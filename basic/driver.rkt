#lang racket
(require unstable/contract
         "../wire/main.rkt"
         "../bson/driver.rkt"
         "../bson/main.rkt"
         "../lib/binio.rkt"
         "../lib/seq.rkt"
         "../lib/mapping.rkt")

;;; Structs

(define-struct mongo (lock conn))
(define-struct mongo-db ([mongo #:mutable] name))
(define-struct mongo-collection (db name))
(provide/contract
 [mongo? (any/c . -> . boolean?)]
 [struct mongo-db ([mongo mongo?]
                   [name string?])]
 [struct mongo-collection ([db mongo-db?]
                           [name string?])])

;;; Executor
(define mongo-executor (make-will-executor))
; XXX Figure out some way to batch a few kill cursors together
(define executor-thread
  (thread
   (lambda ()
     (let loop ()
       (will-execute mongo-executor)
       (loop)))))

;;; Cursor operations
; XXX Figure out some way to get more at a time
(define-struct mongo-cursor (mongo col cid [start #:mutable] [done? #:mutable])
  #:property prop:sequence
  (lambda (mc)
    (define init (mongo-cursor-start mc))
    (in-sequences 
     ; Start with the vector from the first query
     init
     ; Then continue with more results
     (make-do-sequence
      (lambda ()
        ; Forget the initial values
        (set-mongo-cursor-start! mc #f)
        (values (lambda (pos)
                  (mongo-cursor-next mc))
                (lambda (pos) (add1 pos))
                (vector-length init)
                (lambda (pos) (mongo-cursor-done? mc))
                (lambda (val) (not (void? val)))
                (lambda (pos val) #t)))))))

(provide/contract
 [mongo-cursor? (any/c . -> . boolean?)]
 [mongo-cursor-done? (mongo-cursor? . -> . boolean?)])

(define (create-mongo-cursor mongo col cid start)
  (define mc (make-mongo-cursor mongo col cid start (not (zero? cid))))
  (will-register mongo-executor mc mongo-cursor-kill!)
  mc)

(provide/contract
 [mongo-cursor-kill! (mongo-cursor? . -> . void)])

(define (mongo-cursor-kill! mc)
  (match-define (struct mongo-cursor (m c cid _ done?)) mc)
  (define qid (new-msg-id))
  (unless done?
    (mongo-send m (make-kill-cursors qid 0 (vector cid)))
    (set-mongo-cursor-done?! mc #t)))

(define (mongo-cursor-next mc)
  (match-define (struct mongo-cursor (m c cid _ _)) mc)
  (define qid (new-msg-id))
  (define response
    (mongo-send m (make-get-more qid 0 c 1 cid)))
  (match response
    [(struct reply (id to error? new-cid _from answers))
     (unless (= to qid)
       (error 'mongo-get-one-more "Got an answer to a different query"))
     (when error?
       (error 'mongo-get-one-more "Get more failed: ~e" cid))
     (match answers
       ; XXX Is this correct wrt tailable?
       [(vector)
        (set-mongo-cursor-done?! mc #t)]
       [(vector ans)
        ans]
       [_
        (error 'mongo-get-one-more "Received too many answers: ~e" answers)])]))

;;; Mongo operations
; XXX Support other connection styles (master-slave, replica pair, etc)
; XXX Support automatic reconnection
(define (mongo-send m msg)
  (match-define (struct mongo (lock conn)) m)
  (call-with-semaphore 
   lock
   (lambda ()
     (send-message conn msg))))

(provide/contract
 [create-mongo (() (#:host string? #:port port-number?) . ->* . mongo?)]
 [close-mongo! (mongo? . -> . void?)])
(define (create-mongo #:host [host "localhost"] #:port [port 27017])
  (make-mongo (make-semaphore 1) (create-mongo-connection #:host host #:port port)))

(define (close-mongo! m)
  (match-define (struct mongo (lock conn)) m)
  (call-with-semaphore 
   lock
   (lambda ()
     (close-mongo-connection! conn))))

(define (mongo-find m c q
                    #:tailable? [tailable? #f]
                    #:slave-okay? [slave-okay? #f]
                    #:no-timeout? [no-timeout? #f]
                    #:selector [selector #f]
                    #:skip [skip 0]
                    #:limit [limit #f])
  (define qid (new-msg-id))
  (define actual-limit
    (or limit
        ; The default limit is 2 because it is the smallest limit that returns a cursor.
        2))
  (define response
    (mongo-send
     m
     (make-query qid 0 c 
                 (append (if tailable? (list 'tailable-cursor) empty)
                         (if slave-okay? (list 'slave-ok) empty)
                         (if no-timeout? (list 'no-cursor-timeout) empty))
                 skip actual-limit
                 q selector)))
  (match response
    [(struct reply (id to error? cid _from ans))
     (unless (= to qid)
       (error 'mongo-find "Got an answer to a different query"))
     (when error?
       (error 'mongo-find "Query failed: ~e" q))
     (create-mongo-cursor m c cid ans)]))

(define (mongo-find-one m c q)
  (define ans-cursor
    (mongo-find m c q #:limit -1))
  (sequence-ref ans-cursor 0))

(provide/contract
 [mongo-list-databases (mongo? . -> . (vectorof bson-document/c))]
 [mongo-db-names (mongo? . -> . (listof string?))])

(define (mongo-list-databases m)
  (hash-ref (mongo-db-execute-command! (make-mongo-db m "admin") `([listDatabases . 1]))
            'databases))

(define (mongo-db-names m)
  (for/list ([d (in-vector (mongo-list-databases m))])
    (hash-ref d 'name)))

;;; Database operations
(provide/contract
 [mongo-db-execute-command! (mongo-db? bson-document/c . -> . bson-document/c)])
(define (mongo-db-execute-command! db cmd)
  (define ans
    (mongo-find-one (mongo-db-mongo db) (format "~a.$cmd" (mongo-db-name db)) cmd))
  (if (and (hash? ans)
           (hash-has-key? ans 'errmsg))
      (error 'mongo-db-execute-command! "~e returned ~e" cmd (hash-ref ans 'errmsg))
      ans))

(provide/contract
 [mongo-db-collections (mongo-db? . -> . (listof string?))])
(define (mongo-db-collections db)
  (define name (mongo-db-name db))
  (define ans (mongo-find (mongo-db-mongo db) (format "~a.system.namespaces" name) empty))
  (define name-rx (regexp (format "^~a\\.(.+)$" (regexp-quote name))))
  (for/fold ([l empty])
    ([c ans])
    (define n (hash-ref c 'name))
    (match (regexp-match name-rx n)
      [(list _ name)
       (if (regexp-match #rx"\\$" name)
           l
           (list* name l))]
      [#f l])))

(provide/contract
 [mongo-db-create-collection! ((mongo-db? string? #:capped? boolean? #:size number?)
                               (#:max (or/c false/c number?))
                               . ->* . mongo-collection?)])
(define (mongo-db-create-collection! db name
                                     #:capped? capped? 
                                     #:size size
                                     #:max [max #f])
  (mongo-db-execute-command!
   db 
   (list* (cons 'create name)
          (cons 'capped capped?)
          (cons 'size size)
          (if max
              (list (cons 'max max))
              empty)))
  (make-mongo-collection db name))

; XXX parse answers
(provide/contract
 [mongo-db-drop-collection! (mongo-db? string? . -> . bson-document/c)])
(define (mongo-db-drop-collection! db name)
  (mongo-db-execute-command! db `([drop . ,name])))

(provide/contract
 [mongo-db-drop (mongo-db? . -> . bson-document/c)])
(define (mongo-db-drop db)
  (mongo-db-execute-command! db `([dropDatabase . 1])))

(define-mappings (num->profiling profiling->num)
  [(0) 'none]
  [(1) 'low]
  [(2) 'all])
(define mongo-db-profiling/c (symbols 'none 'low 'all))

(provide/contract
 [mongo-db-profiling/c contract?]
 [mongo-db-profiling (mongo-db? . -> . mongo-db-profiling/c)]
 [set-mongo-db-profiling! (mongo-db? mongo-db-profiling/c . -> . boolean?)])
(define (mongo-db-profiling db)
  (hash-ref num->profiling
            (inexact->exact
             (hash-ref (mongo-db-execute-command! db `([profile . -1]))
                       'was))))
; XXX error on fail
(define (set-mongo-db-profiling! db level)
  (define level-n (hash-ref profiling->num level))
  (= 1
     (hash-ref (mongo-db-execute-command! db `([profile . ,level-n])) 'ok)))

(provide/contract
 [mongo-db-profiling-info (mongo-db? . -> . bson-document/c)]
 [mongo-db-valid-collection? (mongo-db? string? . -> . boolean?)])
(define (mongo-db-profiling-info db)
  (mongo-find-one (mongo-db-mongo db) (format "~a.system.profile" (mongo-db-name db)) empty))

(define (mongo-db-valid-collection? db c)
  (= 1 (hash-ref (mongo-db-execute-command! db `([validate . ,c])) 'ok)))

;;; Collection operations
(provide/contract
 [mongo-collection-drop! (mongo-collection? . -> . void)]
 [mongo-collection-valid? (mongo-collection? . -> . boolean?)]
 [mongo-collection-full-name (mongo-collection? . -> . string?)])
(define (mongo-collection-drop! c)
  (match-define (struct mongo-collection (db name)) c)
  (mongo-db-drop-collection! db name))

(define (mongo-collection-valid? c)
  (match-define (struct mongo-collection (db name)) c)
  (mongo-db-valid-collection? db name))

(define (mongo-collection-full-name c)
  (match-define (struct mongo-collection (db col)) c)
  (match-define (struct mongo-db (m db-name)) db)
  (format "~a.~a" db-name col))

(provide/contract
 [mongo-collection-find
  (->* (mongo-collection? bson-document/c)
       (#:tailable? boolean?
        #:slave-okay? boolean?
        #:no-timeout? boolean?
        #:selector (or/c false/c bson-document/c)
        #:skip int32?
        #:limit (or/c false/c int32?))
       mongo-cursor?)])
(define (mongo-collection-find c query 
                               #:tailable? [tailable? #f]
                               #:slave-okay? [slave-okay? #f]
                               #:no-timeout? [no-timeout? #f]
                               #:selector [selector #f]
                               #:skip [skip 0]
                               #:limit [limit #f])
  (match-define (struct mongo-collection (db col)) c)
  (match-define (struct mongo-db (m db-name)) db)
  (mongo-find m (mongo-collection-full-name c)
              query
              #:tailable? tailable?
              #:slave-okay? slave-okay?
              #:no-timeout? no-timeout?
              #:selector selector
              #:skip skip
              #:limit limit))

(provide/contract
 [mongo-collection-insert-docs! (mongo-collection? (sequenceof bson-document/c) . -> . void)]
 [mongo-collection-insert-one! (mongo-collection? bson-document/c . -> . void)]
 [mongo-collection-insert! ((mongo-collection?) () #:rest (listof bson-document/c) . ->* . void)])
(define (mongo-collection-insert-docs! c objs)
  (match-define (struct mongo-collection (db col)) c)
  (match-define (struct mongo-db (m db-name)) db)
  (define mid (new-msg-id))
  (mongo-send m (make-insert mid 0 (mongo-collection-full-name c) objs))
  (void))

(define (mongo-collection-insert-one! c obj)
  (mongo-collection-insert-docs! c (vector obj)))
(define (mongo-collection-insert! c . objs)
  (mongo-collection-insert-docs! c objs))

(provide/contract
 [mongo-collection-remove! (mongo-collection? bson-document/c . -> . void)]
 [mongo-collection-modify! (mongo-collection? bson-document/c bson-document/c . -> . void)]
 [mongo-collection-replace! (mongo-collection? bson-document/c bson-document/c . -> . void)]
 [mongo-collection-repsert! (mongo-collection? bson-document/c bson-document/c . -> . void)])
(define (mongo-collection-remove! c sel)
  (match-define (struct mongo-collection (db col)) c)
  (match-define (struct mongo-db (m db-name)) db)
  (define mid (new-msg-id))
  (mongo-send m (make-delete mid 0 (mongo-collection-full-name c) sel))
  (void))

(define (mongo-collection-update! c flags sel mod)
  (match-define (struct mongo-collection (db col)) c)
  (match-define (struct mongo-db (m db-name)) db)
  (define mid (new-msg-id))
  (mongo-send m (make-update mid 0 (mongo-collection-full-name c) flags sel mod))
  (void))

(define (mongo-collection-modify! c sel mod)
  (mongo-collection-update! c '(multi-update) sel mod))
(define (mongo-collection-replace! c sel obj)
  (mongo-collection-update! c empty sel obj))
(define (mongo-collection-repsert! c sel obj)
  (mongo-collection-update! c '(upsert) sel obj))

(provide/contract
 [mongo-collection-count ((mongo-collection?) (bson-document/c) . ->* . exact-integer?)])
(define (mongo-collection-count c [q empty])
  (sequence-count (mongo-collection-find c q)))

;;; Index
(define (generate-index-name k)
  (with-output-to-string (lambda () (write k))))

(provide/contract
 [mongo-collection-index! ((mongo-collection? bson-document/c) (#:name string?) . ->* . void)]
 [mongo-collection-indexes (mongo-collection? . -> . mongo-cursor?)]
 [mongo-collection-drop-index! (mongo-collection? string? . -> . void)])
(define (mongo-collection-index! c key #:name [name (generate-index-name key)])
  (match-define (struct mongo-collection (db col)) c)
  (define si-c (make-mongo-collection db "system.indexes"))
  (mongo-collection-insert-one!
   si-c 
   (list (cons 'name name)
         (cons 'ns (mongo-collection-full-name c))
         (cons 'key key))))

(define (mongo-collection-indexes c)
  (match-define (struct mongo-collection (db col)) c)
  (define si-c (make-mongo-collection db "system.indexes"))
  (mongo-collection-find si-c (list (cons 'ns (mongo-collection-full-name c)))
                         #:limit 0))

(define (mongo-collection-drop-index! c name)
  (match-define (struct mongo-collection (db col)) c)
  (mongo-db-execute-command! 
   db 
   (list (cons 'deleteIndexes col)
         (cons 'index name))))

; XXX explain, getOptions

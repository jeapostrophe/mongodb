#lang racket
(require "../bson/main.rkt"
         "../bson/driver.rkt"
         "../lib/binio.rkt"
         "../lib/seq.rkt"
         "../lib/mapping.rkt")

;;; Structs
(define-struct msg (id response-to) #:transparent)
(define-struct (reply msg) (error? cursor-id starting-from documents) #:transparent)

(define-struct (update msg) (collection flags selector document) #:transparent)
(define-struct (insert msg) (collection documents) #:transparent)
(define-struct (query msg) (collection options to-skip to-return query selector) #:transparent)
(define-struct (get-more msg) (collection to-return cursor-id) #:transparent)
(define-struct (delete msg) (collection selector) #:transparent)
(define-struct (kill-cursors msg) (cursor-ids) #:transparent)

;;; Op codes
(define (not-supported x) #f)
(define-mappings/pred (op-code->tag tag->op-code v->tag)
  "Invalid msg: ~e"
  [(1) 'OP_REPLY reply?]
  [(1000) 'OP_MSG not-supported]
  [(2001) 'OP_UPDATE update?]
  [(2002) 'OP_INSERT insert?]
  [(2003) 'RESERVED not-supported]
  [(2004) 'OP_QUERY query?]
  [(2005) 'OP_GET_MORE get-more?]
  [(2006) 'OP_DELETE delete?]
  [(2007) 'OP_KILL_CURSORS kill-cursors?])

;;; Writers
(define (write-msg m p)
  (define-values (body-size write-body)
    (prepare-body m))
  (write-header body-size m p)
  (write-body p)
  (flush-output p))

(define (write-header body-size m p)
  (match-define (struct msg (id response-to)) m)
  (define op-code
    (hash-ref tag->op-code (v->tag m)))
  (write-int32 p (+ int32-size int32-size int32-size int32-size body-size))
  (write-int32 p id)
  (write-int32 p response-to)
  (write-int32 p op-code))

(define (prepare-vector prepare-e v)
  (for/fold ([size 0]
             [write-before void])
    ([d v])
    (define-values (d-size write-d) (prepare-e d))
    (values (+ size d-size)
            (lambda (p)
              (write-before p)
              (write-d p)))))

(define prepare-bson* (curry prepare-vector prepare-bson))

(define (maybe-prepare-bson mb)
  (if mb
      (prepare-bson mb)
      (values 0 void)))

(define-syntax-rule (define-set->int32 f
                      contract/c
                      [symbol bit]
                      ...)
  (begin (define contract/c
           (listof (symbols 'symbol ...)))
         (define (f s)
           (+ (if (member 'symbol s)
                  bit 0)
              ...))))

(define-set->int32 update-flag-set->flags
  update-flags/c
  [upsert 1]
  [multi-update 2])

(define-set->int32 query-opt-set->opts
  query-opts/c
  [tailable-cursor 2]
  [slave-ok 4]
  #;[oplog-replay 8] ; (internal replication use only - drivers should not implement)
  [no-cursor-timeout 16])

(define prepare-body
  (match-lambda
    [(struct update (_ _ col flag-set sel doc))
     (define flags (update-flag-set->flags flag-set))
     (define-values (col-size write-col) (prepare-cstring col))
     (define-values (sel-size write-sel) (prepare-bson sel))
     (define-values (doc-size write-doc) (prepare-bson doc))
     (values (+ int32-size col-size int32-size sel-size doc-size)
             (lambda (p)
               (write-int32 p 0)
               (write-col p)
               (write-int32 p flags)
               (write-sel p)
               (write-doc p)))]
    [(struct insert (_ _ col docs))
     (define-values (col-size write-col) (prepare-cstring col))
     (define-values (docs-size write-docs) (prepare-bson* docs))
     (values (+ int32-size col-size docs-size)
             (lambda (p)
               (write-int32 p 0)
               (write-col p)
               (write-docs p)))]
    [(struct query (_ _ col opt-set to-skip to-return query sel))
     (define opts (query-opt-set->opts opt-set))
     (define-values (col-size write-col) (prepare-cstring col))
     (define-values (query-size write-query) (prepare-bson query))
     (define-values (sel-size write-sel) (maybe-prepare-bson sel))
     (values (+ int32-size col-size int32-size int32-size query-size sel-size)
             (lambda (p)
               (write-int32 p opts)
               (write-col p)
               (write-int32 p to-skip)
               (write-int32 p to-return)
               (write-query p)
               (write-sel p)))]
    [(struct get-more (_ _ col to-return cursor-id))
     (define-values (col-size write-col) (prepare-cstring col))
     (values (+ int32-size col-size int32-size int64-size)
             (lambda (p)
               (write-int32 p 0)
               (write-col p)
               (write-int32 p to-return)
               (write-int64 p cursor-id)))]
    [(struct delete (_ _ col sel))
     (define-values (col-size write-col) (prepare-cstring col))
     (define-values (sel-size write-sel) (prepare-bson sel))
     (values (+ int32-size col-size int32-size sel-size)
             (lambda (p)
               (write-int32 p 0)
               (write-col p)
               (write-int32 p 0)
               (write-sel p)))]
    [(struct kill-cursors (_ _ cursor-ids))
     (define-values (cs-size write-cs) (prepare-vector prepare-int64 cursor-ids))
     (values (+ int32-size int32-size cs-size)
             (lambda (p)
               (write-int32 p 0)
               (write-int32 p (vector-length cursor-ids))
               (write-cs p)))]))


;;; Readers
(define (read-msg p)
  (define-values (len id response-to op-code)
    (read-header p))
  (define tag
    (hash-ref op-code->tag op-code
              (lambda ()
                (error 'read-msg "Invalid op code: ~e" op-code))))
  (case tag
    [(OP_REPLY)
     (read-reply id response-to p)]
    [else
     (error 'read-msg "Unsupported op code: ~e" tag)]))

(define (read-header p)
  (define len (read-int32 p))
  (define id (read-int32 p))
  (define response-to (read-int32 p))
  (define op-code (read-int32 p))
  (values len id response-to op-code))

(define (reply-flag->error? flag)
  (case flag
    [(0 8) #f]
    [else #t]))

(define (read-reply id response-to p)
  (define flag (read-int32 p))
  (define cursor-id (read-int64 p))
  (define starting-from (read-int32 p))
  (define number-returned (read-int32 p))
  (define documents
    (build-vector number-returned
                  (lambda (i) (read-bson p))))
  (make-reply id response-to (reply-flag->error? flag) cursor-id starting-from documents))

;;; Exports w/ contracts
(provide/contract
 [read-msg (input-port? . -> . msg?)]
 [write-msg (msg? output-port? . -> . void)]
 
 [update-flags/c contract?]
 [query-opts/c contract?]
 
 [struct msg 
         ([id int32?]
          [response-to int32?])]
 [struct (reply msg) 
         ([id int32?]
          [response-to int32?]
          [error? boolean?]
          [cursor-id int64?]
          [starting-from int32?]
          [documents (vectorof bson-document/c)])]
 
 [struct (update msg)
         ([id int32?]
          [response-to int32?]
          [collection string?]
          [flags update-flags/c]
          [selector bson-document/c]
          [document bson-document/c])]
 [struct (insert msg)
         ([id int32?]
          [response-to int32?]
          [collection string?]
          [documents (sequenceof bson-document/c)])]
 [struct (query msg)
         ([id int32?]
          [response-to int32?]
          [collection string?] 
          [options query-opts/c]
          [to-skip int32?]
          [to-return int32?]
          [query bson-document/c]
          [selector (or/c false/c bson-document/c)])]
 [struct (get-more msg)
         ([id int32?]
          [response-to int32?]
          [collection string?]
          [to-return int32?]
          [cursor-id int64?])]
 [struct (delete msg)
         ([id int32?]
          [response-to int32?]
          [collection string?]
          [selector bson-document/c])]
 [struct (kill-cursors msg)
         ([id int32?]
          [response-to int32?]
          [cursor-ids (vectorof int64?)])])
 
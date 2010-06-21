#lang scheme
(require scheme/serialize
         "../bson/main.rkt"
         "../lib/seq.rkt"
         "../basic/main.rkt")

(define current-mongo-db (make-parameter #f))

(define (create-mongo-dict col)
  (define id (new-bson-objectid))
  (define c (make-mongo-collection (current-mongo-db) col))
  ; XXX Delay committing
  (mongo-collection-insert! c (list (cons '_id id)))
  (make-mongo-dict col id))

(define (mongo-dict-query col query)
  (define c (make-mongo-collection (current-mongo-db) col))
  (sequence-map 
   (lambda (ans)
     (define id (hash-ref ans '_id))
     (make-mongo-dict col id))
   (mongo-collection-find 
    c query
    #:selector (list (cons '_id 1)))))

(define (mongo-dict-find md sel)
  (match-define (struct mongo-dict (col-name id)) md)
  (define c (make-mongo-collection (current-mongo-db) col-name))
  (define query (list (cons '_id id)))
  (define cur
    (mongo-collection-find c query 
                           #:selector sel
                           #:limit -1))
  (sequence-ref cur 0))

(define (mongo-dict-ref md key [fail bson-null])
  (with-handlers ([exn:fail?
                   (lambda (x)
                     (if (procedure? fail) (fail)
                         fail))])
    (hash-ref (mongo-dict-find md (list (cons key 1))) key)))

(define (mongo-dict-replace! md mod)
  (match-define (struct mongo-dict (col-name id)) md)
  (define c (make-mongo-collection (current-mongo-db) col-name))
  (define query (list (cons '_id id)))
  (hash-remove! MONGO-DICT-CACHE md)
  (mongo-collection-modify!
   c query mod))

(define (mongo-dict-set! md key val)
  (mongo-dict-replace! md (list (cons '$set (list (cons key val))))))
; XXX set*!
(define (mongo-dict-remove! md key)
  (mongo-dict-replace! md (list (cons '$unset (list (cons key 1))))))

(define (mongo-dict->dict md)
  (define ans (mongo-dict-find md #f))
  (hash-remove! ans '_id)
  ans)

(define MONGO-DICT-CACHE (make-weak-hasheq))
(define (make-mongo-dict-wrapper dict-fun)
  (lambda (md . args)
    (define dict-box
      (hash-ref! MONGO-DICT-CACHE md (lambda () (make-weak-box (mongo-dict->dict md)))))
    (define dict-val
      (match (weak-box-value dict-box)
        [#f 
         (define v (mongo-dict->dict md))
         (hash-set! MONGO-DICT-CACHE md (make-weak-box v))
         v]
        [e e]))
    (apply dict-fun dict-val args)))

(define mongo-dict-count (make-mongo-dict-wrapper dict-count))
(define mongo-dict-iterate-first (make-mongo-dict-wrapper dict-iterate-first))
(define mongo-dict-iterate-next (make-mongo-dict-wrapper dict-iterate-next))
(define mongo-dict-iterate-key (make-mongo-dict-wrapper dict-iterate-key))
(define mongo-dict-iterate-value (make-mongo-dict-wrapper dict-iterate-value))

(define (mongo-dict-inc! md key [inc 1])
  (mongo-dict-replace! md (list (cons '$inc (list (cons key inc))))))
(define (mongo-dict-push! md key val)
  (mongo-dict-replace! md (list (cons '$push (list (cons key val))))))
(define (mongo-dict-append! md key vals)
  (mongo-dict-replace! md (list (cons '$pushAll (list (cons key vals))))))
(define (mongo-dict-set-add! md key val)
  (mongo-dict-replace! md (list (cons '$addToSet (list (cons key val))))))
(define (mongo-dict-set-add*! md key vals)
  (mongo-dict-replace! md (list (cons '$addToSet (list (cons key (list (cons '$each vals))))))))
(define (mongo-dict-pop! md key)
  (mongo-dict-replace! md (list (cons '$pop (list (cons key 1))))))
(define (mongo-dict-shift! md key)
  (mongo-dict-replace! md (list (cons '$pop (list (cons key -1))))))
(define (mongo-dict-pull! md key val)
  (mongo-dict-replace! md (list (cons '$pull (list (cons key val))))))
(define (mongo-dict-pull*! md key vals)
  (mongo-dict-replace! md (list (cons '$pullAll (list (cons key vals))))))

(define-serializable-struct mongo-dict (collection-name id)
  #:transparent
  #:property prop:sequence
  (lambda (md)
    (mongo-dict->dict md))
  #:property prop:dict
  (vector mongo-dict-ref
          mongo-dict-set!
          #f
          mongo-dict-remove!
          #f
          mongo-dict-count
          mongo-dict-iterate-first
          mongo-dict-iterate-next
          mongo-dict-iterate-key
          mongo-dict-iterate-value))

(provide/contract
 [struct mongo-dict ([collection-name string?]
                     [id bson-objectid?])]
 [current-mongo-db (parameter/c (or/c false/c mongo-db?))]
 [create-mongo-dict (string? . -> . mongo-dict?)]
 [mongo-dict-query (string? bson-document/c . -> . sequence?)]
 [mongo-dict-ref ((mongo-dict? symbol?) (any/c) . ->* . any/c)]
 [mongo-dict-set! (mongo-dict? symbol? any/c . -> . void)]
 [mongo-dict-remove! (mongo-dict? symbol? . -> . void)]
 [mongo-dict-count (mongo-dict? . -> . exact-nonnegative-integer?)]
 [mongo-dict-inc! ((mongo-dict? symbol?) (number?) . ->* . void)]
 [mongo-dict-push! (mongo-dict? symbol? any/c . -> . void)]
 [mongo-dict-append! (mongo-dict? symbol? sequence? . -> . void)]
 [mongo-dict-set-add! (mongo-dict? symbol? any/c . -> . void)]
 [mongo-dict-set-add*! (mongo-dict? symbol? sequence? . -> . void)]
 [mongo-dict-pop! (mongo-dict? symbol? . -> . void)]
 [mongo-dict-shift! (mongo-dict? symbol? . -> . void)]
 [mongo-dict-pull! (mongo-dict? symbol? any/c . -> . void)]
 [mongo-dict-pull*! (mongo-dict? symbol? sequence? . -> . void)])
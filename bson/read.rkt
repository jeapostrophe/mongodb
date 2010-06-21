#lang racket
(require (prefix-in racket: racket)
         "shared.rkt"
         "../lib/binio.rkt")

(provide read-bson read-bson/bytes)

(define (read-document p)
  (define total-bytes (read-int32 p))
  (define ht (make-hasheq))
  (read-into-hash ht p read-element-into-hash)
  ht)

(define (read-into-hash ht p reader)
  (define t (read-type-tag p))
  (case t
    [(eof) (void)]
    [else
     (reader ht t p)
     (read-into-hash ht p reader)]))

(define (read-element-into-hash ht type p)
  (define name (read-element-name p))
  (hash-set! ht name (read-type type p)))

(define (read-boolean p)
  (case (read-byte p)
    [(#x00) #f]
    [(#x01) #t]))

(define (read-javascript-code/scope p)
  (define total-size (read-int32 p))
  (define code (read-string p))
  (define scope (read-document p))
  (make-bson-javascript/scope code scope))

(define (read-binary p)
  (define array-size (read-int32 p))
  (define subtype-b (read-byte p))
  (define subtype (hash-ref binary-byte->tag subtype-b))
  (case subtype
    [(binary)
     (let ([bytes-size (read-int32 p)])
       (read-bytes bytes-size p))]
    [else
     (make-bson-binary subtype (read-bytes array-size p))]))

(define (read-oid p)
  (make-bson-objectid (read-bytes 12 p)))

(define (read-regexp p)
  (define pat (read-cstring p))
  (define opts (read-cstring p))
  (make-bson-regexp pat opts))

(define (read-type t p)
  (case t
    [(floating-point) (read-double p)]
    [(utf8-string) (read-string p)]
    [(document) (read-document p)]
    [(array) (document->array (read-document p))]
    [(binary) (read-binary p)]
    [(undefined)
     (error 'read-type "Undefined is deprecated")]
    [(objectid) (read-oid p)]
    [(boolean) (read-boolean p)]
    [(utc-datetime) (make-bson-utc-datetime (read-int64 p))]
    [(null) bson-null]
    [(regexp) (read-regexp p)]
    [(db-pointer)
     (error 'read-type "Database pointers are deprecated")]
    [(javascript-code) (make-bson-javascript (read-string p))]
    [(symbol) (string->symbol (read-string p))]
    [(javascript-code/scope) (read-javascript-code/scope p)]
    [(int32) (read-int32 p)]
    [(timestamp) (make-bson-timestamp (read-int64 p))]
    [(int64) (read-int64 p)]
    [(min-key) bson-min-key]
    [(max-key) bson-max-key]
    [else
     (error 'read-type "Unknown tag: ~a" t)]))

(define (document->array d)
  (define max (hash-count d))
  (define vec (make-vector max #f))
  (for ([(k v) d])
    (vector-set! vec (symbol->number k) v))
  vec)

(define (read-until p reader until?)
  (define c (reader p))
  (if (until? c)
      empty
      (list* c (read-until p reader until?))))

(define (read-string p)
  (define amt+1 (read-int32 p))
  (begin0 (racket:read-string (sub1 amt+1) p)
          (read-char p)))

(define (read-cstring p)
  (apply string (read-until p read-char (curry char=? #\nul))))

(define (read-double p)
  (define bs (read-bytes 8 p))
  (floating-point-bytes->real bs #f))  

(define read-element-name (compose string->symbol read-cstring))

(define (read-type-tag p)
  (define b (read-byte p))
  (hash-ref byte->tag b
            (lambda ()
              (error 'read-type-tag "Unknown tag: ~a" b))))

;;;;
(define (read-bson/bytes bs)
  (read-document (open-input-bytes bs)))
(define read-bson read-document)

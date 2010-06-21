#lang racket
(require "shared.rkt"
         "../lib/binio.rkt")

(provide write-bson write-bson/bytes prepare-document)

(define (prepare-document d)
  (define-values (almost-total-size write-body) 
    (prepare-document-body d))
  (define total-size
    (+ almost-total-size int32-size 1))
  (values total-size
          (lambda (p)
            (write-int32 p total-size)
            (write-body p)
            (write-null-byte p))))

(define (prepare-document-body d)
  (for/fold ([size 0]
             [write void])
    ([(k v) (in-dict d)])
    (define-values (element-size write-element)
      (prepare-element k v))
    (values (+ size element-size)
            (write-then write write-element))))

(define (prepare-element k v)
  (define type-tag (value->tag v))
  (define-values (name-size write-name)
    (prepare-element-name k))
  (define-values (value-size write-value)
    (prepare-value type-tag v))
  (values (+ type-tag-size name-size value-size)
          (lambda (p)
            (write-type-tag p type-tag)
            (write-name p)
            (write-value p))))

(define prepare-element-name (compose prepare-cstring symbol->string))

(define (prepare-double v)
  (values 8
          (lambda (p)
            (write-bytes (real->floating-point-bytes v 8) p))))

(define (prepare-string v)
  (define-values (str-len write-str)
    (prepare-cstring v))
  (values (+ int32-size str-len)
          (lambda (p)
            (write-int32 p str-len)
            (write-str p))))

(define (array->document vec)
  (for/list ([i (in-naturals)]
             [v vec])
    (cons (number->symbol i) v)))

(define (prepare-boolean v)
  (values 1
          (lambda (p)
            (if v
                (write-byte 1 p)
                (write-byte 0 p)))))

(define (no-printing)
  (values 0 void))

(define prepare-javascript/scope
  (match-lambda
    [(struct bson-javascript/scope (s d))
     (define-values (s-len write-s)
       (prepare-string s))
     (define-values (d-len write-d)
       (prepare-document d))
     (define total-size
       (+ int32-size s-len d-len))
     (values total-size
             (lambda (p)
               (write-int32 p total-size)
               (write-s p)
               (write-d p)))]))

(define (ensure-binary v)
  (if (bytes? v)
      (make-bson-binary 'bytes v)
      v))

(define prepare-binary
  (match-lambda
    [(struct bson-binary (t bs))
     (define byte-array-size
       (+ (if (symbol=? t 'bytes) int32-size 0)
          (bytes-length bs)))
     (define total-size
       (+ int32-size 1 byte-array-size))
     (define rt
       (if (symbol=? t 'bytes)
           'binary t))
     (values total-size
             (lambda (p)
               (write-int32 p byte-array-size)
               (write-byte (hash-ref tag->binary-byte rt) p)
               (when (symbol=? t 'bytes)
                 (write-int32 p (bytes-length bs)))
               (write-bytes bs p)))]))

(define (prepare-oid o)
  (values 12
          (lambda (p)
            (write-bytes (bson-objectid-v o) p))))

(define prepare-regexp
  (match-lambda
    [(struct bson-regexp (pat opts))
     (define-values (ps p!) (prepare-cstring pat))
     (define-values (os o!) (prepare-cstring opts))
     (values (+ ps os)
             (write-then p! o!))]))

(define (prepare-value t v)
  (case t
    [(floating-point) (prepare-double v)]
    [(utf8-string) (prepare-string v)]
    [(document) (prepare-document v)]
    [(array) (prepare-document (array->document v))]
    [(binary) (prepare-binary (ensure-binary v))]
    [(undefined)
     (error 'prepare-value "Undefined is deprecated")]
    [(objectid) (prepare-oid v)]
    [(boolean) (prepare-boolean v)]
    [(utc-datetime) (prepare-int64 (bson-utc-datetime-ms v))]
    [(null) (no-printing)]
    [(regexp) (prepare-regexp v)]
    [(db-pointer)
     (error 'prepare-value "Database pointers are deprecated")]
    [(javascript-code) (prepare-string (bson-javascript-string v))]
    [(symbol) (prepare-string (symbol->string v))]
    [(javascript-code/scope) (prepare-javascript/scope v)]
    [(int32) (prepare-int32 v)]
    [(timestamp) (prepare-int64 (bson-timestamp-value v))]
    [(int64) (prepare-int64 v)]
    [(min-key) (no-printing)]
    [(max-key) (no-printing)]
    [else
     (error 'prepare-value "Unknown tag: ~a" t)]))

;;;
(define (write-type-tag p t)
  (write-byte (hash-ref tag->byte t) p))

;;;

(define ((write-then fst snd) p)
  (begin (fst p)
         (snd p)))

;;;

(define (write-bson d p)
  (define-values (_ write-it!)
    (prepare-document d))
  (write-it! p))

(define (write-bson/bytes d)
  (define ob (open-output-bytes))
  (write-bson d ob)
  (get-output-bytes ob))
#lang scheme
(require srfi/19
         "../lib/mapping.rkt"
         "../lib/binio.rkt")

(define (not-represented x) #f)
(define (deprecated x) #f)

(define ((and-pred fst snd) x)
  (and (fst x) (snd x)))
(define ((or-pred fst snd) x)
  (or (fst x) (snd x)))

(define-struct bson-token ())
(define bson-min-key (make-bson-token))
(define bson-max-key (make-bson-token))
(define bson-null (make-bson-token))

(define bson-min-key? (curry eq? bson-min-key))
(define bson-max-key? (curry eq? bson-max-key))
(define bson-null? (curry eq? bson-null))

(define-struct bson-timestamp (value) #:prefab)
(define-struct bson-javascript (string) #:prefab)
(define-struct bson-javascript/scope (string scope) #:prefab)
(define-struct bson-binary (type bs) #:prefab)
(define-struct bson-objectid (v) #:prefab)

(define (bson-utc-datetime? x)
  (and (time? x)
       (eq? (time-type x) time-utc)))
(define (bson-utc-datetime-ms t)
  (+ (sec->ms (time-second t))
     (ns->ms (time-nanosecond t))))
(define (make-bson-utc-datetime ms)
  (define-values (s ns) (split-ms ms))
  (make-time time-utc ns s))
(define (sec->ms s)
  (* 1000 s))
(define (ns->ms ns)
  (* ns (expt 10 -6)))
(define (split-ms ms)
  (define s (floor (/ ms 1000)))
  (define ms-after-s (modulo ms 1000))
  (define ns (* (expt 10 6) ms-after-s))
  (values s ns))          

(define new-bson-objectid
  (local [(define count 0)
          (define fuzz (random))]
    (lambda ()
      (begin0
        (make-bson-objectid
         (bytes-append (integer->integer-bytes (current-seconds) 4 #t #t)
                       (real->floating-point-bytes fuzz 4 #t)
                       (integer->integer-bytes count 4 #t #t)))
        (set! count (add1 count))))))
(define (bson-objectid-timestamp v)
  (integer-bytes->integer (bson-objectid-v v) #t #t 0 4))
(require net/base64)
(define (string->bson-objectid s)
  (make-bson-objectid (base64-decode (string->bytes/utf-8 s))))
(define (bson-objectid->string b)
  (bytes->string/utf-8 (base64-encode (bson-objectid-v b))))

(define-struct bson-regexp (pattern options) #:prefab)

(define type-tag-size 1)

(define-mappings (binary-byte->tag tag->binary-byte)
  [(#x01) 'function]
  [(#x02) 'binary]
  [(#x03) 'uuid]
  [(#x05) 'md5]
  [(#x80) 'user-defined])

(define (bson-dict? d)
  (and (dict? d)
       (not (or (vector? d)))))
(define (bson-sequence? s)
  (and (sequence? s)
       (not (or (string? s)
                (bson-dict? s)
                (bytes? s)))))

(define-mappings/pred (byte->tag tag->byte value->tag)
  "Invalid BSON value: ~e"
  [(#x00) 'eof not-represented]
  [(#x01) 'floating-point (and-pred real? inexact?)]
  [(#x02) 'utf8-string string?]
  [(#x03) 'document bson-dict?]
  [(#x04) 'array bson-sequence?]
  [(#x05) 'binary (or-pred bytes? bson-binary?)]
  [(#x06) 'undefined deprecated] ; Deprecated
  [(#x07) 'objectid bson-objectid?]
  [(#x08) 'boolean boolean?]
  [(#x09) 'utc-datetime bson-utc-datetime?]
  [(#x0A) 'null bson-null?]
  [(#x0B) 'regexp bson-regexp?]
  [(#x0C) 'db-pointer deprecated] ; Deprecated
  [(#x0D) 'javascript-code bson-javascript?]
  [(#x0E) 'symbol symbol?]
  [(#x0F) 'javascript-code/scope bson-javascript/scope?]
  [(#x10) 'int32 int32?]
  [(#x11) 'timestamp bson-timestamp?]
  [(#x12) 'int64 int64?]
  [(#xFF) 'min-key bson-min-key?]
  [(#x7F) 'max-key bson-max-key?])

(define symbol->number 
  (compose string->number symbol->string))
(define number->symbol 
  (compose string->symbol number->string))

(provide (all-defined-out))
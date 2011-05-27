#lang racket

(define int32-size 4)
(define int64-size 8)

(define (read-int32 p)
  (define bs (read-bytes int32-size p))
  (integer-bytes->integer bs #t #f))
(define (read-int64 p)
  (define bs (read-bytes int64-size p))
  (integer-bytes->integer bs #t #f))

(define (write-int32 p n)
  (write-bytes (integer->integer-bytes n int32-size #t #f) p))
(define (write-int64 p n)
  (write-bytes (integer->integer-bytes n int64-size #t #f) p))

(define (int32? x)
  (and (integer? x)
       (<= (* -1 32768) x +32767)))
(define (int64? x)
  (and (integer? x)
       (<= (* -1 9223372036854775808) x +9223372036854775807)))

(define (prepare-cstring s)
  (values (add1 (string-utf-8-length s))
          (lambda (p)
            (write-string s p)
            (write-null-byte p))))
(define (prepare-int32 v)
  (values int32-size
          (lambda (p)
            (write-int32 p v))))
(define (prepare-int64 v)
  (values int64-size
          (lambda (p)
            (write-int64 p v))))

(define (write-null-byte p)
  (write-byte 0 p))

(provide (all-defined-out))
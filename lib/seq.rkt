#lang racket

(define (sequence-ref s i)
  (define-values (more? get) (sequence-generate s))
  (let loop ([n i])
    (if (more?)
        (if (zero? n)
            (get)
            (begin
              (get)
              (loop (sub1 n))))
        (error 'sequence-ref "Sequence does not contain ~e elements" i))))

(define (sequence-count s)
  (define-values (more? get) (sequence-generate s))
  (let loop ([i 0])
    (if (more?)
        (begin (get) (loop (add1 i)))
        i)))

(define (sequence->list s)
  (for/list ([e s]) e))

(define (sequence-map f s)
  (make-do-sequence
   (lambda ()
     (define-values (more? get) (sequence-generate s))
     (values
      (lambda (pos) 
        (call-with-values get f))
      (lambda (pos) pos)
      0
      (lambda (pos) (more?))
      (lambda (val) #t)
      (lambda (pos val) #t)))))

; XXX
(define (sequenceof c)
  sequence?)

(provide/contract
 [sequence->list (sequence? . -> . list?)]
 [sequence-ref (sequence? exact-nonnegative-integer? . -> . any/c)]
 [sequence-count (sequence? . -> . exact-nonnegative-integer?)]
 [sequence-map (procedure? sequence? . -> . sequence?)]
 [sequenceof (contract? . -> . contract?)])
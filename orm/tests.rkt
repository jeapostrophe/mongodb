#lang racket
(require "main.rkt"
         "../basic/main.rkt"
         "../bson/main.rkt"
         "../lib/test.rkt"
         "../lib/seq.rkt"
         racket/set
         racket/serialize
         tests/eli-tester)

(test
 (with-mongod
     (define m (create-mongo))
   (define d (make-mongo-db m "test"))
   
   (current-mongo-db d)
   
   (define obj (create-mongo-dict "cons"))
   
   (define (test-obj obj)
     (test
      (mongo-dict-ref obj 'car) => bson-null
      (mongo-dict-ref obj 'car #f) => #f
      (mongo-dict-ref obj 'car (lambda () 2)) => 2
      (mongo-dict-set! obj 'car 1) => (void)
      (mongo-dict-ref obj 'car) => 1
      (mongo-dict-remove! obj 'car) => (void)
      (mongo-dict-ref obj 'car) => bson-null
      (mongo-dict-count obj) => 0
      (mongo-dict-set! obj 'car 1) => (void)
      (mongo-dict-count obj) => 1
      (dict-map obj cons) => (list (cons 'car 1))
      (for/list ([(k v) obj]) (cons k v)) => (list (cons 'car 1))
      (mongo-dict-inc! obj 'car) => (void)
      (mongo-dict-ref obj 'car) => 2
      (mongo-dict-inc! obj 'car 2) => (void)
      (mongo-dict-ref obj 'car) => 4
      (mongo-dict-push! obj 'cdr 3) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3)
      (mongo-dict-push! obj 'cdr 4) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4)
      (mongo-dict-append! obj 'cdr (vector 5 6)) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6)
      (mongo-dict-append! obj 'cdr (list 7 8)) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6 7 8)
      (mongo-dict-set-add! obj 'cdr 3) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6 7 8)
      (mongo-dict-set-add! obj 'cdr 9) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6 7 8 9)
      (mongo-dict-set-add*! obj 'cdr (vector 10 11)) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6 7 8 9 10 11)
      (mongo-dict-pop! obj 'cdr) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 3 4 5 6 7 8 9 10)
      (mongo-dict-shift! obj 'cdr) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 4 5 6 7 8 9 10)
      (mongo-dict-pull! obj 'cdr 5) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 4 6 7 8 9 10)
      (mongo-dict-push! obj 'cdr 7) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 4 6 7 8 9 10 7)
      (mongo-dict-pull! obj 'cdr 7) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 4 6 8 9 10)
      (mongo-dict-pull*! obj 'cdr (vector 8 9)) => (void)
      (mongo-dict-ref obj 'cdr) => (vector 4 6 10)
      (mongo-dict-count obj) => 2
      
      (for/fold ([s (set)])
        ([(k v) (in-dict obj)])
        (set-add s (cons k v)))
      =>
      (set (cons 'cdr (vector 4 6 10))
           (cons 'car 4))
      
      (mongo-dict-ref (deserialize (serialize obj)) 'car) => 4
      ))
   
   (test-obj obj)
   (test
    (for/list ([c (mongo-dict-query "cons" empty)])
      (cons (mongo-dict-ref c 'car)
            (mongo-dict-ref c 'cdr)))
    =>
    (list (cons 4 (vector 4 6 10))))
   
   #;(exit 0)
   
   (local
     [(define-mongo-struct cons "cons"
        ([car]
         [cdr]))
      (define x (make-cons #:car 1
                           #:cdr 2))
      (define y (make-cons #:car 1))]
     (test
      (cons-car obj) => 4
      (cons-cdr obj) => (vector 4 6 10)
      (cons-car x) => 1
      (cons-cdr x) => 2
      (cons-car y) => 1
      (cons-cdr y) => bson-null
      
      ; You can go right through
      (test-obj (make-cons))))
   
   (local 
     [(define-mongo-struct cons "cons"
        ([car #:inc #:null]
         [cdr #:push #:append #:set-add #:set-add* #:pop #:shift #:pull #:pull*]))
      (define obj (make-cons))]
     (test
      
      (cons-car obj) => bson-null
      (set-cons-car! obj 1) => (void)
      (cons-car obj) => 1
      (null-cons-car! obj) => (void)
      (cons-car obj) => bson-null
      (set-cons-car! obj 1) => (void)
      (inc-cons-car! obj) => (void)
      (cons-car obj) => 2
      (inc-cons-car! obj 2) => (void)
      (cons-car obj) => 4
      (push-cons-cdr! obj 3) => (void)
      (cons-cdr obj) => (vector 3)
      (push-cons-cdr! obj 4) => (void)
      (cons-cdr obj) => (vector 3 4)
      (append-cons-cdr! obj (vector 5 6)) => (void)
      (cons-cdr obj) => (vector 3 4 5 6)
      (append-cons-cdr! obj (list 7 8)) => (void)
      (cons-cdr obj) => (vector 3 4 5 6 7 8)
      (set-add-cons-cdr! obj 3) => (void)
      (cons-cdr obj) => (vector 3 4 5 6 7 8)
      (set-add-cons-cdr! obj 9) => (void)
      (cons-cdr obj) => (vector 3 4 5 6 7 8 9)
      (set-add*-cons-cdr! obj (vector 10 11)) => (void)
      (cons-cdr obj) => (vector 3 4 5 6 7 8 9 10 11)
      (pop-cons-cdr! obj) => (void)
      (cons-cdr obj) => (vector 3 4 5 6 7 8 9 10)
      (shift-cons-cdr! obj) => (void)
      (cons-cdr obj) => (vector 4 5 6 7 8 9 10)
      (pull-cons-cdr! obj 5) => (void)
      (cons-cdr obj) => (vector 4 6 7 8 9 10)
      (push-cons-cdr! obj 7) => (void)
      (cons-cdr obj) => (vector 4 6 7 8 9 10 7)
      (pull-cons-cdr! obj 7) => (void)
      (cons-cdr obj) => (vector 4 6 8 9 10)
      (pull*-cons-cdr! obj (vector 8 9)) => (void)
      (cons-cdr obj) => (vector 4 6 10)
      
      (cons-car (deserialize (serialize obj))) => 4
      ))
   
   (local
     [(define-mongo-struct cons "cons"
        ([car #:required]
         [cdr]))]
     (test
      (make-cons #:car 1)
      (make-cons) =error> "requires"
      (make-cons #:cdr 1) =error> "requires"))
   
   (local
     [(define-mongo-struct cons "cons"
        ([car #:immutable]
         [cdr]))]
     (test
      (make-cons #:car 1)
      (make-cons) =error> "requires"
      (make-cons #:cdr 1) =error> "requires"
      (set-cons-car! (make-cons #:car 1) 2) =error> "unbound"))
   
   (test 
    (define-mongo-struct cons "cons"
      ([car #:immutable #:null]
       [cdr]))
    =error> "Immutable"
    
    (define-mongo-struct cons "cons"
      ([car #:required #:null]
       [cdr]))
    =error> "Required"
   
   (define-mongo-struct cons "cons"
      ([car #:frozzle]
       [cdr]))
    =error> "valid")
   
   ))
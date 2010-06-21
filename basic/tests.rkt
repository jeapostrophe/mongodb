#lang racket
(require "main.rkt"
         "../bson/main.rkt"
         "../lib/test.rkt"
         "../lib/seq.rkt"
         tests/eli-tester)

(test
 (with-mongod
     (define m (create-mongo))
   
   (test
    (mongo-db-names m)
    =>
    (list "admin" "local"))
   
   (define d (make-mongo-db m "test"))
   
   (test
    (mongo-db-name d)
    =>
    "test"
    
    (mongo-db-collections d)
    =>
    empty
    
    (mongo-db-create-collection! d "test1" #:capped? #f #:size 100)
    (mongo-db-create-collection! d "test2" #:capped? #f #:size 100 #:max 20)
    
    (mongo-db-collections d)
    =>
    (list "test2" "system.indexes" "test1")
    
    (mongo-db-drop-collection! d "test2")
    
    (mongo-db-collections d)
    =>
    (list "system.indexes" "test1")
    
    (mongo-db-create-collection! d "test2" #:capped? #f #:size 100 #:max 20)
    
    (mongo-db-collections d)
    =>
    (list "test2" "system.indexes" "test1")
    
    (mongo-collection-drop! (make-mongo-collection d "test2"))
    
    (mongo-db-collections d)
    =>
    (list "system.indexes" "test1")
    
    (mongo-db-drop d)
    
    (mongo-db-collections d)
    =>
    empty
    
    (mongo-db-create-collection! d "test1" #:capped? #f #:size 100)
    
    (mongo-db-collections d)
    =>
    (list "system.indexes" "test1") 
    
    (mongo-db-profiling d)
    =>
    'none
    
    (set-mongo-db-profiling! d 'all)
    (mongo-db-profiling d)
    =>
    'all
    
    (set-mongo-db-profiling! d 'low)
    (mongo-db-profiling d)
    =>
    'low
    
    (set-mongo-db-profiling! d 'none)
    (mongo-db-profiling d)
    =>
    'none
    
    (mongo-db-profiling-info d)
    
    (mongo-db-valid-collection? d "test1")
    =>
    #t
    
    (mongo-db-valid-collection? d "zog")
    =error>
    "ns not found"
    )
   
   
   (define c (make-mongo-collection d "test1"))
   (define ELEMENTS 100)
   
   (test
    (mongo-collection-valid? c) =>
    #t
    
    (mongo-collection-drop! c)
    
    (for ([i (in-range ELEMENTS)])
      (mongo-collection-insert! c (list (cons 'i i) (cons 'data (random ELEMENTS)))))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i 0)))]) (hash-ref e 'i))
    =>
    (list 0)
    
    (mongo-collection-remove! c (list (cons 'i 0)))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i 0)))]) (hash-ref e 'i))
    =>
    empty
    
    (mongo-collection-insert! c (list (cons 'i 1) (cons 'data (random ELEMENTS))))
    (mongo-collection-modify! c (list (cons 'i 1)) (list (cons '$set (list (cons 'data 5)))))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i 1)))]) (hash-ref e 'data))
    =>
    (list 5 5)
    
    (for/list ([e (mongo-collection-find c (list (cons 'i 1))
                                         #:selector (list (cons 'data 1)))])
      (hash-ref e 'data))
    =>
    (list 5 5)
    
    (mongo-collection-replace! c (list (cons 'i 1)) (list (cons 'i 1) (cons 'data 6)))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i 1)))]) (hash-ref e 'data))
    =>
    (list 6 5)
    
    (mongo-collection-repsert! c (list (cons 'i (add1 ELEMENTS)))
                               (list (cons 'i (add1 ELEMENTS))
                                     (cons 'data 0)))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i (add1 ELEMENTS))))]) (hash-ref e 'data))
    =>
    (list 0)
    
    (mongo-collection-repsert! c 
                               (list (cons 'i (add1 ELEMENTS)))
                               (list (cons 'i (add1 ELEMENTS))
                                     (cons 'data 1)))
    
    (for/list ([e (mongo-collection-find c (list (cons 'i (add1 ELEMENTS))))]) (hash-ref e 'data))
    =>
    (list 1)
    
    (mongo-collection-count c)
    =>
    (+ ELEMENTS 1)
    
    (mongo-collection-count c (list (cons 'i 0)))
    =>
    0
    
    (mongo-collection-count c (list (cons 'i 1)))
    =>
    2
    
    (sequence-count (mongo-collection-indexes c)) => 1
    
    (mongo-collection-index! c (list (cons 'i 1)))
    
    (sequence-count (mongo-collection-indexes c)) => 2
    
    (mongo-collection-index! c (list (cons 'i 2))
                             #:name "i-index")
    
    (sequence-count (mongo-collection-indexes c)) => 3
    
    (rest
     (for/list ([e (mongo-collection-indexes c)])
       (cons (hash-ref e 'name) (hash-ref e 'key #f))))
    =>
    (list (cons "((i . 1))" (make-hasheq (list (cons 'i 1))))
          (cons "i-index" (make-hasheq (list (cons 'i 2)))))
    
    
    (mongo-collection-drop-index! c "i-index")
    
    (rest
     (for/list ([e (mongo-collection-indexes c)])
       (cons (hash-ref e 'name) (hash-ref e 'key))))
    =>
    (list (cons "((i . 1))" (make-hasheq (list (cons 'i 1)))))
    
    )
   
   
   ))
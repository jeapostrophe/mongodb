#lang racket/base
(require racket/local
         racket/match
         racket/list
         racket/function
         "util.rkt"
         db/mongodb/wire/main
         tests/eli-tester)

(define ELEMENTS 100)

(module+ test
  (when mongod-p
    (test
     (with-mongod
       (define c (create-mongo-connection))
       (define the-collect "db.test")
       (define (make-a-thing i [v (random 100)])
         (make-hasheq (list (cons 'i i)
                            (cons 'data v))))

       ;; Create some stuff on the server
       (define stuff-we-made (make-hasheq))
       (for ([i (in-range ELEMENTS)])
         (define thing (make-a-thing i i))
         (test
          (send-message
           c
           (make-insert (new-msg-id) 0 the-collect
                        (vector thing)))
          =>
          #f)
         (hash-set! stuff-we-made i thing))

       ;; Update a few of them
       (for ([j (in-range (/ ELEMENTS 4))])
         (define i (random ELEMENTS))
         (define new-thing (make-a-thing i))
         (hash-set! stuff-we-made i new-thing)
         (test
          (send-message
           c
           (make-update (new-msg-id) 0 the-collect
                        empty
                        (make-hasheq (list (cons 'i i)))
                        new-thing))
          =>
          #f))

       ;; Query a few
       (for ([j (in-range (/ ELEMENTS 4))])
         (define i (random ELEMENTS))
         (define query-id (new-msg-id))
         (test
          (match
              (send-message
               c
               (make-query query-id 0 the-collect
                           empty 0 0
                           (make-hasheq (list (cons 'i i)))
                           #f))
            [(struct reply (_id (? (curry = query-id)) #f _cursor-id 0
                                (vector v)))
             (hash-remove! v '_id)
             (equal? v (hash-ref stuff-we-made i))]
            [r
             r])
          =>
          #t))

       ;; Delete something
       (local [(define gonna-die (random ELEMENTS))
               (define query-id (new-msg-id))]
         (test
          (send-message
           c
           (make-delete (new-msg-id) 0 the-collect
                        (make-hasheq (list (cons 'i gonna-die)))))
          =>
          #f

          (match
              (send-message
               c
               (make-query query-id 0 the-collect
                           empty 0 0
                           (make-hasheq (list (cons 'i gonna-die)))
                           #f))
            [(struct reply (_id (? (curry = query-id)) #f _cursor-id 0 (vector)))
             #t]
            [r r])
          =>
          #t

          (send-message
           c
           (make-insert (new-msg-id) 0 the-collect
                        (vector (make-a-thing gonna-die))))
          =>
          #f))

       ;; Duplicate something, then use cursors
       (local [(define dup (random ELEMENTS))
               (define query-id0 (new-msg-id))
               (define query-id (new-msg-id))
               (define get-more-id (new-msg-id))
               (define get-more-id2 (new-msg-id))
               (define the-cursor 999)]

         (test
          ; Add the duplicates
          (send-message
           c
           (make-insert (new-msg-id) 0 the-collect
                        (vector (make-a-thing dup))))
          =>
          #f
          (send-message
           c
           (make-insert (new-msg-id) 0 the-collect
                        (vector (make-a-thing dup))))
          =>
          #f

          ; Query them all
          (match
              (send-message
               c
               (make-query query-id0 0 the-collect
                           empty 0 3
                           (make-hasheq (list (cons 'i dup)))
                           #f))
            [(struct reply (_id (? (curry = query-id0)) #f _cid 0
                                (vector v1 v2 v3)))
             #t]
            [r
             r])
          =>
          #t

          ; Query the first and second
          (match
              (send-message
               c
               (make-query query-id 0 the-collect
                           empty 0 2
                           (make-hasheq (list (cons 'i dup)))
                           #f))
            [(struct reply (_id (? (curry = query-id)) #f cursor-id 0
                                (vector v1 v2)))
             (set! the-cursor cursor-id)
             #t]
            [r
             r])
          =>
          #t

          ; Query the third
          (match
              (send-message
               c
               (make-get-more get-more-id 0 the-collect
                              0 the-cursor))
            [(struct reply (_id (? (curry = get-more-id)) #f 0 2
                                (vector v)))
             #t]
            [r r])
          =>
          #t

          ; Delete the cursor
          (send-message
           c
           (make-kill-cursors (new-msg-id) 0 (vector the-cursor)))
          =>
          #f

          ; Try to use the cursor again (and fail)
          (match
              (send-message
               c
               (make-get-more get-more-id2 0 the-collect
                              1 the-cursor))
            [(struct reply (_id (? (curry = get-more-id2)) #t 0 0
                                (vector)))
             #t]
            [r r])
          =>
          #t))

       ; Test bytes
       (local [(define the-bytes #"1")]
         (test
          (send-message
           c
           (make-insert (new-msg-id) 0 the-collect
                        (vector (make-hasheq (list (cons 'name 'foo) (cons 'bytes the-bytes))))))
          =>
          #f

          (match
              (send-message
               c
               (make-query (new-msg-id) 0 the-collect
                           empty 0 0
                           (make-hasheq (list (cons 'name 'foo)))
                           #f))
            [(struct reply (_id _mid #f _cursor-id 0
                                (vector v)))
             (equal? the-bytes (hash-ref v 'bytes))]
            [r
             r])
          =>
          #t))

       (close-mongo-connection! c)

       ))))

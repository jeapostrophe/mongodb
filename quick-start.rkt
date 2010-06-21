#lang scheme
(require "main.rkt"
         "lib/test.rkt")

(with-mongod
    (define m (create-mongo))
  (define d (make-mongo-db m "awesome-dot-com"))
  (current-mongo-db d)
  (define-mongo-struct post "posts"
    ([title #:required]
     [body #:required]
     [tags #:set-add #:pull]
     [comments #:push #:pull]
     [views #:inc]))
  
  (define p
    (make-post #:title "Welcome to my blog"
               #:body "This is my first entry, yay!"))
  (set-add-post-tags! p 'awesome)
  (inc-post-views! p)
  
  (set-post-comments! p (list "Can't wait!" "Another blog?"))
  (post-comments p))
#lang setup/infotab
(define name "MongoDB")
(define release-notes
  (list '(ul (li "Closing connections"))))
(define repositories
  (list "4.x"))
(define blurb
  (list "A native Racket interface to MongoDB"))
(define scribblings '(("mongodb.scrbl" (multi-page))))
(define primary-file "main.rkt")
(define categories '(net io))
(define compile-omit-paths
  (list "tests.rkt"
        "quick-start.rkt"
        "basic/tests.rkt"
        "bson/tests.rkt"
        "orm/tests.rkt"
        "wire/tests.rkt"))
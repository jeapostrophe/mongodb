#lang setup/infotab
(define name "MongoDB")
(define release-notes
  (list '(ul (li "Fixed bug in BSON binary encoding"))))
(define repositories
  (list "4.x"))
(define blurb
  (list "A native Scheme interface to MongoDB"))
(define scribblings '(("mongodb.scrbl" (multi-page))))
(define primary-file "main.ss")
(define categories '(net io))
(define compile-omit-paths
  (list "tests.ss"
        "basic/tests.ss"
        "bson/tests.ss"
        "orm/tests.ss"
        "wire/tests.ss"))
#lang racket/base
(require web-server/dispatch/extend
         racket/match
         racket/function
         db/mongodb)

(define-match-expander mongo-dict/string
  (syntax-rules ()
    [(_ col d)
     (? string? (app (compose (curry make-mongo-dict col) string->bson-objectid) d))]))

(define-match-expander string/mongo-dict
  (syntax-rules ()
    [(_ col s)
     (? mongo-dict? (app (compose bson-objectid->string mongo-dict-id) s))]))

(define-bidi-match-expander mongo-dict-arg mongo-dict/string string/mongo-dict)

(provide mongo-dict-arg)

#lang scheme


(define-syntax-rule (define-mappings (lhs->rhs rhs->lhs)
                      [(lhs) rhs] ...)
  (begin (define lhs->rhs
           (make-hasheq (list (cons lhs rhs) ...)))
         (define rhs->lhs
           (make-hasheq (list (cons rhs lhs) ...)))))
(define-syntax-rule (define-mappings/pred (lhs->rhs rhs->lhs value->rhs)
                      error-msg
                      [(lhs) rhs pred] ...)
  (begin (define-mappings (lhs->rhs rhs->lhs)
           [(lhs) rhs] ...)
         (define (value->rhs x)
           (cond
             [(pred x) rhs]
             ...
             [else
              (error 'value->rhs error-msg x)]))))


(provide (all-defined-out))
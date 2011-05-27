#lang racket
(require (for-syntax syntax/parse
                     racket/list
                     unstable/syntax
                     racket/syntax)
         "dict.rkt")

(define-syntax (define-mongo-struct stx)
  (syntax-parse 
   stx
   [(_ struct:id collection:str
       ([field:id given-opt:keyword ...]
        ...))
    (with-syntax*
        ([make-struct
          (format-id stx "make-~a" #'struct)]
         [((required? opt ...) ...)
          (syntax-map (lambda (opts-stx)
                        (define opts (syntax->list opts-stx))
                        (define immutable?
                          (findf (lambda (stx)
                                   (syntax-parse 
                                    stx
                                    [#:immutable #t]
                                    [_ #f]))
                                 opts))
                        (define required?
                          (or immutable?
                              (findf (lambda (stx)
                                       (syntax-parse 
                                        stx
                                        [#:required #t]
                                        [_ #f]))
                                     opts)))
                        (define null?
                          (findf (lambda (stx)
                                       (syntax-parse 
                                        stx
                                        [#:null #t]
                                        [_ #f]))
                                     opts))
                        (define base-opts
                          (filter (lambda (stx)
                                    (syntax-parse 
                                     stx
                                     [#:required #f]
                                     [#:immutable #f]
                                     [_ #t]))
                                  opts))
                        (define ref-opts
                          (list* #'#:ref base-opts))
                        (define set-opts
                          (if immutable?
                              ref-opts
                              (list* #'#:set! ref-opts)))
                        (when (and immutable? (not (zero? (length base-opts))))
                          (raise-syntax-error 'define-mongo-struct "Immutable fields cannot have mutation operators" opts-stx (first base-opts)))
                        (when (and required? null?)
                          (raise-syntax-error 'define-mongo-struct "Required fields cannot have a null operator" opts-stx null?))
                        (cons (and required? #t) set-opts))
                      #'((given-opt ...) ...))]
         [(field-kw ...)
          (syntax-map (lambda (field)
                        (datum->syntax field (string->keyword (symbol->string (syntax->datum field)))))
                      #'(field ...))]
         [(field-arg ...)
          (for/fold ([arg-stx #'()])
            ([field (in-list (syntax->list #'(field ...)))]
             [required? (in-list (syntax->list #'(required? ...)))]
             [field-kw (in-list (syntax->list #'(field-kw ...)))])
            (if (syntax->datum required?)
                (quasisyntax/loc stx
                  (#,field-kw #,field #,@arg-stx))
                (quasisyntax/loc stx
                  (#,field-kw [#,field (void)] #,@arg-stx))))])
      (syntax/loc stx
        (begin
          (define the-collection collection)
          (define (make-struct field-arg ...)
            (define the-struct
              (create-mongo-dict the-collection))
            (unless (void? field)
              (mongo-dict-set! the-struct 'field field))
            ...
            the-struct)
          (define-mongo-struct-field struct field (opt ...))
          ...)))]))

(define-syntax (define-mongo-struct-field stx)
  (syntax-parse
   stx
   [(_ struct:id field:id (opt:keyword ...))
    (with-syntax
        ([((name fun) ...)
          (filter-map
           (lambda (stx)
             (syntax-parse 
              stx
              [#:ref 
               (list (format-id #'struct "~a-~a" #'struct #'field)
                     #'mongo-dict-ref)]
              [#:set! 
               (list (format-id #'struct "set-~a-~a!" #'struct #'field)
                     #'mongo-dict-set!)]
              [#:inc 
               (list (format-id #'struct "inc-~a-~a!" #'struct #'field)
                     #'mongo-dict-inc!)]
              [#:null 
               (list (format-id #'struct "null-~a-~a!" #'struct #'field)
                     #'mongo-dict-remove!)]
              [#:push 
               (list (format-id #'struct "push-~a-~a!" #'struct #'field)
                     #'mongo-dict-push!)]
              [#:append 
               (list (format-id #'struct "append-~a-~a!" #'struct #'field)
                     #'mongo-dict-append!)]
              [#:set-add 
               (list (format-id #'struct "set-add-~a-~a!" #'struct #'field)
                     #'mongo-dict-set-add!)]
              [#:set-add* 
               (list (format-id #'struct "set-add*-~a-~a!" #'struct #'field)
                     #'mongo-dict-set-add*!)]
              [#:pop
               (list (format-id #'struct "pop-~a-~a!" #'struct #'field)
                     #'mongo-dict-pop!)]
              [#:shift 
               (list (format-id #'struct "shift-~a-~a!" #'struct #'field)
                     #'mongo-dict-shift!)]
              [#:pull 
               (list (format-id #'struct "pull-~a-~a!" #'struct #'field)
                     #'mongo-dict-pull!)]
              [#:pull* 
               (list (format-id #'struct "pull*-~a-~a!" #'struct #'field)
                     #'mongo-dict-pull*!)]
              [_
               (raise-syntax-error 'define-mongo-struct "Invalid field option" stx)]))
           (syntax->list #'(opt ...)))])
      (syntax/loc stx
        (begin
          (define-mongo-struct-field* field name fun)
          ...)))]))

(define-syntax (define-mongo-struct-field* stx)
  (syntax-parse
   stx
   [(_ field:id name:id opt-fun:id)
    (syntax/loc stx
      (define (name the-struct . args)
        (apply opt-fun the-struct 'field args)))]))

(provide define-mongo-struct)
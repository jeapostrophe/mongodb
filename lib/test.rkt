#lang scheme
(require scheme/runtime-path
         (only-in mzlib/etc begin-with-definitions))

(define-syntax-rule (with-mongod e ...)
  (with-mongod* (lambda () (begin-with-definitions e ...))))

(define-runtime-path test-dir "../test.db")

(define (with-mongod* thnk)
  (define dbpath 
    test-dir
    #;(make-temporary-file "db~a" 'directory))
  (define sp #f)
  (dynamic-wind
   (lambda ()
     (define _ (make-directory* test-dir))
     (define-values (the-sp stdout stdin stderr)
       (subprocess (current-output-port) #f (current-error-port)
                   (find-executable-path "mongod")
                   #;"-v"
                   "--dbpath" (path->string dbpath)
                   "--nohttpinterface"
                   "--noauth"))
     (set! sp the-sp)
     (sleep 2))
   thnk
   (lambda ()
     (subprocess-kill sp #t)
     (delete-directory/files dbpath))))

(provide with-mongod)
#lang racket/base
(require racket/runtime-path
         racket/path
         racket/port
         racket/file)

(define-syntax-rule (with-mongod e ...)
  (with-mongod* (lambda () e ...)))

(define-runtime-path test-dir "../test.db")

(define mongod-p (find-executable-path "mongod"))
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
                   ;; #f #f #f
                   mongod-p
                   ;; "-v"
                   "--quiet"
                   "--nojournal"
                   "--noprealloc"
                   "--dbpath" (path->string dbpath)
                   "--nohttpinterface"
                   "--noauth"))
     (set! sp the-sp)
     (sleep 3))
   thnk
   (lambda ()
     (subprocess-kill sp #t)
     (delete-directory/files dbpath))))

(provide mongod-p with-mongod)

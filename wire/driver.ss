#lang scheme
(require unstable/contract
         "../lib/binio.ss"
         "format.ss")

(define-struct mongo-connection (input output))

(define (create-mongo-connection #:host [hostname "localhost"]
                                 #:port [port 27017])
  (call-with-values (lambda () (tcp-connect hostname port))
                    make-mongo-connection))
(define close-mongo-connection!
  (match-lambda
    [(struct mongo-connection (ip op))
     (close-input-port ip)
     (close-output-port op)]))

(define (msg-has-response? m)
  (or (query? m)
      (get-more? m)))

(define (send-message c m)
  (match-define (struct mongo-connection (ip op)) c)
  (write-msg m op)
  (if (msg-has-response? m)
      (read-msg ip)
      #f))

(define new-msg-id
  (local [(define c 0)]
    (lambda ()
      (unless (int32? c)
        (set! c 0))
      (begin0 c (set! c (add1 c))))))

(provide/contract
 [mongo-connection? contract?]
 [create-mongo-connection (() (#:host string? #:port port-number?) . ->* . mongo-connection?)]
 [close-mongo-connection! (mongo-connection? . -> . void)]
 [send-message (mongo-connection? msg? . -> . (or/c false/c reply?))]
 [new-msg-id (-> int32?)])
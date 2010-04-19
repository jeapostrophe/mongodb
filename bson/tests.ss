#lang scheme
(require "read.ss"
         "write.ss"
         "shared.ss"
         srfi/19
         tests/eli-tester)

(define (id-test v)
  (test
   (read-bson/bytes (write-bson/bytes v)) => v))

(test
 (read-bson/bytes #"\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00")
 =>
 (make-hasheq '([hello . "world"]))
 
 (read-bson/bytes #"1\x00\x00\x00\x04BSON\x00&\x00\x00\x00\x020\x00\x08\x00\x00\x00awesome\x00\x011\x00333333\x14@\x102\x00\xc2\x07\x00\x00\x00\x00")
 =>
 (make-hasheq '([BSON . #("awesome" 5.05 1986)]))
 
 (write-bson/bytes (make-hasheq '([hello . "world"])))
 =>
 #"\x16\x00\x00\x00\x02hello\x00\x06\x00\x00\x00world\x00\x00"
 
 (write-bson/bytes (make-hasheq '([BSON . #("awesome" 5.05 1986)])))
 =>
 #"1\x00\x00\x00\x04BSON\x00&\x00\x00\x00\x020\x00\x08\x00\x00\x00awesome\x00\x011\x00333333\x14@\x102\x00\xc2\x07\x00\x00\x00\x00"
 
 (id-test (make-hasheq '([hello . "world"])))
 (id-test (make-hasheq '([BSON . #("awesome" 5.05 1986)])))
 
 (id-test (make-hasheq (list (cons 'double 3.14))))
 (id-test (make-hasheq (list (cons 'utf8 "λ"))))
 (id-test (make-hasheq (list (cons 'embedded (make-hasheq (list (cons 'utf8 "λ")))))))
 (id-test (make-hasheq (list (cons 'vector (vector 1 2 3)))))
 
 (read-bson/bytes (write-bson/bytes (make-hasheq (list (cons 'seq (list 1 2 3))))))
 =>
 (make-hasheq (list (cons 'seq (vector 1 2 3))))
 
 (read-bson/bytes (write-bson/bytes (list (cons 'seq (list 1 2 3)))))
 =>
 (make-hasheq (list (cons 'seq (vector 1 2 3))))
 
 (id-test (make-hasheq (list (cons 'binary (make-bson-binary 'function #"blob")))))
 (id-test (make-hasheq (list (cons 'binary #"blob"))))
 
 (read-bson/bytes (write-bson/bytes (make-hasheq (list (cons 'binary (make-bson-binary 'binary #"\4\0\0\0blob"))))))
 =>
 (make-hasheq (list (cons 'binary #"blob")))
 
 (bson-objectid-timestamp (new-bson-objectid))
 
 (id-test (make-hasheq (list (cons 'binary (make-bson-binary 'uuid #"blob")))))
 (id-test (make-hasheq (list (cons 'binary (make-bson-binary 'md5 #"blob")))))
 (id-test (make-hasheq (list (cons 'binary (make-bson-binary 'user-defined #"blob")))))
 ; undefined
 (id-test (make-hasheq (list (cons 'oid (new-bson-objectid)))))
 (id-test (make-hasheq (list (cons 'true #t))))
 (id-test (make-hasheq (list (cons 'false #f))))
 (id-test (make-hasheq (list (cons 'utc-datetime (make-bson-utc-datetime (current-milliseconds))))))
 (id-test (make-hasheq (list (cons 'utc-datetime (current-time)))))
 (id-test (make-hasheq (list (cons 'null bson-null))))
 (id-test (make-hasheq (list (cons 'regexp (make-bson-regexp "something" "i" )))))
 ; db-pointer
 (id-test (make-hasheq (list (cons 'js (make-bson-javascript "int x = 1;")))))
 (id-test (make-hasheq (list (cons 'symbol 'symbol))))
 (id-test (make-hasheq (list (cons 'js (make-bson-javascript/scope "int x = a;"
                                                                   (make-hasheq (list (cons 'a 1))))))))
 (id-test (make-hasheq (list (cons 'int32 4))))
 (id-test (make-hasheq (list (cons 'timestamp (make-bson-timestamp 132767)))))
 (id-test (make-hasheq (list (cons 'int64 132767))))
 (id-test (make-hasheq (list (cons 'min-key bson-min-key))))
 (id-test (make-hasheq (list (cons 'max-key bson-max-key))))
 
 )
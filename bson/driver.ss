#lang scheme
(require "read.ss"
         "write.ss"
         "main.ss")

(provide/contract
 [read-bson (input-port? . -> . bson-document/c)]
 [read-bson/bytes (bytes? . -> . bson-document/c)]
 [rename prepare-document prepare-bson (bson-document/c . -> . (values exact-integer? (output-port? . -> . void)))]
 [write-bson (bson-document/c output-port? . -> . void)]
 [write-bson/bytes (bson-document/c . -> . bytes?)])
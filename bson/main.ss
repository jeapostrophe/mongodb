#lang scheme
(require "shared.ss"
         "../lib/binio.ss")

(define bson-document/c
  bson-dict?)
(define bson-sequence/c
  bson-sequence?)

(provide
 int32?
 int64?)
(provide/contract
 [bson-document/c contract?]
 
 [bson-min-key? contract?]
 [bson-min-key bson-min-key?]

 [bson-max-key? contract?]
 [bson-max-key bson-max-key?]
 
 [bson-null? contract?]
 [bson-null bson-null?]
 
 [struct bson-timestamp ([value int64?])]
 [struct bson-javascript ([string string?])]
 [struct bson-javascript/scope ([string string?]
                                [scope bson-document/c])]
 [struct bson-binary ([type (symbols 'function 'binary 'uuid 'md5 'user-defined)]
                      [bs bytes?])]
 [struct bson-regexp ([pattern string?]
                      ; XXX more constraints on this
                      [options string?])]
 
 [bson-objectid? contract?]
 [string->bson-objectid (string? . -> . bson-objectid?)]
 [bson-objectid->string (bson-objectid? . -> . string?)]
 [new-bson-objectid (-> bson-objectid?)]
 [bson-objectid-timestamp (bson-objectid? . -> . exact-integer?)]
 
 [bson-sequence/c contract?])
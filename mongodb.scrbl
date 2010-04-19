#lang scribble/doc
@(require (planet cce/scheme:6/planet)
          (planet cce/scheme:6/scribble)
          scribble/manual
          (for-label scheme
                     (only-in srfi/19
                              time? time-type time-utc)
                     "main.ss"))

@title{MongoDB}
@author{@(author+email "Jay McCarthy" "jay@plt-scheme.org")}

@defmodule/this-package[]

This package provides an interface to @link["http://www.mongodb.org/"]{MongoDB}. It supports and exposes features of MongoDB 1.3, if you use it with an older version they may silently fail.

@table-of-contents[]

@section{Quickstart}

Here's a little snippet that uses the API.

@schemeblock[
 (define m (create-mongo))
 (define d (make-mongo-db m "awesome-dot-com"))
 (define-mongo-struct post "posts"
   ([title #:required]
    [body #:required]
    [tags #:set-add #:pull]
    [comments #:push #:pull]
    [views #:inc]))
 
 (define p
   (make-post #:title "Welcome to my blog"
              #:body "This is my first entry, yay!"))
 (set-add-post-tags! p 'awesome)
 (inc-post-views! p)
 
 (set-post-comments! p (list "Can't wait!" "Another blog?"))
 (post-comments p)
 ]             

@section{BSON}

@defmodule/this-package[bson/main]

MongoDB depends on @link["http://bsonspec.org/"]{BSON}. This module contains an encoding of BSON values as Scheme values.

A @deftech{BSON document} is a dictionary that maps symbols to @tech{BSON values}.

A @deftech{BSON value} is either
@itemlist[
 @item{ An @scheme[inexact?] @scheme[real?] number }
 @item{ A @scheme[string?] }
 @item{ A @tech{BSON document} }
 @item{ A @tech{BSON sequence} }
 @item{ A @scheme[bson-binary?] or @scheme[bytes?]}
 @item{ A @scheme[bson-objectid?] }
 @item{ A @scheme[boolean?] }
 @item{ A SRFI 19 @scheme[time?] where @scheme[time-type] equals @scheme[time-utc] }
 @item{ A @scheme[bson-null?] }
 @item{ A @scheme[bson-regexp?] }
 @item{ A @scheme[bson-javascript?] }
 @item{ A @scheme[symbol?] }
 @item{ A @scheme[bson-javascript/scope?] }
 @item{ A @scheme[int32?] }
 @item{ A @scheme[bson-timestamp?] }
 @item{ A @scheme[int64?] }
 @item{ @scheme[bson-min-key] }
 @item{ @scheme[bson-max-key] }
]

A @deftech{BSON sequence} is sequence of @tech{BSON values}.

@defproc[(int32? [x any/c]) boolean?]{ A test for 32-bit integers.}
@defproc[(int64? [x any/c]) boolean?]{ A test for 64-bit integers.}
@defthing[bson-document/c contract?]{A contract for @tech{BSON documents}.}
@defthing[bson-sequence/c contract?]{ A contract for @tech{BSON sequences}. }

A few BSON types do not have equivalents in Scheme.

@defproc[(bson-min-key? [x any/c]) boolean?]{ A test for @scheme[bson-min-key]. }
@defthing[bson-min-key bson-min-key?]{ The smallest BSON value. }
@defproc[(bson-max-key? [x any/c]) boolean?]{ A test for @scheme[bson-max-key]. }
@defthing[bson-max-key bson-max-key?]{ The largest BSON value. }
@defproc[(bson-null? [x any/c]) boolean?]{ A test for @scheme[bson-null]. }
@defthing[bson-null bson-null?]{ The missing BSON value. }
@defstruct[bson-timestamp ([value int64?])]{ A value representing an internal MongoDB type. }
@defproc[(bson-objectid? [x any/c]) boolean?]{ A test for BSON @link["http://www.mongodb.org/display/DOCS/Object+IDs"]{ObjectId}s, an internal MongoDB type. }
@defproc[(new-bson-objectid) bson-objectid?]{ Returns a fresh ObjectId. }
@defproc[(bson-objectid-timestamp [oid bson-objectid?]) exact-integer?]{ Returns the part of the ObjectID conventionally representing a timestamp. }

A few BSON types have equivalents in Scheme, but because of additional tagging of them in BSON, we have to create structures to preserve the tagging.

@defstruct[bson-javascript ([string string?])]{ A value representing Javascript code. }
@defstruct[bson-javascript/scope ([string string?] [scope bson-document/c])]{ A value representing Javascript code and its scope. }
@defstruct[bson-binary ([type (symbols 'function 'binary 'uuid 'md5 'user-defined)] [bs bytes?])]{ A value representing binary data. }
@defstruct[bson-regexp ([pattern string?] [options string?])]{ A value representing a regular expression. }

@subsection{Decoding Conventions}

Only @scheme[make-hasheq] dictionaries are returned as @tech{BSON documents}.

A @scheme[bson-binary?] where @scheme[bson-binary-type] is equal to @scheme['binary] is never returned. It is converted to @scheme[bytes?].

Only @scheme[vector] sequences are returned as @tech{BSON sequences}.

@section{Basic Operations}

@defmodule/this-package[basic/main]

The basic API of MongoDB is provided by this module.

@subsection{Servers}

@defproc[(mongo? [x any/c]) boolean?]{ A test for Mongo servers. }

@defproc[(create-mongo [#:host host string "localhost"]
                       [#:port port port-number? 27017])
         mongo?]{
 Creates a connection to the specified Mongo server.
 }

@defproc[(mongo-list-databases [m mongo?])
         (vectorof bson-document/c)]{
 Returns information about the databases on a server.
 }

@defproc[(mongo-db-names [m mongo?])
         (listof string?)]{
 Returns the names of the databases on the server.
 }
         
@subsection{Databases}

@defstruct[mongo-db ([mongo mongo?] [name string?])]{ A structure representing a Mongo database. }

@defproc[(mongo-db-execute-command! [db mongo-db?] [cmd bson-document/c])
         bson-document/c]{
 Executes command @scheme[cmd] on the database @scheme[db] and returns Mongo's response. Refer to @link["http://www.mongodb.org/display/DOCS/List+of+Database+Commands"]{List of Database Commands} for more details.
}
                         
@defproc[(mongo-db-collections [db mongo-db?])
         (listof string?)]{
 Returns a list of collection names in the database.
 }
                          
@defproc[(mongo-db-create-collection! [db mongo-db?]
                                      [name string?]
                                      [#:capped? capped? boolean?]
                                      [#:size size number?]
                                      [#:max max (or/c false/c number?) #f])
         mongo-collection?]{
 Creates a new collection in the database and returns a handle to it. Refer to @link["http://www.mongodb.org/display/DOCS/Capped+Collections"]{Capped Collections} for details on the options.
}

@defproc[(mongo-db-drop-collection! [db mongo-db?]
                                    [name string?])
         bson-document/c]{
 Drops a collection from the database.
 }
                         
@defproc[(mongo-db-drop [db mongo-db?])
         bson-document/c]{
 Drops a database from its server.
 }
                       
@defthing[mongo-db-profiling/c contract?]{ Defined as @scheme[(symbols 'none 'low 'all)]. }
@defproc[(mongo-db-profiling [db mongo-db?]) mongo-db-profiling/c]{ Returns the profiling level of the database. }
@defproc[(set-mongo-db-profiling! [db mongo-db?] [v mongo-db-profiling/c]) boolean?]{ Sets the profiling level of the database. Returns @scheme[#t] on success. }

@defproc[(mongo-db-profiling-info [db mongo-db?]) bson-document/c]{ Returns the profiling information from the database. Refer to @link["http://www.mongodb.org/display/DOCS/Database+Profiler"]{Database Profiler} for more details. }

@defproc[(mongo-db-valid-collection? [db mongo-db?] [name string?]) boolean?]{ Returns @scheme[#t] if @scheme[name] is a valid collection. }
                          
@subsection{Collections}

@defstruct[mongo-collection ([db mongo-db?] [name string?])]{ A structure representing a Mongo collection. }

@defproc[(mongo-collection-drop! [mc mongo-collection?]) void]{ Drops the collection from its database. }
@defproc[(mongo-collection-valid? [mc mongo-collection?]) boolean?]{ Returns @scheme[#t] if @scheme[mc] is a valid collection. }
@defproc[(mongo-collection-full-name [mc mongo-collection?]) string?]{ Returns the full name of the collection. }
@defproc[(mongo-collection-find [mc mongo-collection?]
                                [query bson-document/c]
                                [#:tailable? tailable? boolean? #f]
                                [#:slave-okay? slave-okay? boolean? #f]
                                [#:no-timeout? no-timeout? boolean? #f]
                                [#:selector selector (or/c false/c bson-document/c) #f]
                                [#:skip skip int32? 0]
                                [#:limit limit (or/c false/c int32?) #f])
         mongo-cursor?]{
 Performs a query in the collection. Refer to @link["http://www.mongodb.org/display/DOCS/Querying"]{Querying} for more details.
 
 If @scheme[limit] is @scheme[#f], then a limit of @scheme[2] is sent. This is the smallest limit that creates a server-side cursor, because @scheme[1] is interpreted as @scheme[-1].
 }

@defproc[(mongo-collection-insert-docs! [mc mongo-collection?] [docs (sequenceof bson-document/c)]) void]{ Inserts a sequence of documents into the collection. }
@defproc[(mongo-collection-insert-one! [mc mongo-collection?] [doc bson-document/c]) void]{ Insert an document into the collection. }
@defproc[(mongo-collection-insert! [mc mongo-collection?] [doc bson-document/c] ...) void]{ Inserts any number of documents into the collection. }

@defproc[(mongo-collection-remove! [mc mongo-collection?] [sel bson-document/c]) void]{ Removes documents matching the selector. Refer to @link[
"http://www.mongodb.org/display/DOCS/Removing"]{Removing} for more details. }

@defproc[(mongo-collection-modify! [mc mongo-collection?] [sel bson-document/c] [mod bson-document/c]) void]{ Modifies all documents matching the selector according to @scheme[mod]. Refer to @link[
"http://www.mongodb.org/display/DOCS/Updating#Updating-ModifierOperations"]{Modifier Operations} for more details. }

@defproc[(mongo-collection-replace! [mc mongo-collection?] [sel bson-document/c] [doc bson-document/c]) void]{ Replaces the first document matching the selector with @scheme[obj]. }

@defproc[(mongo-collection-repsert! [mc mongo-collection?] [sel bson-document/c] [doc bson-document/c]) void]{ If a document matches the selector, it is replaced; otherwise the document is inserted. Refer to @link[
"http://www.mongodb.org/display/DOCS/Updating#Updating-UpsertswithModifiers"]{Upserts with Modifiers} for more details on using modifiers. }

@defproc[(mongo-collection-count [mc mongo-collection?] [query bson-document/c empty]) exact-integer?]{ Returns the number of documents matching the query. }

@subsubsection{Indexing}

Refer to @link["http://www.mongodb.org/display/DOCS/Indexes"]{Indexes} for more details on indexing.

@defproc[(mongo-collection-index! [mc mongo-collection?] [spec bson-document/c] [name string? ....]) void]{ Creates an index of the collection. A name will be automatically generated if not specified. }
@defproc[(mongo-collection-indexes [mc mongo-collection?]) mongo-cursor?]{ Queries for index information. }
@defproc[(mongo-collection-drop-index! [mc mongo-collection?] [name string?]) void]{ Drops an index by name. }

@subsection{Cursors}

Query results are returned as @tech{Mongo cursors}.

A @deftech{Mongo cursor} is a sequence of @tech{BSON documents}.

@defproc[(mongo-cursor? [x any/c]) boolean?]{ A test for @tech{Mongo cursors}. }
@defproc[(mongo-cursor-done? [mc mongo-cursor?]) boolean?]{ Returns @scheme[#t] if the cursor has no more answers. @scheme[#f] otherwise. }
@defproc[(mongo-cursor-kill! [mc mongo-cursor?]) void]{ Frees the server resources for the cursor. }

@section{ORM Operations}

@defmodule/this-package[orm/main]

An "ORM" style API is built on the basic Mongo operations.

@subsection{Dictionaries}

@defmodule/this-package[orm/dict]

A @deftech{Mongo dictionary} is a dictionary backed by Mongo.

@defproc[(create-mongo-dict [col string?]) mongo-dict?]{ Creates a new @tech{Mongo dictionary} in the @scheme[col] collection of the @scheme[(current-mongo-db)] database. }

@defproc[(mongo-dict-query [col string?] [query bson-document/c]) (sequenceof mongo-dict?)]{ Queries the collection and returns @tech{Mongo dictionaries}. }

@defproc[(mongo-dict? [x any/c]) boolean?]{ A test for @tech{Mongo dictionaries}. }
@defparam[current-mongo-db db (or/c false/c mongo-db?)]{ The database used in @tech{Mongo dictionary} operations. }
@defproc[(mongo-dict-ref [md mongo-dict?] [key symbol?] [fail any/c bson-null]) any/c]{ Like @scheme[dict-ref] but for @tech{Mongo dictionaries}, returns @scheme[bson-null] by default on errors or missing values. }
@defproc[(mongo-dict-set! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Like @scheme[dict-set!] but for @tech{Mongo dictionaries}. }
@defproc[(mongo-dict-remove! [md mongo-dict?] [key symbol?]) void]{ Like @scheme[dict-remove!] but for @tech{Mongo dictionaries}. }
@defproc[(mongo-dict-count [md mongo-dict?]) exact-nonnegative-integer?]{ Like @scheme[dict-count] but for @tech{Mongo dictionaries}. }

@defproc[(mongo-dict-inc! [md mongo-dict?] [key symbol?] [amt number? 1]) void]{ Increments @scheme[key]'s value by @scheme[amt] atomically. }
@defproc[(mongo-dict-push! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Pushes a value onto the sequence atomically. }
@defproc[(mongo-dict-append! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Pushes a sequence of values onto the sequence atomically. }
@defproc[(mongo-dict-set-add! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Adds a value to the sequence if it is not present atomically. }
@defproc[(mongo-dict-set-add*! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Adds a sequence of values to the sequence if they are not present atomically. }
@defproc[(mongo-dict-pop! [md mongo-dict?] [key symbol?]) void]{ Pops a value off the sequence atomically. }
@defproc[(mongo-dict-shift! [md mongo-dict?] [key symbol?]) void]{ Shifts a value off the sequence atomically. }
@defproc[(mongo-dict-pull! [md mongo-dict?] [key symbol?] [val any/c]) void]{ Remove a value to the sequence if it is present atomically. }
@defproc[(mongo-dict-pull*! [md mongo-dict?] [key symbol?] [vals sequence?]) void]{ Removes a sequence of values to the sequence if they are present atomically. }

@subsection{Structures}

@defmodule/this-package[orm/struct]

@scheme[define-mongo-struct] is a macro to create some convenience functions for @tech{Mongo dictionaries}.

@defform/subs[(define-mongo-struct struct collection
                ([field opt ...]
                 ...))
              ([opt #:required #:immutable
                    #:ref #:set! #:inc #:null #:push #:append #:set-add #:set-add* #:pop #:shift #:pull #:pull*])
              #:contracts ([struct identifier?]
                           [collection string?]
                           [field identifier?])]{
 Defines @scheme[make-struct] and a set of operations for the fields.
         
 Every field implicitly has the @scheme[#:ref] option. Every mutable field implicitly has the @scheme[#:set!] option. Every immutable field implicitly has the @scheme[#:required] option. It is an error for an immutable field to have any options other than @scheme[#:required] and @scheme[#:ref], which are both implicit.
 
 @scheme[make-struct] takes one keyword argument per field. If the field does not have the @scheme[#:required] option, the argument is optional and the instance will not contain a value for the field. @scheme[make-struct] returns a @scheme[mongo-dict?].
 
 If a field has the @scheme[#:ref] option, then @scheme[struct-field] is defined. It is implemented with @scheme[mongo-dict-ref].
 
 If a field has the @scheme[#:set] option, then @scheme[set-struct-field!] is defined. It is implemented with @scheme[mongo-dict-set!].
 
 If a field has the @scheme[#:inc] option, then @scheme[inc-struct-field!] is defined. It is implemented with @scheme[mongo-dict-inc!].
 
 If a field has the @scheme[#:null] option, then @scheme[null-struct-field!] is defined. It is implemented with @scheme[mongo-dict-remove!].
 
 If a field has the @scheme[#:push] option, then @scheme[push-struct-field!] is defined. It is implemented with @scheme[mongo-dict-push!].
 
 If a field has the @scheme[#:append] option, then @scheme[append-struct-field!] is defined. It is implemented with @scheme[mongo-dict-append!].
 
 If a field has the @scheme[#:set-add] option, then @scheme[set-add-struct-field!] is defined. It is implemented with @scheme[mongo-dict-set-add!].
 
 If a field has the @scheme[#:set-add*] option, then @scheme[set-add*-struct-field!] is defined. It is implemented with @scheme[mongo-dict-set-add*!].
 
 If a field has the @scheme[#:pop] option, then @scheme[pop-struct-field!] is defined. It is implemented with @scheme[mongo-dict-pop!].
 
 If a field has the @scheme[#:shift] option, then @scheme[shift-struct-field!] is defined. It is implemented with @scheme[mongo-dict-shift!].
 
 If a field has the @scheme[#:pull] option, then @scheme[pull-struct-field!] is defined. It is implemented with @scheme[mongo-dict-pull!].
 
 If a field has the @scheme[#:pull*] option, then @scheme[pull*-struct-field!] is defined. It is implemented with @scheme[mongo-dict-pull*!].
 
}

@section{Other}

@subsection{Dispatch Rules}

@(require (for-label "dispatch.ss"))

@defmodule/this-package[dispatch]

This module requires at least revision 18724 (committed on April 2nd, 2010) of PLT Scheme.

@defform[(mongo-dict-arg col) #:contracts ([col string?])]{
A bi-directional match expander for @schememodname[web-server/dispatch] that serializes to and from @tech{Mongo dictionaries} from the @scheme[col] collection.
}

                                                                                                
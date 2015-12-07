(cl:in-package #:common-lisp-user)

(defpackage #:cluffer
  (:use #:common-lisp)
  (:export
   #:buffer
   #:line
   #:cursor
   #:item-count
   #:cursor-attached-p
   #:cursor-position
   #:beginning-of-line-p
   #:end-of-line-p
   #:forward-item
   #:backward-item
   #:beginning-of-line
   #:end-of-line
   #:item-before-cursor
   #:item-after-cursor
   #:insert-item
   #:delete-item
   #:erase-item))

(defpackage #:cluffer-base
  (:use #:common-lisp)
  (:export))
(cl:in-package #:asdf-user)

(defsystem :cluffer-base
  :serial t
  :components
  ((:file "packages")
   (:file "edit-protocol")
   (:file "methods")))
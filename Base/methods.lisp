(cl:in-package #:cluffer-base)

;;; This :AFTER method calls the function NOTIFY-ITEM-COUNT-CHANGED in
;;; the internal protocol.
(defmethod cluffer:insert-item :after ((cursor cluffer:cursor) item)
  (let* ((line (cluffer:line cursor))
	 (dock (cluffer-internal:dock line)))
    (cluffer-internal:notify-item-count-changed dock 1)))

;;; This :AFTER method calls the function NOTIFY-ITEM-COUNT-CHANGED in
;;; the internal protocol.
(defmethod cluffer:delete-item :after ((cursor cluffer:cursor))
  (let* ((line (cluffer:line cursor))
	 (dock (cluffer-internal:dock line)))
    (cluffer-internal:notify-item-count-changed dock -1)))

;;; This :AFTER method calls the function NOTIFY-ITEM-COUNT-CHANGED in
;;; the internal protocol.
(defmethod cluffer:erase-item :after ((cursor cluffer:cursor))
  (let* ((line (cluffer:line cursor))
	 (dock (cluffer-internal:dock line)))
    (cluffer-internal:notify-item-count-changed dock -1)))

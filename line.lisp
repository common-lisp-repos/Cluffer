(cl:in-package #:cluffer-line)

(defclass line (cluffer-buffer:line)
   ((%contents :initarg :contents :accessor contents)
    (%cursors :initarg :cursors :accessor cursors)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Open line.
;;; 
;;; The items of an open line are stored in a gap buffer.

(defclass open-line (line)
  ((%gap-start :initarg :gap-start :accessor gap-start)
   (%gap-end :initarg :gap-end :accessor gap-end)))

;;; At the moment, we represent open cursors and a closed cursors the
;;; same way, where the position is the logical position in the line.
;;; Later, we might represent open cursors by the physical position in
;;; the gap vector so as to avoid updating cursors when items are
;;; inserted.  On the other hand, that would be an important
;;; optimization only if the number of cursors is very large.
(defclass open-cursor-mixin ()
  ((%cursor-position
    :initarg :cursor-position
    :accessor cluffer-buffer:cursor-position)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class CLOSED-LINE. 
;;; 
;;; The contents of a closed line is a vector of items.  At the
;;; moment, it is always a simple vector.

(defclass closed-line (line) ())

(defclass closed-cursor-mixin ()
  ((%cursor-position
    :initarg :cursor-position
    :accessor cluffer-buffer:cursor-position)))

(defclass closed-left-sticky-cursor
    (cluffer-buffer:attached-cursor
     closed-cursor-mixin
     cluffer-buffer:left-sticky-mixin)
  ())

(defclass closed-right-sticky-cursor
    (cluffer-buffer:attached-cursor
     closed-cursor-mixin
     cluffer-buffer:right-sticky-mixin)
  ())

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class OPEN-LEFT-STICKY CURSOR.

(defclass open-left-sticky-cursor
    (cluffer-buffer:attached-cursor
     open-cursor-mixin
     cluffer-buffer:left-sticky-mixin)
  ())

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Class OPEN-RIGHT-STICKY CURSOR.

(defclass open-right-sticky-cursor
    (cluffer-buffer:attached-cursor
     open-cursor-mixin
     cluffer-buffer:right-sticky-mixin)
  ())

(defmethod cluffer-buffer:item-count ((line open-line))
  (- (length (contents line)) (- (gap-end line) (gap-start line))))

(defmethod cluffer-buffer:item-count ((line closed-line))
  (length (contents line)))

(defun make-empty-line ()
  (make-instance 'open-line
    :cursors '()
    :contents (make-array 32 :initial-element 0)
    :gap-start 0
    :gap-end 32))
    
(setq cluffer-buffer:*empty-line-constructor* 'make-empty-line)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on ITEMS.

(defmethod cluffer-buffer:items ((line open-line) &key (start 0) (end nil))
  (close-line line)
  (cluffer-buffer:items line :start start :end end))

;;; When all the items are asked for, we do not allocate a fresh
;;; vector.  This means that client code is not allowed to mutate the
;;; return value of this function
(defmethod cluffer-buffer:items ((line closed-line) &key (start 0) (end nil))
  (if (and (= start 0) (null end))
      (contents line)
      (subseq (contents line) start end)))

(defgeneric close-cursor (cursor))

(defmethod close-cursor ((cursor open-left-sticky-cursor))
  (change-class cursor 'closed-left-sticky-cursor))
  
(defmethod close-cursor ((cursor open-right-sticky-cursor))
  (change-class cursor 'closed-right-sticky-cursor))

(defgeneric close-line (line))

(defmethod close-line ((line closed-line))
  nil)

(defmethod close-line ((line open-line))
  (mapc #'close-cursor (cursors line))
  (let* ((item-count (cluffer-buffer:item-count line))
	 (contents (contents line))
	 (new-contents (make-array item-count)))
    (replace new-contents contents
	     :start1 0 :start2 0 :end2 (gap-start line))
    (replace new-contents contents
	     :start1 (gap-start line) :start2 (gap-end line))
    (change-class line 'closed-line
		  :contents new-contents)
    nil))

(defgeneric open-cursor (cursor))

(defmethod open-cursor ((cursor closed-left-sticky-cursor))
  (change-class cursor 'open-left-sticky-cursor))
  
(defmethod open-cursor ((cursor closed-right-sticky-cursor))
  (change-class cursor 'open-right-sticky-cursor))

(defgeneric open-line (line))

(defmethod open-line ((line open-line))
  nil)

(defmethod open-line ((line closed-line))
  (mapc #'open-cursor (cursors line))
  (let* ((contents (contents line))
	 (item-count (length contents))
	 (new-length (max 32 item-count))
	 (new-contents (make-array new-length)))
    (replace new-contents contents
	     :start1 (- new-length item-count) :start2 0)
    (change-class line 'open-line
		  :contents new-contents
		  :gap-start 0
		  :gap-end (- new-length item-count))
    nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Detaching and attaching a cursor.

(defmethod cluffer-buffer:attach-cursor
    ((cursor cluffer-buffer:attached-cursor) line &optional position)
  (declare (ignore line position))
  (error 'cluffer-buffer:cursor-attached))

(defmethod cluffer-buffer:attach-cursor
    ((cursor cluffer-buffer:detached-left-sticky-cursor)
     (line open-line)
     &optional
       (position 0))
  (when (> position (cluffer-buffer:item-count line))
    (error 'cluffer-buffer:end-of-line))
  (push cursor (cursors line))
  (change-class cursor 'open-left-sticky-cursor
		:line line
		:cursor-position position)
  nil)

(defmethod cluffer-buffer:attach-cursor
    ((cursor cluffer-buffer:detached-left-sticky-cursor)
     (line closed-line)
     &optional
       (position 0))
  (when (> position (cluffer-buffer:item-count line))
    (error 'cluffer-buffer:end-of-line))
  (push cursor (cursors line))
  (change-class cursor 'closed-left-sticky-cursor
		:line line
		:cursor-position position)
  nil)
  
(defmethod cluffer-buffer:attach-cursor
    ((cursor cluffer-buffer:detached-right-sticky-cursor)
     (line open-line)
     &optional
       (position 0))
  (when (> position (cluffer-buffer:item-count line))
    (error 'cluffer-buffer:end-of-line))
  (push cursor (cursors line))
  (change-class cursor 'open-right-sticky-cursor
		:line line
		:cursor-position position)
  nil)

(defmethod cluffer-buffer:attach-cursor
    ((cursor cluffer-buffer:detached-right-sticky-cursor)
     (line closed-line)
     &optional
       (position 0))
  (when (> position (cluffer-buffer:item-count line))
    (error 'cluffer-buffer:end-of-line))
  (push cursor (cursors line))
  (change-class cursor 'closed-right-sticky-cursor
		:line line
		:cursor-position position)
  nil)

(defmethod cluffer-buffer:detach-cursor
    ((cursor cluffer-buffer:detached-cursor))
  (error 'cluffer-buffer:cursor-detached))

(defmethod cluffer-buffer:detach-cursor
  ((cursor cluffer-buffer:left-sticky-mixin))
  (setf (cursors (cluffer-buffer:line cursor))
	(remove cursor (cursors (cluffer-buffer:line cursor))))
  (change-class cursor 'cluffer-buffer:detached-left-sticky-cursor)
  nil)

(defmethod cluffer-buffer:detach-cursor
  ((cursor cluffer-buffer:right-sticky-mixin))
  (setf (cursors (cluffer-buffer:line cursor))
	(remove cursor (cursors (cluffer-buffer:line cursor))))
  (change-class cursor 'cluffer-buffer:detached-right-sticky-cursor)
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Operations on cursors.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on BEGINNING-OF-LINE-P.
;;;
;;; Given a cursor, return true if and only if it is at the beginning
;;; of the line.

(defmethod cluffer-buffer:beginning-of-line-p
    ((cursor cluffer-buffer:detached-cursor))
  (error 'cluffer-buffer:cursor-detached))

;;; The default method just calls CURSOR-POSITION and returns true if
;;; and only if that position is 0.
(defmethod cluffer-buffer:beginning-of-line-p
    ((cursor cluffer-buffer:attached-cursor))
  (zerop (cluffer-buffer:cursor-position cursor)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on END-OF-LINE-P.

(defmethod cluffer-buffer:end-of-line-p
    ((cursor cluffer-buffer:detached-cursor))
  (error 'cluffer-buffer:cursor-detached))

;;; The default method just calls CURSOR-POSITION and returns true if
;;; and only if that position is the same as the number of items in
;;; the line.
(defmethod cluffer-buffer:end-of-line-p
    ((cursor cluffer-buffer:attached-cursor))
  (= (cluffer-buffer:cursor-position cursor)
     (cluffer-buffer:item-count (cluffer-buffer:line cursor))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on INSERT-ITEM.

(defmethod cluffer-buffer:insert-item ((cursor closed-cursor-mixin) item)
  (open-line (cluffer-buffer:line cursor))
  (cluffer-buffer:insert-item cursor item))

(defmethod cluffer-buffer:insert-item ((cursor open-cursor-mixin) item)
  (let* ((pos (cluffer-buffer:cursor-position cursor))
	 (line (cluffer-buffer:line cursor))
	 (contents (contents line)))
    (cond ((= (gap-start line) (gap-end line))
	   (let* ((new-length (* 2 (length contents)))
		  (diff (- new-length (length contents)))
		  (new-contents (make-array new-length)))
	     (replace new-contents contents
		      :start2 0 :start1 0 :end2 pos)
	     (replace new-contents contents
		      :start2 pos :start1 (+ pos diff))
	     (setf (gap-start line) pos)
	     (setf (gap-end line) (+ pos diff))
	     (setf (contents line) new-contents)))
	  ((< pos (gap-start line))
	   (decf (gap-end line) (- (gap-start line) pos))
	   (replace contents contents
		    :start2 pos :end2 (gap-start line)
		    :start1 (gap-end line))
	   (setf (gap-start line) pos))
	  ((> pos (gap-start line))
	   (replace contents contents
		    :start2 (gap-end line)
		    :start1 (gap-start line) :end1 pos)
	   (incf (gap-end line) (- pos (gap-start line)))
	   (setf (gap-start line) pos))
	  (t
	   nil))
    (setf (aref (contents line) (gap-start line)) item)
    (incf (gap-start line))
    (loop for cursor in (cursors line)
	  do (when (or (and (typep cursor 'cluffer-buffer:right-sticky-mixin)
			    (>= (cluffer-buffer:cursor-position cursor) pos))
		       (and (typep cursor 'cluffer-buffer:left-sticky-mixin)
			    (> (cluffer-buffer:cursor-position cursor) pos)))
	       (incf (cluffer-buffer:cursor-position cursor)))))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on DELETE-ITEM.

(defmethod cluffer-buffer:delete-item ((cursor closed-cursor-mixin))
  (open-line (cluffer-buffer:line cursor))
  (cluffer-buffer:delete-item cursor))

(defmethod cluffer-buffer:delete-item ((cursor open-cursor-mixin))
  (when (cluffer-buffer:end-of-line-p cursor)
    (error 'cluffer-buffer:end-of-line))
  (let* ((pos (cluffer-buffer:cursor-position cursor))
	 (line (cluffer-buffer:line cursor))
	 (contents (contents line)))
    (cond ((< pos (gap-start line))
	   (decf (gap-end line) (- (gap-start line) pos))
	   (replace contents contents
		    :start2 pos :end2 (gap-start line)
		    :start1 (gap-end line))
	   (setf (gap-start line) pos))
	  ((> pos (gap-start line))
	   (replace contents contents
		    :start2 (gap-end line)
		    :start1 (gap-start line) :end1 pos)
	   (incf (gap-end line) (- pos (gap-start line)))
	   (setf (gap-start line) pos))
	  (t
	   nil))
    (setf (aref contents (gap-end line)) 0)  ; for the GC
    (incf (gap-end line))
    (when (and (> (length contents) 32)
	       (> (- (gap-end line) (gap-start line))
		  (* 3/4 (length contents))))
      (let* ((new-length (floor (length contents) 2))
	     (diff (- (length contents) new-length))
	     (new-contents (make-array new-length)))
	(replace new-contents contents
		 :start2 0 :start1 0 :end2 (gap-start line))
	(replace new-contents contents
		 :start2 (gap-end line) :start1 (- (gap-end line) diff))
	(decf (gap-end line) diff)
	(setf (contents line) new-contents)))
    (loop for cursor in (cursors line)
	  do (when (> (cluffer-buffer:cursor-position cursor) pos)
	       (decf (cluffer-buffer:cursor-position cursor)))))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on ERASE-ITEM.

(defmethod cluffer-buffer:erase-item ((cursor closed-cursor-mixin))
  (open-line (cluffer-buffer:line cursor))
  (cluffer-buffer:erase-item cursor))

(defmethod cluffer-buffer:erase-item ((cursor open-cursor-mixin))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (cluffer-buffer:backward-item cursor)
  (cluffer-buffer:delete-item cursor)
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on FORWARD-ITEM

;;; No need to open the line just because the cursor moves.  
(defmethod cluffer-buffer:forward-item ((cursor closed-cursor-mixin))
  (when (cluffer-buffer:end-of-line-p cursor)
    (error 'cluffer-buffer:end-of-line))
  (incf (cluffer-buffer:cursor-position cursor))
  nil)

(defmethod cluffer-buffer:forward-item ((cursor open-cursor-mixin))
  (when (cluffer-buffer:end-of-line-p cursor)
    (error 'cluffer-buffer:end-of-line))
  (incf (cluffer-buffer:cursor-position cursor))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on BACKWARD-ITEM

;;; No need to open the line just because the cursor moves.  
(defmethod cluffer-buffer:backward-item ((cursor closed-cursor-mixin))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (decf (cluffer-buffer:cursor-position cursor))
  nil)

(defmethod cluffer-buffer:backward-item ((cursor open-cursor-mixin))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (decf (cluffer-buffer:cursor-position cursor))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on BEGINNING-OF-LINE.
;;;
;;; Position the cursor at the beginning of the line.

(defmethod cluffer-buffer:beginning-of-line
    ((cursor cluffer-buffer:detached-cursor))
  (error 'cluffer-buffer:cursor-detached))

(defmethod cluffer-buffer:beginning-of-line
    ((cursor cluffer-buffer:attached-cursor))
  (setf (cluffer-buffer:cursor-position cursor) 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on END-OF-LINE.
;;;
;;; Position the cursor at the end of the line.

(defmethod cluffer-buffer:end-of-line
    ((cursor cluffer-buffer:detached-cursor))
  (error 'cluffer-buffer:cursor-detached))

(defmethod cluffer-buffer:end-of-line
    ((cursor cluffer-buffer:attached-cursor))
  (setf (cluffer-buffer:cursor-position cursor)
	(cluffer-buffer:item-count (cluffer-buffer:line cursor))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on ITEM-BEFORE-CURSOR.

;;; No need to open the line.
(defmethod cluffer-buffer:item-before-cursor
    ((cursor closed-cursor-mixin))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (aref (contents (cluffer-buffer:line cursor))
	(1- (cluffer-buffer:cursor-position cursor))))

(defmethod cluffer-buffer:item-before-cursor
    ((cursor open-left-sticky-cursor))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (let ((pos (1- (cluffer-buffer:cursor-position cursor)))
	(line (cluffer-buffer:line cursor)))
    (aref (contents line)
	  (if (< pos (gap-start line))
	      pos
	      (+ pos (- (gap-end line) (gap-start line)))))))

(defmethod cluffer-buffer:item-before-cursor
    ((cursor open-right-sticky-cursor))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (let ((pos (1- (cluffer-buffer:cursor-position cursor)))
	(line (cluffer-buffer:line cursor)))
    (aref (contents line)
	  (if (< pos (gap-start line))
	      pos
	      (+ pos (- (gap-end line) (gap-start line)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on ITEM-AFTER-CURSOR.

;;; No need to open the line.
(defmethod cluffer-buffer:item-after-cursor
    ((cursor closed-cursor-mixin))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (aref (contents (cluffer-buffer:line cursor))
	(cluffer-buffer:cursor-position cursor)))

(defmethod cluffer-buffer:item-after-cursor
    ((cursor open-left-sticky-cursor))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (let ((pos (cluffer-buffer:cursor-position cursor))
	(line (cluffer-buffer:line cursor)))
    (aref (contents line)
	  (if (< pos (gap-start line))
	      pos
	      (+ pos (- (gap-end line) (gap-start line)))))))

(defmethod cluffer-buffer:item-after-cursor
    ((cursor open-right-sticky-cursor))
  (when (cluffer-buffer:beginning-of-line-p cursor)
    (error 'cluffer-buffer:beginning-of-line))
  (let ((pos (cluffer-buffer:cursor-position cursor))
	(line (cluffer-buffer:line cursor)))
    (aref (contents line)
	  (if (< pos (gap-start line))
	      pos
	      (+ pos (- (gap-end line) (gap-start line)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on LINE-SPLIT-LINE.

(defmethod cluffer-buffer:line-split-line ((cursor closed-cursor-mixin))
  (let* ((pos (cluffer-buffer:cursor-position cursor))
	 (line (cluffer-buffer:line cursor))
	 (contents (contents line))
	 (new-contents (subseq contents pos))
	 (new-line (make-instance 'closed-line
		     :cursors '()
		     :contents new-contents)))
    (setf (contents line)
	  (subseq (contents line) 0 pos))
    (setf (cursors new-line)
	  (loop for cursor in (cursors line)
		when (or (and (typep cursor 'cluffer-buffer:right-sticky-mixin)
			      (>= (cluffer-buffer:cursor-position cursor) pos))
			 (and (typep cursor 'cluffer-buffer:left-sticky-mixin)
			      (> (cluffer-buffer:cursor-position cursor) pos)))
		  collect cursor))
    (loop for cursor in (cursors new-line)
	  do (setf (cluffer-buffer:line cursor) new-line)
	     (decf (cluffer-buffer:cursor-position cursor) pos))
    (setf (cursors line)
	  (set-difference (cursors line) (cursors new-line)))
    new-line))

(defmethod cluffer-buffer:line-split-line ((cursor open-cursor-mixin))
  (close-line (cluffer-buffer:line cursor))
  (cluffer-buffer:line-split-line cursor))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on LINE-JOIN-LINE.

(defmethod cluffer-buffer:line-join-line ((line1 open-line) line2)
  (close-line line1)
  (cluffer-buffer:line-join-line line1 line2))

(defmethod cluffer-buffer:line-join-line (line1 (line2 open-line))
  (close-line line2)
  (cluffer-buffer:line-join-line line1 line2))

(defmethod cluffer-buffer:line-join-line ((line1 closed-line) (line2 closed-line))
  (loop with length = (length (contents line1))
	for cursor in (cursors line2)
	do (setf (cluffer-buffer:line cursor) line1)
	   (incf (cluffer-buffer:cursor-position cursor) length))
  (setf (contents line1)
	(concatenate 'vector (contents line1) (contents line2)))
  nil)

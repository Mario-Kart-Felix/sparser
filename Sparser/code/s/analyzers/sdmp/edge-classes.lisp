;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER COMMON-LISP) -*-
;;; Copyright (c) 2021-2022 David D. McDonald all rights reserved
;;;
;;;      File: "edge-classes"
;;;    Module: analyzers/sdmp/
;;;   Version: January 2022

;; Broken out of word-spotting classes 8/9/21

(in-package :sparser)

;;;---------------------------------------------------
;;; records for instances of edges and chains of them
;;;---------------------------------------------------

(defvar *current-edge-records* (make-hash-table :size 200)
  "Set in store-edge-chain, accessed by get-edge-record. Key is an edge.")

(defvar *current-edge-chains* (make-hash-table :size 200)
  "Set in store-edge-chain, accessed by get-chain. Key is an edge.")

(defun initialize-spotter-edge-records ()
  "These accessor tables are useless once their edges are recycled."
  ;;//// called from clear-spotting-tables
  (clrhash *current-edge-records*)
  (clrhash *current-edge-chains*))

;;--- edge-record

#| Edge records are a A lightweight typed encapsulation of the information
 we retain about an edge for notes or word-spotting. They are created by
 add-edge-to-note-entry and only accessible from the text-strings slot of
 the note-entry they go with.
   Accessors use the stuct's name, e.g. edge-record-chain.
|#
#+ignore ;; supplanted by the defclass that includes information needed for export
(defstruct (edge-record
             (:print-function print-edge-record))
  number ; the edge-position-in-the-resource-array of the edge, see edge#
  string ; its string-for-edge
  chain  ; its edge-chain following up its used-in field
  configuration)

(defclass edge-record ()
  ((number :initarg :number :accessor edge-record-number
           )
   (spotted-string :initform "" :accessor spotted-string
                   )
   (chain :initform nil :accessor edge-record-chain
          )
   (configuration :initform nil :accessor edge-record-configuration
                  )
   ;;--- new slots below. Accessors above match the struct's
   (indexes :initform nil :accessor motif-offsets)
   (top-string :initform "" :accessor top-string)
   (form-labels :initform nil :accessor form-labels))
  (:documentation ""))

(defmethod print-object ((r edge-record) stream)
  (print-unreadable-object (r stream)
    (format stream "~a" (edge-record-number r))))
#+ignore
(defun print-edge-record (obj stream depth)
  (declare (ignore depth))
  (write-string "#<e" stream)
  (format stream "~a" (edge-record-number obj))
  (write-string ">" stream))

(defun add-edge-to-note-entry (edge entry)
  "Called from handle-spotted-word and by maybe-note.
   Wraps the edge in an edge-record and pushs it onto
   the edge-strings slot of the entry."
  (let* ((string (string-for-edge edge))
         (number (edge-position-in-resource-array edge)))
    (unless (find number (text-strings entry) :key #'edge-record-number)
      (let* ((r (make-instance 'edge-record :number number))
             (start (pos-edge-starts-at edge))
             (start-char-index (pos-character-index start))
             (end (pos-edge-ends-at edge))
             (end-char-index (pos-character-index end)))
        (setf (slot-value r 'spotted-string) string)
        (setf (slot-value r 'indexes) (cons start-char-index end-char-index))
        ;; other slots filled when we get the chain
        (push r (text-strings entry))))
    entry))

(defgeneric get-edge-record (edge)
  (:documentation "Retrieve the record for this edge")
  (:method ((number integer))
    (get-edge-record (edge# number)))
  (:method ((e edge))
    (gethash e *current-edge-records*)))

(defgeneric edge-of-edge-record (record)
  (:method ((record edge-record))
    (edge# (edge-record-number record))))


(defgeneric show-edge-records (note-entry &optional stream)
  (:documentation "Shared routine for iterating over edge-records
    and displaying their salient information as a report directed
    to a person")
  (:method ((entry note-entry) &optional stream)
    (unless stream (setq stream *standard-output*))
    (let ((edge-records (text-strings entry)))
      (loop for record in edge-records
         do (report-edge-record record stream)))))

(defun report-edge-record (record &optional (stream *standard-output*))
  "Write out all the salient facts about this edge record with
   and eye toward compactly providing useful information for developing
   context categorizations"
  (let ((edge-number (edge-record-number record))
        (chain (edge-record-chain record))
        (config (edge-record-configuration record)))
    (format stream "~&  e~a~8T~a~
                    ~%~8T~s"
                    edge-number
                    (form-labels chain)
                    (string-for-edge (top-edge chain)))
    (when config
      (format stream "~&~10T:~a" config))))

(defun display-recorded-strings (group &optional (stream *standard-output*))
  "Go through the edge-records on the note-group and print out their strings"
  (when (symbolp group) ; e.g. 'parentheses
    (setq group (get-note-instance group))) ; in current article
  (let ((stream *standard-output*)
        (records (text-strings group)))
    (loop for r in (reverse records) ; sequence order in the article
       as number = (edge-record-number r)
       as string = (spotted-string r) ;; (edge-record-string r)
       do (format stream "~& e~a ~s" number string))))


(defun edge-record-summary (germaine-group-instances)
  "Called by show-abbreviated--motif-edge-contexts to provide
   the statistics on the motific edge records of an article.
   Analogous to show-motif-term-context and show-edge-records
   without theier display component."
  (let ((group-count (length germaine-group-instances))
        records-per-group  records  configurations  uncategorized )
    ;; collect the records
    (loop for group in germaine-group-instances
       as entries = (note-instances group)
       do (loop for note-entry in entries
             as entry-records = (text-strings note-entry)
             do (progn (push (list group entry-records) records-per-group)
                       (setq records (append entry-records records)))))
    ;; determine what categories they have and which ones aren't categorized
    (loop for r in records
       as config = (edge-record-configuration r)
       do (if config
            (push config configurations)
            (push r uncategorized)))
    
    (values (gather-and-count-terms configurations)
            (length records) ; record-count
            (if configurations
              (length configurations) ; categorized-count
              0)
            group-count
            uncategorized))) ; uncategorized-records





;;--- edge-chain

#| The notion of an edge chain was developed for identifying
 and characterizing the location of motif trigger phrased
 found by the word-spotter. They are created as part of the
 after-action method on articles and stored as part of
 the edge-record for the triggering edge.
|#

(defclass edge-chain ()
  ((list :initarg :list :accessor edges
     :documentation "The list of edges as created by upward-used-in-chain")
   (top :initform nil :accessor top-edge
     :documentation "The edge at the high end of the chain")
   (labels :initform nil :accessor form-labels
           :documentation "list of the form labels for the edge"))
  (:documentation
   "Workhorse data structure for identifying position signatures."))

(defmethod print-object ((ec edge-chain) stream)
  (print-unreadable-object (ec stream)
    (let* ((first (first (edges ec)))
           (n1 (edge-position-in-resource-array first))
           (last (top-edge ec))
           (n2 (edge-position-in-resource-array last)))
      (format stream "e~a..e~a " n1 n2))))

(defgeneric get-chain (key)
  (:documentation "retrieve the edge-chain from the current set of
    chains, i.e. those created by apply-context-predicates in the
    after-method for the current article. Use the first edge of the
    chain or that edge's number as the key")
  (:method ((number integer))
    (get-chain (edge# number)))
  (:method ((first-edge edge))
    (gethash first-edge *current-edge-chains*)))

(defgeneric form-chain-and-add-to-record (record)
  (:documentation "Run the used-in operation to get the
    list of edge, then call store-edge-chain. Used in XXX")
  (:method ((record edge-record))
    (let* ((n (edge-record-number record))
           (edge (edge# n))
           (list-of-edges (upward-used-in-chain edge)))
      (store-edge-chain record list-of-edges))))

(defun store-edge-chain (record list-of-edges)
  "Convert the list into an edge-chain and stash it on the
   edge-record. Done in article-level postprocessing by
   apply-context-predicates as part of its setup.
   Also stores the edge-record since the 'find' part of adding an
   edge seems to interfer somehow"
  (let ((ec (make-instance 'edge-chain :list list-of-edges))
        (first-edge (car list-of-edges))
        (top-edge (car (last list-of-edges))))
    ;; index for get-edge-chain
    (setf (gethash first-edge *current-edge-chains*) ec)
   ;; flesh out the fields
    (setf (top-edge ec) top-edge)
    (setf (form-labels ec) (mapcar #'form-cat-name list-of-edges))
    ;; add to the edge record
    (setf (edge-record-chain record) ec)
    ;; stash the record
    (setf (gethash first-edge *current-edge-records*) record)
    ;; Fill the fields in the record that use the chain's information
    (let ((top-string (string-for-edge top-edge)))
      (setf (slot-value record 'top-string) top-string)
      (setf (slot-value record 'form-labels) (form-labels ec)))    
    ec))

(defgeneric display-chain (key &optional stream)
  (:documentation "show all the usual properties of a chain.
    Used to get more detail a particular chain after seeing
    the short version of all the chains in show-edge-records.")
  (:method ((number integer) &optional stream)
    (display-chain (get-chain number)))
  (:method ((ec edge-chain) &optional stream)
    (unless stream (setq stream *standard-output*))
    (let* ((edges (edges ec))
           (edge-numbers (mapcar #'edge-position-in-resource-array edges))
           (categories (mapcar #'edge-cat-name edges)))
      (format stream "~&~a~
                    ~%  edges: ~{e~a  ~}~
                    ~%  form:  ~{~a ~}~
                    ~%  categories:  ~{~a ~}~
                    ~% stree:~%"
              ec edge-numbers (form-labels ec) categories)
      (stree (top-edge ec)) 
      ec)))


;;--- edge walker

(defgeneric upward-used-in-chain (edge)
  (:documentation "Collect the chain of edges walking up
    the 'used-in' field starting at a particular edge.
    Returns all the edges including the last one that wasn't used-in
    anything, ordered from lowest to highest.")
  (:method ((n integer))
    (upward-used-in-chain (edge# n)))
  (:method ((e edge))
    (let ((next e) ; prime pump 
          (chain (list e))
          used-in )
      (loop
         (setq used-in (edge-used-in next))
         (if used-in
           (then (push used-in chain)
                 (setq next used-in))
           (return (nreverse chain)))))))

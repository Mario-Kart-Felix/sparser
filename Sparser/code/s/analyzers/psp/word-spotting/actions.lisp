;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 2021 David D. McDonald  -- all rights reserved
;;;
;;;      File: "actions"
;;;    Module: "analyzers;psp:word-spotting:"
;;;   Version:  August 2021

;; Initiated 5/18/21

(in-package :sparser)

;; (trace-word-spotting)

(defun handle-spotted-word (spotter pos-before pos-after &key edge)
  "Called from spot-word, which supplies the two positions, and from
   spot-polyword which also supplies the edge. We lookup the corresponding
   spot-entry (or create it) and bump up its number. When we have or
   can get an edge we include it in the entry. "
  (declare (special *pnf-has-control*))
  (tr :spotted spotter)
  ;;(push-debug `(,spotter ,pos-before ,pos-after ,edge)) ;(break "handle")

  ;; This part is a straight copy of get-entry-for-notable
  (let* ((name (name spotter))
         (s (sentence))
         (container (contents s))
         (alist (items container))
         (entry (when alist (assoc name alist :test #'eq))))
    (flet ((make-initial-spotter-entry (spotter)
             (let ((entry (find-or-make-spot-entry name)))
               (setf (notable entry) spotter)
               entry)))
      (cond
        ((null alist)
         (setq entry (make-initial-spotter-entry spotter))
         (setf (items container)
               (list (list name entry))))
        ((null entry)
         (setq entry (make-initial-spotter-entry spotter))
         (setf (items container)
               (cons (list name entry) alist)))
        (entry ; we've seen it before
         (when (consp entry) ; e.g. (shamock #<shamrock 2>)
           (setq entry (second entry)))))

      (unless *pnf-has-control*
        ;; If the trigger term is capitalized there wiil be a call
        ;; in examine that's redundant with the one during 
        ;; scan-sentences-and-pws-to-eof -- on the same edge
        (increment-note-entry entry))

      (if edge 
        (massage-spotted-edge edge entry) ; give the right labels
        (setq edge (make-edge-over-motif-word entry pos-before pos-after)))
      (add-edge-to-note-entry edge entry)
      (tr :spotting-edge edge entry)

      entry)))
      




;;--- traces

(defvar *trace-word-spotting* nil)

(defun trace-word-spotting ()
  (setq *trace-word-spotting* t))
(defun untrace-word-spotting ()
  (setq *trace-word-spotting* nil))

(deftrace :spotted (spotter)
  ;; called from handle-spotted-word
  (when *trace-word-spotting*
    (trace-msg "Spotted ~s"
               (pname (note-trigger spotter)))))

(deftrace :spotting-edge (edge entry)
  ;; called from handle-spotted-word
  (when *trace-word-spotting*
    (trace-msg "Adding ~a to ~a" edge entry)))

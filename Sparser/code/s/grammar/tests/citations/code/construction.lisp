;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1993,2013-2015  David D. McDonald  -- all rights reserved
;;;
;;;     File:  "construction"
;;;   Module:  "grammar;tests:citations:code:"
;;;  version:  0.2 October 2015

;; initiated 11/2/93 v2.3
;; 0.1 (12/22) Added appreciation of :multiple-initial edges
;; 0.2 (5/24/13) Adding version that can be run from the listener
;;   (10/26/15) fixed scan-treetops-and-form-citation-exps to
;;     ignore (cut off) the final period.

(in-package :sparser)

;;;----------------------------------
;;; short form for using in listener
;;;----------------------------------

(defun cite (text-string)
  "Parse the text, then write out a citation to the Lisp listener."
  (pp text-string)
  (write-citation-from-last-run))

(defun fcite (text-string)
  "Parse the text, then write out a citation to the designated
   file (see set-citation-file)."
  (pp text-string)
  (take-citation+check+save))


;;;----------------------------------------------------
;;; getting the form created by reading from the chart
;;;----------------------------------------------------

(defun write-citation-from-last-run (&optional
                                     (stream *citation-out-stream*))
  (let ((string (get-last-run-from-buffer))
        (treetop-exps (scan-treetops-and-form-citation-exps)))

    (format stream "~&(define-citation \"~A\"" string)
    (dolist (exp treetop-exps)
      (format stream "~%  (~A " (first exp))
      (write-cite/label-dispatch (second exp) stream)
      (format stream " ~A)" (third exp)))
    (format stream ")~%")))

(defun write-bracket-citation-from-last-run (&optional
                                     (stream *citation-out-stream*))
  (let ((string (get-last-run-from-buffer))
        (bracketing (bracketing-tree)))
    (format stream "~&(define-bracket-citation \"~A\"~%" string)
    (format stream "~s" bracketing)
    (format stream ")~%")))

(defun write-cite/label-dispatch (label stream)
  (etypecase label
    (referential-category
     (write-string (symbol-name (cat-symbol label)) stream))
    (category
     (write-string (symbol-name (cat-symbol label)) stream))
    (polyword
     (format stream "\"~A\"" (pw-pname label)))
    (word
     (format stream "\"~A\"" (word-pname label)))
    (list  ;; i.e. (:multiple-edges l1 l2 ...)
     (write-string "(:multiple-edges" stream)
     (dolist (l (cdr label))
       (write-string " " stream)
       (write-cite/label-dispatch l stream))
     (write-string ")" stream))))



(defun get-last-run-from-buffer ()
  (unless (= 0 *length-accumulated-from-prior-buffers*)
    (error "Can not make a citation out of a run on a string ~
            that is~%more than one buffer long"))
  (subseq *character-buffer-in-use*
          1 *index-of-next-character*))



(defun scan-treetops-and-form-citation-exps ()
  (when *position-array-is-wrapped*
    (error "Can not make a citation out of a run that was ~
            ~%long enough to wrap the chart"))

  (let ((treetops
         (successive-treetops/with-positions
          ;; cut off the final period
          :from (position# 1)
          :to (position# (- *next-array-position-to-fill* 2))))
        exps  left-pos  right-pos  label )

    (dolist (tt treetops)
      (etypecase tt
        (edge
         (setq left-pos (pos-edge-starts-at tt)
               right-pos (pos-edge-ends-at tt))
         (setq label (edge-category tt))
         (push `(,(pos-token-index left-pos)
                 ,label
                 ,(pos-token-index right-pos) )
               exps))
        (list ;; the expression has already been formed
         (push tt exps))))

    (nreverse exps)))



(defun successive-treetops/with-positions
       (&key from   ;; a position -- obligatory
             to     ;; ditto -- ditto
             below) ;; ditto -- optional

  ;; An extension of the version in analyzers;forest:sequence circa 11/93
  ;; that remembers position information when the tt is a word.

  (let (accumulating-tts  lower-first-edge  exp
        (first-edge (right-treetop-at from))
        (went-past-it? nil))

    (when (eq first-edge below)
      (setq lower-first-edge
            (starting-edge-just-under first-edge from)))

    (do* ((edge (or lower-first-edge first-edge)
                (right-treetop-at next-position))
          (last-position from
                         next-position)
          (next-position
           (etypecase edge
             (edge (ev-position (edge-ends-at edge)))
             (word (chart-position-after from))
             (symbol
              (unless (eq edge :multiple-initial-edges)
                (break "Unexpected symbol returned as the next 'edge':~
                        ~%   ~A" edge))
              (chart-position-after last-position)))
           (etypecase edge
             (edge (ev-position (edge-ends-at edge)))
             (word (chart-position-after next-position))
             (symbol
              (unless (eq edge :multiple-initial-edges)
                (break "Unexpected symbol returned as the next 'edge':~
                        ~%   ~A" edge))
              (chart-position-after last-position)))))

         ((or (eq next-position to)
              (if (< (pos-token-index to)  ;;we went past it
                     (pos-token-index next-position))
                (setq went-past-it? t)
                nil))
          (push edge accumulating-tts))

      (setq exp
            (etypecase edge
              (edge edge)
              (word `(,(pos-array-index last-position)
                      ,edge
                      ,(pos-array-index next-position)))
              (symbol  ;; i.e. multiple-initial-edges
               `(,(pos-array-index last-position)
                 (:multiple-edges
                  ,@(mapcar #'(lambda (edge)
                                (edge-category edge))
                            (preterminal-edges
                             (chart-position-before next-position))))
                 ,(pos-array-index next-position)))))

      (push exp accumulating-tts))

    (values (nreverse accumulating-tts)
            went-past-it?)))


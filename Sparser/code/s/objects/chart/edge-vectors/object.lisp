;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1992-1995,2011-2020  David D. McDonald  -- all rights reserved
;;; Copyright (c) 2007 BBNT Solutions LLC. All Rights Reserved
;;; 
;;;     File:  "object"
;;;   Module:  "objects;chart:edge-vectors:"
;;;  Version:  June 2020

;; 2.0 (11/26/92 v2.3) bumped on general principles anticipating changes.
;;     (5/5/93) Added Preterminal-edges
;;     (5/15) added Span-covered-by-one-edge?
;;     (6/2) added Highest-edge
;; 2.1 (1/21/94) elaborated def. of Starting-edge-just-under
;; 2.2 (2/24) fixed a bug in that elaboration
;; 2.3 (3/30) fixed a typo in Index-of-edge-in-vector
;; 2.4 (5/11) added marker and plist fields to the object
;;     (11/23) found missing case in Starting-edge-just-under
;;     (1/30/95) added kcons version for it
;; 2.5 (2/27) changed case of edge index being 1 in Starting-edge-just-under
;;      to fix bug in opening edges via wb/treetops-below-edge
;;     (9/6) added Edge-vector-contains-edge? (2/22/07) added longest-edge-starting-at
;;     (10/18/11) added search-ev-for-edge. (3/28/13) added lowest-edge.
;;     (9/19/13) moved search-ev-for-edge to peek.
;; 2.6 (12/10/14) revised span-covered-by-one-edge? to return an edges
;;     when the span is over multiple-initial-edges. 

(in-package :sparser)


(defstruct (edge-vector
            (:include unit)
            (:conc-name #:ev-)
            (:print-function print-edge-vector-structure))

  edge-vector      ;; a vector of edges
  top-node         ;; an edge or :multiple-initial-edges or nil
  number-of-edges  ;; an integer
  boundary         ;; a phrase boundary
  position         ;; a #<position>
  direction        ;; a keyword, e.g. :|ending at|
  marker           ;; an expansion site for things like font-shift indicators
  )


;;;------------------
;;; access functions
;;;------------------

(defun ev/s (position#)
  (let ((position (position# position#)))
    (pos-starts-here position)))

(defun ev/e (position#)
  (let ((position (position# position#)))
    (pos-ends-here position)))


(defun pos-edge-starts-at (edge)
  (declare (optimize (speed 3)))
  (ev-position (edge-starts-at edge)))

(defun pos-edge-ends-at (edge)
  (declare (optimize (speed 3)))
  (ev-position (edge-ends-at edge)))


(defun edge-start-offset (edge)
  (pos-character-index (pos-edge-starts-at edge)))

(defun edge-end-offset (edge)
  (pos-character-index (pos-edge-ends-at edge)))

(defun edge-character-offsets (edge)
  (values (pos-character-index (pos-edge-starts-at edge))
          (pos-character-index (pos-edge-starts-at edge))))

;;;--------------------------------
;;; searching through edge vectors
;;;--------------------------------

(defun edge-vector-contains-edge? (ev edge)
  (member edge (preterminal-edges (ev-position ev))))


(defun edges-on-ev-above (edge ev)
  "Scan up to the edge, then return a list of the edges above
   that, including the edge, ordered from bottom to top."
  ;; 1st consumer is conjoin-and-rethread-edges
  ;; Only works on vectors because I'm in a hurry and the odds
  ;; are that they're all that will be used for something like this
  (let ((vector (ev-edge-vector ev))
        e  edges-above  accumulate? )
    (dotimes (i (ev-number-of-edges ev))
      (setq e (aref vector i))
      (when (eq e edge)
        (setq accumulate? t))
      (when accumulate?
        (push e edges-above)))
    (nreverse edges-above)))

(defun transpose-edges-up-one (ev edges)
  ;; The last edge should be topmost on the vector
  ;; we start there and move everything up into the
  ;; slot its just-higher edge has been in
  ;; Remember -- vector is zero indexed
  (let ((vector (ev-edge-vector ev))
        (index (1- (ev-number-of-edges ev)))
        (count (length edges)))
    (loop for i downfrom index to (- index count)
       as j = (1+ i)
       as edge = (aref vector i)
       do (setf (aref vector j) edge))
    vector))

(defun insert-edge-into-vector-at (ev edge index)
  "Caller has to warrant that this cell of the edge vector
   can be overridden."
  (let ((vector (ev-edge-vector ev)))
    (setf (aref vector index) edge)
    vector))

(defun swap-edges-in-vector (above below ev)
  "The two edges should be adjacent in the edge array of
 edge-vector 'ev'. Swap their positions so that 'above' now
 has a higher index than 'below'. If above is now the top
 edge update that field."
  (let ((index-for-above (index-of-edge-in-vector below ev))
        (index-for-below (index-of-edge-in-vector above ev)))
    (insert-edge-into-vector-at ev above index-for-above)
    (insert-edge-into-vector-at ev below index-for-below)
    (unless (aref (ev-edge-vector ev) (1+ index-for-above))
      (setf (ev-top-node ev) above))
    ev))



(defun all-edges-on (ev)
  "Returns the edges in order from bottom (shortest)
   to top (longest)."
  (let ((vector (ev-edge-vector ev)))
    (loop for i from 0 upto (1- (ev-number-of-edges ev))
       collect (aref vector i))))


(defgeneric connected-fringe (ev)
  (:documentation "Return a fresh list of the edges on this vector
    ordered from the bottom (shortest) to the top (longest).
    It is similar to all-edge-on except that unlike that function, 
    it guarentees that each edge is 'used-in' the edge above it.
    Designed for the situation where there are multiple preterminal
    edges at the position, only one of which is used in the rest of
    the tree.")
  ;; sort of a combination of all-preterminals-at and edges-all-chain
  (:method ((ev edge-vector))
    (let ((vector (ev-edge-vector ev))
          (index -1)
          (max (ev-number-of-edges ev)))
      ;; 1st identify the preterminals. Only one of them is
      ;; expected to point up into the actual tree.
      (let ((preterminals
             (loop for i from 0 to (1- max)
                as edge = (aref vector i)
                when (one-word-long? edge)
                collect edge)))
        (unless preterminals
          ;; the bottom edge is more than one word long.
          ;; e.g. "...  in vivo [37]" overnight #3
          (setq preterminals `(,(aref vector 0))))
        (let* ((used-preterms
                (loop for edge in preterminals
                   when (edge-used-in edge)
                   collect edge))
               (preterm-to-include
                (if (null (cdr used-preterms))
                  (car used-preterms)
                  ;; Else there must be multiple chains up from
                  ;; this position. For a knowledge-free decision
                  ;; we'd want the longest chain and return that
                  ;; one's preterminal. This flips a coin.
                  (car used-preterms))))
          (if preterm-to-include
            (edges-on-ev-above preterm-to-include ev)
            (cond
              ((null (cdr preterminals)) ;; dec #55
               preterminals)
              (t
               (error "connected-fringe - no used-in preterminals at ~a~
                  ~%in ~s" ev (current-string))))))))))

  


(defun tt-edges-starting-at (start-ev)
  "Special purpose lookup for whack-a-rule.
   Called from adjacent-tt-pairs where we want to include literal rules.
   We include them when we have multiple-initial-edges, otherwise we
   return the top edge."
  (let* ((top-edge (ev-top-node start-ev)))
    (when top-edge ;; nil at the end of sentence in an article
      (if (eq top-edge :multiple-initial-edges)
        (all-edges-on start-ev)
        `(,top-edge)))))

(defgeneric edges-starting-at (position)
  (:documentation "Return all of the edges that start at
   this position. If one of the edges on the vector is larger
   that the others, return just that edge. Also if there is
   a designated top-edge return that edge and ignore the other
   edges below it on the vector.")
  (:method ((n integer))
    (edges-starting-at (position# n)))
  (:method ((p position ))
    (edges-starting-at (pos-starts-here p)))
  (:method ((ev edge-vector))
    (cond
      ((edge-p (ev-top-node ev)) (list (ev-top-node ev)))
      (t (all-edges-on ev)))))

;;//// add the 'longest edges' case
(defgeneric edges-ending-at (position)
  (:documentation "Return all of the edges that end at
   this position. If one of the edges on the vector is larger
   that the others, return just that edge. Also if there is
   a designated top-edge return that edge and ignore the other
   edges below it on the vector.")
  (:method ((n integer))
    (edges-ending-at (position# n)))
  (:method ((p position ))
    (edges-ending-at (pos-ends-here p)))
  (:method ((ev edge-vector))
    (cond
      ((edge-p (ev-top-node ev)) (list (ev-top-node ev)))
      (t (all-edges-on ev)))))


(defun span-covered-by-one-edge? (start end)
  "Return the edge that starts and ends at the indicated positions
  if there is one"
  (let ((start-vector (pos-starts-here start))
        (end-vector (pos-ends-here end)))
    (let ((start-top (ev-top-node start-vector))
          (end-top (ev-top-node end-vector)))
      (when start-top
        (when (eq start-top :multiple-initial-edges)
          (setq start-top (highest-edge start-vector)))
        (when end-top
          (when (eq end-top :multiple-initial-edges)
            (setq end-top (highest-edge end-vector)))
          (if (eq start-top end-top) ;; the easy case
            start-top
            (let ( start-edge end-edge )
              ;; sigh. there must be an easier way
              (dotimes (i (ev-number-of-edges start-vector))
                ;; starts with the earliest node and works up to
                ;; the most recent
                (setq start-edge (aref (ev-edge-vector start-vector) i))
                (dotimes (j (ev-number-of-edges end-vector))
                  (setq end-edge
                        (aref (ev-edge-vector end-vector) j))
                  (when (eq start-edge end-edge)
                    (return-from span-covered-by-one-edge? start-edge))))
              nil )))))))
                              

(defun top-edge-on-ev (ev)
  "If the top-node field holds an edge, return it. Otherwise
   return the final edge in the array."
  (cond
    ((edge-p (ev-top-node ev))
     (ev-top-node ev))
    ((ev-number-of-edges ev) ;; nil over punctuation
     (when (> (ev-number-of-edges ev) 1)
       (elt (ev-edge-vector ev)
            (1- (ev-number-of-edges ev)))))
    (t nil)))

(defun top-edge-at/ending (position)
  ;; returns the top-edge that ends at the position
  ;; or :multiple-initial-edges if that's the case
  (top-edge-on-ev (pos-ends-here position)))

(defun top-edge-at/starting (position)
  ;; returns the top-edge that starts at the position
  ;; or :multiple-initial-edges if that's the case
  (top-edge-on-ev (pos-starts-here position)))



(defun preterminal-edges (position)
  "Return a list of the edges that start at this position and
   span just the one word here."
  ;;/// identical (older?) version of what all-preterminals-at does
  (let ((starting-ev (pos-starts-here position)))
    (if (null (ev-top-node starting-ev))
      nil
      (let ((ending-ev (pos-ends-here (chart-position-after position)))
            (vector (ev-edge-vector starting-ev))
            preterminals )

        (ecase *edge-vector-type*
          (:kcons-list
           (if (eq (edge-ends-at (car vector))
                   ending-ev)
             ;; if the first edge ends at the next position
             ;; then all the rest do
             vector
             (dolist (edge vector)
               (when (eq (edge-ends-at edge)
                         ending-ev)
                 (push edge preterminals)))))
          (:vector
           (let ( edge )
             (dotimes (i (ev-number-of-edges starting-ev))
               (setq edge (aref vector i))
               (when (eq (edge-ends-at edge)
                         ending-ev)
                 (push edge preterminals))))))

        preterminals ))))


(defgeneric edge-spans-position? (edge position)
  (:documentation "Is the position located somewhere between the
    endpoints of the edge (including the endpoints themselves)")
  (:method ((e edge) (p position))
    (position-is-at-or-between p (pos-edge-starts-at e) (pos-edge-ends-at e)))
  (:method ((ev edge-vector) (p position)) nil)
  (:method ((w word) (p position)) nil))


(defun highest-edge (ev)
  ;; returns the edge most recently added to the vector
  (let ((vector (ev-edge-vector ev)))
    (ecase *edge-vector-type*
      (:kcons-list
       (car vector))
      (:vector
       (let ((n (ev-number-of-edges ev)))
	 (if (<= n 0)
	     nil
	     (aref vector (1- n))))))))

(defun lowest-edge (ev)
  (let ((vector (ev-edge-vector ev)))
    (ecase *edge-vector-type*
      (:kcons-list
       (push-debug `(,ev))
       (break "Stub: write lowest-edge for a kcons-list ~
               edge-vector"))
      (:vector
       (aref vector 0)))))


(defun longest-edge-starting-at (position)
  (let* ((ev (pos-starts-here position))
	 (array (ev-edge-vector ev))
	 (count (ev-number-of-edges ev))
	 (index -1)
	 (length 0)
	 edge  )
    (case *edge-vector-type*
      (:vector
       (do ((e (aref array (incf index)) (aref array (incf index))))
	   ((= index count))
	 (when (> (edge-length e) length)
	   (setq edge e)
	   (setq length (edge-length e)))))
      (otherwise
       (break "Stub - write the version for kcons lists")))
    (values edge length)))

(defun starting-edge-just-under (edge position)
  (let* ((ev (pos-starts-here position))
         (count (ev-number-of-edges ev))
         (array (ev-edge-vector ev))
         (top-edge (ev-top-node ev)))
    (ecase *edge-vector-type*
      (:kcons-list
       (let ((length (length array)))
         (cond
          ((= length 1)  ;; no edge underneath
           (pos-terminal position))
          ((= count 0)
           (pos-terminal position))
          (t
           (let ((sublist (member edge (reverse array))))
             (if (cdr sublist) ;; more than just the one edge
               (second sublist)
               (pos-terminal position)))))))
      (:vector
       (cond
        ((eq edge top-edge) ;;most common case
         (if (= count 1)
           (pos-terminal position)
           (aref array (- count 2))))
        ((= count 0)
         (pos-terminal position))
        (t
         (let (( i (index-of-edge-in-vector edge ev)))
           (cond ;((= i 1)
                 ; (pos-terminal position))
                 ((= i 0)
                  (pos-terminal position))
                 (t
                  (aref array (1- i)))))))))))


(defun index-of-edge-in-vector (edge ev)
  (let ((count (ev-number-of-edges ev))
        (vector (ev-edge-vector ev)))
    (loop for i from 0 to count
       when (eq (aref vector i) edge)
       return i
       finally (return nil))))


(defun vector-contains-edge-of-category (vector category)
  ;; called by CA search routines, e.g. for conjunctions
  (let ((number-of-edges (ev-number-of-edges vector))
        (array (ev-edge-vector vector))
        edge )
    (do ((i (1- number-of-edges) (1- i)))
        ((< i 0) nil)
      (setq edge (aref array i))
      (when (eq (edge-category edge)
                category)
        (return edge)))))


;;--- editing the vector

(defun specify-top-edge (edge)
  "This is called from disambiguate-head-of-chunk because the 
   chunker has chosen a specific ending edge for a chunk (with the 
   correct POS), and we want that to be used by any SDM-SPAN-SEGMENT 
  operation. Example: 'is import' gets chunked as a VG, though it is
  syntactically incorrect. Then SDM-SPAN-SEGMENT picks
  the top edge, which is the IMPORT-ENDURANT edge."
  (let* ((start-ev (edge-starts-at edge))
         (end-ev (edge-ends-at edge)))
    (when (not (eq (ev-top-node start-ev) edge))
      (setf (ev-top-node start-ev) edge))
    (when (not (eq (ev-top-node end-ev) edge))
      (setf (ev-top-node end-ev) edge))))


(defun remove-noun-edge (e)
  "When the chunker decides that the noun edge is highly implausible, then remove it from the chart -- e.g. 'these target SMAD2' where the noun reading of target is wrong"
  ;; was   (specify-top-edge (get-verb-edge e))
  (loop for ee in (get-non-verb-edges e)
     do (remove-edge-from-chart ee)))

(defun stipulate-edge-position (start-pos end-pos edge)
  "We're editing the chart, and we want to 'move' an edge
 onto these new start and end positions, with the appropriate
 adjustments to their to make it look like the edge was put
 there by the usual parsing process."
  (let ((start-vector (pos-starts-here start-pos))
        (end-vector (pos-ends-here end-pos)))
    (setf (edge-starts-at edge) start-vector)
    (setf (edge-ends-at edge) end-vector)
    (knit-edge-into-positions edge start-vector end-vector)
    edge))

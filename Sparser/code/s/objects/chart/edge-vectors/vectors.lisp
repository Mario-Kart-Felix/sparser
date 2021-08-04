;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-;;; copyright (c) 1990,1991  Content Technologies Inc.
;;; copyright (c) 1992-1994,2013,2019-2021 David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "vectors"
;;;   Module:  "objects/chart/edge vectors/"
;;;  Version:  August 2021

;; 2.0 (11/26/92 v2.3) bumped on general principles anticipating changes.
;; 2.1 (4/6/93) Put in switch for kcons vs. vector versions
;; 2.2 (4/1/94) added remove-edge-from-chart
;;     (7/30/13) Added a set of function to lift up the fringe of an
;;      established edge, where one of its edges has been composed
;;      (to the right) with another edge, and reknit everything together
;;      properly. 9/19/13 moved the new stuff to objects/chart/edge-vectors/
;;      tuck. 9/23/13 added cleanup-vectors-if-needed

(in-package :sparser)


;;;-------------------------------
;;; adding edges to edge-vectors
;;;-------------------------------

(defun knit-edge-into-positions (edge
                                 starting-vector
                                 ending-vector)

  ;; The edge has been filled out, all we have to do is add it
  ;; to the appropriate edge-vector arrays.  Since this call
  ;; has already differentiated which vectors are involved
  ;; (i.e. which one does it start in, which one end), then
  ;; the same primitive call can be used on each.

  (knit-edge-into-position edge starting-vector)
  (knit-edge-into-position edge ending-vector))



(defun knit-edge-into-position (edge vector)
  (declare (ignore edge vector))
  (error "No value for this switched function.~
          ~%Call Establish-type-of-edge-vector-to-use"))


(defun knit-edge-into-position/vector (edge vector)
  (let ((array (ev-edge-vector vector))
        (count (ev-number-of-edges vector)))
    (declare (special *maximum-number-of-edges-in-an-edge-vector*))
    (when (= 0 count)
      ;; This may be the very first time the edge vector at this point
      ;; in the chart has had edges, have to check and put in an array
      ;; if needed
      (when (null array)
        (setf (ev-edge-vector vector)
              (setq array (make-edge-vector-array)))))

    ;;/// there's something wrong with the format expression in
    ;; this break but I can't see it yet (ddm 7/31/21)
    (when (>= count *maximum-number-of-edges-in-an-edge-vector*)
      (break "Reached the maximum number of edges (~a) allowed on ~
            ~%an edge-vector.~
            ~%    next edge to add: ~A~
            ~%      at edge-vector: ~A"
             *maximum-number-of-edges-in-an-edge-vector*
             edge vector))

    (setf (aref array count) edge)
    (setq count (incf (ev-number-of-edges vector)))
    (setf (ev-top-node vector) edge)
    vector))


(defun knit-edge-into-position/kcons (edge vector)
  (let ((list-so-far (ev-edge-vector vector)))
    (setf (ev-edge-vector vector)
          (kcons edge list-so-far))
    (incf (ev-number-of-edges vector))
    (setf (ev-top-node vector) edge)
    vector))


;;--- delicate editing // consider refactoring

(defun change-edge-end-position (edge new-ev)
  "For chart editing operations only. Reset the
   end position of 'edge' to be 'new-pos' sorting out the
   edge vectors as needed."
  (let ((old-ev (edge-ends-at edge)))
    (setf (edge-ends-at edge) new-ev)
    (remove-edge-from-vector-ev old-ev edge)
    (knit-edge-into-position edge new-ev)
    edge))
   


;;;----------------
;;; removing edges
;;;----------------

(defun remove-and-unhook-edge-from-chart (edge daughters)
  (loop for d in daughters
        do (setf (edge-used-in d) nil))
  (loop for daughter in daughters
        do
          (set-edge-referent daughter (edge-referent daughter) t))
  (remove-edge-from-chart edge))

(defun remove-edge-from-chart (edge)
  ;; Called by form-rule-completion and by
  ;; filter-chunk-compatible-edges-from-ev in the chunker
  (let ((edges (ev-edges (edge-starts-at edge)))
        (starting-vector (edge-starts-at edge))
        (ending-vector (edge-ends-at edge)))
    (remove-edge-from-position starting-vector edge)
    (remove-edge-from-position ending-vector edge)))

(defun remove-edge-from-position (ev edge)
  (ecase *edge-vector-type*
    (:vector (remove-edge-from-vector-ev ev edge))
    (:kcons-list
     (break "Stub: write the routine for removing an edge from an~
             ~%edge-vector based on kcons lists."))))

(defun remove-edge-from-vector-ev (ev edge)
  "Remove 'edge' from the the edge vector 'ev', adjusting
   the other edges in its array and its meta data accordingly."
  (let ((array (ev-edge-vector ev))
        (count (ev-number-of-edges ev))
        (top-node (ev-top-node ev)))
    (cond
     ((eq edge (aref array (1- count))) ;; it is the last one added
      (setf (aref array (decf (ev-number-of-edges ev))) nil)
      (reset-ev-top-node ev))
     (t
      (reset-ev-edges ;; it's in the middle somewhere
       ev (loop for e in (all-edges-on ev)
             unless (eq e edge) collect e))))
    edge ))

(defun reset-ev-top-node (ev)
  "Fixes the top-node field after remove-edge-from-vector-ev has taken away
   the edge it was told to remove. The ev-number-of-edges of the ev
   is already correct, and the edge has been removed from the array."
  (let ((count (ev-number-of-edges ev))
        (edge-list (all-edges-on ev)))
    (cond
      ((= count 1)
       (setf (ev-top-node ev) (car edge-list)))
      ((every #'one-word-long? edge-list)
       (setf (ev-top-node ev) :multiple-initial-edges))
      (t
       (setf (ev-top-node ev) (aref (ev-edge-vector ev) (1- count)))))
    ev))


(defun reset-ev-edges (ev edge-list) ;; moved from psp/chunker.lisp
  "Called from remove-edge-from-vector-ev when the edge to be
   removed is not the last one that was added.
   The edge-list contains all of the edges that should still be on
   the vector after the removal. This code first clears the array
   (sets the cells to nil) and then repopulates it from the
   edge-list."
  (when ev
    #+ignore(if (null (cdr edge-list))
      (setf (ev-top-node ev) (car edge-list))
      (setf (ev-top-node ev) :multiple-initial-edges))
    (loop for i from 0 to (- (length (ev-edge-vector ev)) 1)
       do (setf (aref (ev-edge-vector ev) i)
                nil))
    (loop for i from 0 to (- (length edge-list) 1)
       as e in edge-list
       do (setf (aref (ev-edge-vector ev) i)
                e))
    (setf (ev-number-of-edges ev) (length edge-list))
    (reset-ev-top-node ev)))



(defun reduce-multiple-initial-edges (ev)
  "Some routine has gotten an edge vector where it wanted an edge
   and the reason is :multiple-initial-edges. We go through the
   edges on the vector and return a list of edges that omits
   any that are literals."
  ;; Called by check-out-possible-conjunction and
  ;; look-for-da-patterns though should review what they're
  ;; up to
  (let ((count (ev-number-of-edges ev))
        (vector (ev-edge-vector ev))
        edge  good-edges )
    (ecase *edge-vector-type*
      (:kcons-list (error "Write this routine for kcons list version"))
      (:vector
       (dotimes  (i count)
         (setq edge (aref vector i))
         (unless (edge-for-literal? edge)
           (push edge good-edges)))
       (nreverse good-edges)))))


;;;--------------------------------------
;;; Correcting edge order on the vectors
;;;--------------------------------------

(defun cleanup-vectors-if-needed (top-edge)
  "Called from peek-rightward just afer it has run a rule that
   created a new edge (whose right end happens to be within the
   span of this edge). It can happen, e.g. with the word 'driver',
   that we create another edge as a side effect (in that case
   it's a person given the heuristic about titles in isolation
   being take as roles). When something like that happens, the
   new edge will have started at the same place as the known-to-be-
   top-edge and screw up the ordering on the vector. "
  (flet ((swap-top-edge (ev top-edge)
           (let* ((array (ev-edge-vector ev))
                  (index (index-of-edge-in-vector top-edge ev))
                  (incorrect-top-edge (ev-top-node ev)))
             ;; swapping them ought to suffice
             (setf (aref array index) incorrect-top-edge)
             (setf (aref array (1- (ev-number-of-edges ev)))
                   top-edge)
             (setf (ev-top-node ev) top-edge))))
    (let ((start (edge-starts-at top-edge))
          (end (edge-ends-at top-edge)))
      (unless (eq (ev-top-node start) top-edge)
        (swap-top-edge start top-edge))
      (unless (eq (ev-top-node end) top-edge)
        (swap-top-edge end top-edge)))))


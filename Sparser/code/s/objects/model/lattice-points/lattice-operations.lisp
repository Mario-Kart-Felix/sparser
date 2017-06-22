;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 1992-1994,2014-2015 David D. McDonald  -- all rights reserved
;;;
;;;      File:   "lattice-operations"
;;;    Module:   "analyzers;psp:edges:"
;;;   Version:   May 2016

;; initiated in May 2015
;; Code to place referents in a description lattice to facilitate anaphora and other reasoning
;; 5/30/2015 added a bunch more functionality to description (not-yet-quite-a)lattice
;; 6/20.2015 substantial cleanup for this file -- revised data structures and methods
;; still need to deal with implied superc and subc links

;; First test on compare-to-snapshots d=generated many more elements in the
;;  lattice than I would have expected set *no-description-lattice* to have
;;  this called when parsing

;; 7/7/2015 Maintain the indiv-restrictions field, which contains a list of
;;  all the immediate superior referential categories (1 in most cases, but
;;  can be more than on for a join) and all of the dli-vv’s which have been
;;  produced by the set of bind-variable operations that defined this
;;  individual.
;; Added predicate more-specific? which tests relative position
;;  (subsumption) in the description lattice.
;; 8/12/15 Moved call to use-description-lattice to switches (bio-setting)
;; 12/21/15 Set default value of *description-lattice* to nil to avoid load-
;;  time gratuitous side-effects.


(in-package :sparser)

;;;-----
;;; V+V
;;;-----

;; NOTE -- dl-variable_value are UNIQUELY DEETERMINED by the variable and value
(defstruct (dl-variable+value
            (:include unit)
            (:conc-name #:dlvv-)
            (:print-function print-dl-variable+value-structure))
  variable
  value)

(defparameter *dl-vv-from-variable* (make-hash-table :size 500))

(defun find-or-make-dlvv-ht-from-variable (variable)
  (or (gethash variable *dl-vv-from-variable*)
      (setf (gethash variable *dl-vv-from-variable*) (make-hash-table :size 100 :test #'equal))))

(defun find-or-make-dlvv-from-var-val (variable value)
  (let ((vht (find-or-make-dlvv-ht-from-variable variable)))
    (or (gethash value vht)
        (setf (gethash value vht) 
              (make-dl-variable+value 
               :variable variable 
               :value value)))))

(defun find-or-make-dlvv (binding)
  (find-or-make-dlvv-from-var-val (binding-variable binding) (binding-value binding)))

(defun all-dlvvs ()
  (let
      ((all-dlvvs nil))
    (maphash #'(lambda(k v)
                 (declare (ignore k))
                 (maphash #'(lambda(kk vv)
                              (declare (ignore kk))
                              (push vv all-dlvvs))
                          v))
             *dl-vv-from-variable*)
    all-dlvvs))

(defun print-dl-variable+value-structure (dl-vv stream depth)
  (declare (ignore depth))
  (let ((*print-short* t))
    (format stream "#<dl-vv ~a + ~a>"
            (if (symbolp (dlvv-variable dl-vv))
                (dlvv-variable dl-vv)
                (string-downcase (symbol-name (var-name (dlvv-variable dl-vv)))))
            (dlvv-value dl-vv))))




(defparameter *lattice-ht* (make-hash-table :size 30000 :test #'eq)
  "This is the initial way that edge-referent's are linked to the structures that are in the lattice.
   A bit slower than putting a field in the referent, but applicable to all referents, and does not change their structure.")

(defparameter *lattice-ht-for-collections* (make-hash-table :size 3000 :test #'equal))
(defparameter *source-ht* (make-hash-table :size 30000 :test #'eq)
  "Inverse link to *lattice-ht*")

(defun get-dli (ref)
  (or (gethash ref *lattice-ht*)
      ;; make get-dli idempotent
      (if (gethash ref *source-ht*)
          ref)))

(defun set-dli (ref dli)
  (push ref (gethash dli *source-ht*))
  (setf (gethash ref *lattice-ht*) dli))

(defparameter *dl-lattice-index* 0)
(defparameter *dl-lattice-top* nil)


(defun place-referent-in-lattice (referent edge) ;; THIS IS NOW A NO-OP IN THE DESCRIPTION LATTICE CASE
  (declare (special *prep-forms* referent edge))
  ;; N.b. if anyone revives this. Appreciate that some referents are words
  referent
  )

(defun fom-lattice-description (base)
  ;; Called with the category of the to-be-make individual
  ;; from make-simple-individual and from make-individual-for-dm&p
  (cond ((null base))
        ((get-dli base))
        ((referential-category-p base)
         (find-or-make-lattice-description-for-ref-category base))
        ((individual-p base)
         (if (indiv-binds base)
           (find-or-make-lattice-description-for-individual base)
           (find-or-make-lattice-description-for-cat-list (indiv-type base))))
        ((consp base) ;; a join of categories
         (find-or-make-lattice-description-for-cat-list base))))

(defun dli-ref-cat (c)
  (cond ((null c))
        ((individual-p c)
         (find-or-make-lattice-description-for-cat-list (indiv-type c)))
        ((category-p c)
         (fom-lattice-description c))
        ((symbolp c)
         (fom-lattice-description (category-named c)))))

(defun find-or-make-lattice-description-for-individual (base)
  (declare (special category::collection))
  (or (get-dli base)
      (if (memq category::collection (indiv-type base)) ;; likely a conjunction
          (find-or-make-lattice-description-for-collection base) ;; not quite right -- ehat to do here?
    (let* ((lattice-cat-entry (dli-ref-cat base))
           (current-dli lattice-cat-entry)
           ) ;;(dl-vvs nil))
      (declare (special lattice-cat-entry current-dll #|dll-vvs|#))
      ;; bindings = NIL can happen for VGs -- possibly because of the
      ;; creation of an individual for the referent-category in the
      ;; interpretation process
      (loop for b in (filter-bindings (indiv-binds base)) 
        do
        (setq current-dli 
              (find-or-make-lattice-subordinate current-dli (binding-variable b) (binding-value b))))
      (set-dli base current-dli)))))



(defun make-dli-for-ref-category (category)
  (let ((*index-under-permanent-instances* t))
    (declare (special *index-under-permanent-instances*))
    (make-category-indexed-individual category)))

(defun make-dli-for-join (category-list)
  (let ((*index-under-permanent-instances* t))
    (declare (special *index-under-permanent-instances*))
    (let ((new-dli (make-category-indexed-individual (car category-list))))
      (setf (indiv-restrictions new-dli) (append category-list nil))
      ;; copy the list in case it is in use elsewhere
      (loop for c in (cdr category-list)
         do (pushnew c (indiv-type new-dli) ))
      new-dli)))

(defun find-or-make-lattice-description-for-ref-category (base)
  (or (get-dli base)
      (let ((new-dli (make-dli-for-ref-category base)))
        (loop for c in (immediate-supers base)
          do 
          (let ((ip (find-or-make-lattice-description-for-ref-category c))
                (supers (indiv-all-supers new-dli)))
            (add-downlink ip new-dli)
            (setf (gethash ip supers) t)
            (maphash #'(lambda (k h)
                         (declare (ignore h))
                         (setf (gethash k supers) t))
		     (indiv-all-supers ip))))
            
        (setf (indiv-restrictions new-dli) (list base))
	(set-dli base new-dli))))

(defparameter *non-phrasal-classes* nil)
(defparameter *non-phrasal-class-names*
  '(NAME DETERMINER PRONOUN TIME KINASE SMALL-MOLECULE PROTEIN-METHOD AMOUNT
	BIB-REFERENCE MOLECULE-STATE CATALYSIS BIOCHEMICAL-REACTION MODAL
	MUTATION NAMED-BIO-PROCESS BIO-WHETHERCOMP BIO-IFCOMP DISEASE
	BIO-OBSERVATION BIO-REAGENT BIO-PREPARATION TYPE-MARKER BIO-AGGREGATE
	AGGREGATE TAKES-NEG RECEPTOR BIO-ABSTRACT PHOSPHORYLATION-MODIFICATION
	MECHANISM QUANTIFIER PHOSPHOLIPID LIPID OLIGOMERIZE BIO-SCALAR
	SCALAR-QUALITY QUALITY BIO-QUALITY BIO-THATCOMP BIO-COMPLEMENT
	CELLULAR-LOCATION MOLECULAR-FUNCTION BIO-SELF-MOVEMENT BIO-MOVEMENT
	PREPOSITIONAL-OPERATOR FRACTIONAL-TERM TENSE/ASPECT
	POST-TRANSLATIONAL-ENZYME ADJECTIVE-ADVERB TUMOR ADVERBIAL
	POSITIVE-BIO-CONTROL NUCLEOTIDE-EXCHANGE-FACTOR REACTOME-CATEGORY
	IN-RAS2-MODEL NON-CELLULAR-LOCATION BIO-LOCATION NEGATIVE-BIO-CONTROL
	CAUSED-BIO-PROCESS BIO-RELATION BIO-PREDICATION STATE BIO-CHEMICAL-ENTITY
	PHYSICAL-OBJECT MODIFIER OPERATOR BIO-METHOD KIND PHYSICAL ENDURANT
	HAS-UID RELATION ABSTRACT HAS-NAME BIOLOGICAL WITH-QUANTIFIER
    BIO-RHETORICAL PERDURANT TOP))

(defparameter *npc-complete* nil)

(defun non-phrasal-classes ()
  (when (null *non-phrasal-classes*)
    (setq *non-phrasal-classes*
	  (make-hash-table :test #'eq)))
  (unless
      (or *npc-complete*
	  (setq *npc-complete*
		(loop for c in *non-phrasal-class-names* always
		     (let ((cat (category-named c)))
		       (and cat
			    (gethash  (find-or-make-lattice-description-for-ref-category cat) *non-phrasal-classes*))))))
    (loop  for c in *non-phrasal-class-names*
       when (category-named c)
       do (setf (gethash (find-or-make-lattice-description-for-ref-category (category-named c)) *non-phrasal-classes*) t)))
  *non-phrasal-classes*)

(defparameter *sub-vv* (find-or-make-dlvv-from-var-val :subc nil))
(defparameter *super-vv* (find-or-make-dlvv-from-var-val :superc nil))

(defun add-downlink (dli down)
  (pushnew down (gethash *sub-vv* (indiv-downlinks dli)))
  (push  (cons *super-vv* dli) (indiv-uplinks down)))

(defun add-uplink (dli up)
  (push (cons up *super-vv*) (indiv-uplinks dli))
  (setf (gethash up (indiv-all-supers dli)) t)
  (push dli (gethash *super-vv* (indiv-downlinks up))))
                 
(defun find-or-make-lattice-description-for-cat-list (cat-list)
  (if (null (cdr cat-list))
   (find-or-make-lattice-description-for-ref-category (car cat-list))
   (or (get-dli cat-list)
       (set-dli cat-list (make-dli-for-join cat-list)))))

(defun shared-supercs (c1 c2)
  (if (consp c2)
    (intersection (immediate-supers c1) 
                  (shared-supercs (car c2) (cdr c2)))
    (immediate-supers c1)))

(defun find-or-make-lattice-description-for-collection (indiv-collection)
  (declare (special category::collection))
  (let ((members (value-of 'items indiv-collection)))
    (or
     (get-dli indiv-collection)
     (gethash members *lattice-ht-for-collections*)
     (let ((new-dli (deep-copy-individual indiv-collection)))
       (add-uplink new-dli (dli-ref-cat indiv-collection))
       (loop for member in members
          do
            (add-downlink new-dli (fom-lattice-description member)))
       (setf (gethash members *lattice-ht-for-collections*) new-dli)
       (set-dli indiv-collection new-dli)))))

(defun make-lattice-description-from-collection-members (members)
  (find-or-make-lattice-description-for-collection
   (define-or-find-individual 'collection
       :items members
       :number (length members)
       :type (itype-of (car members)))))
  

(defun filter-bindings (bindings)
  (declare (special bindings))
  #+ignore
  (loop for b in bindings
    unless (memq (var-name (binding-variable b)) '(has-determiner value)) ;; value is bound in items of type number
    collect b)
  bindings)


(defun find-lattice-subordinate (oparent var/name value)
  ;; called from find-by-apply-bindings
  (declare (special oparent var/name binding))
  (let* ((parent (if (referential-category-p oparent)
		   (find-or-make-lattice-description-for-ref-category oparent)
		   oparent))
         (var (find-var-from-var/name var/name parent))
         (dl-vv (when var (find-or-make-dlvv-from-var-val var value)))
         (downlinks (indiv-downlinks parent)))
    (declare (special parent var dl-vv downlinks))
    (when dl-vv
      (gethash dl-vv downlinks))))

(defun find-or-make-lattice-subordinate (oparent var/name value &optional category)
  ;; Called from bind-dli-variable and returns the new individual and 
  ;; the new binding
  (declare (special oparent var/name binding))
  (let* ((parent (if (referential-category-p oparent)
		     (find-or-make-lattice-description-for-ref-category oparent)
		     oparent))
         (lattice-cat-parent (dli-ref-cat oparent))
         (parent-restrictions (indiv-restrictions parent))
         (var (find-var-from-var/name var/name (or category parent)))
         (dl-vv (when var (find-or-make-dlvv-from-var-val var value)))
         (downlinks (indiv-downlinks parent))
         ;; need to make sure copy-individual makes permanent ones
         (*index-under-permanent-instances* t))

    (declare (special *index-under-permanent-instances*
                      parent var dl-vv downlinks))
    (if (null var)
        (then (break "find-or-make-lattice-subordinate fails to find var ~s in ~s~%"
                    var/name (or category parent))
              (return-from find-or-make-lattice-subordinate (values parent nil)))
        (let* ((result
		(or (gethash dl-vv downlinks) ;; already there in the hierarchy
		    (let ((new-child (deep-copy-individual parent)))
		      (setq new-child (old-bind-variable var value new-child))
		      (setf (gethash dl-vv downlinks) new-child)
		      (push (cons dl-vv parent) (indiv-uplinks new-child))
		      (setf (gethash parent (indiv-all-supers new-child)) t)
		      (link-to-other-parents new-child parent dl-vv)
		      (link-to-existing-children new-child parent dl-vv)
		      (setf (indiv-restrictions new-child) (cons dl-vv parent-restrictions))
		      (set-dli new-child new-child)
		      new-child)))
	       (res-supers (indiv-all-supers result)))
         
	  (setf (gethash parent res-supers) t)
	  (loop for key being each hash-key of (indiv-all-supers parent)
	       do (setf (gethash key res-supers) t))
	  
	  (values
	   result
	   (get-binding-of var result value))))))

(defun link-sub-super (sub super)
  (let ((supers (indiv-all-supers sub)))
    (setf (gethash super supers) t)))


(defun interesting-super? (c)
  (not (gethash c (non-phrasal-classes))))

(defparameter *not-as-specific* (make-hash-table :size 20000))

(defun as-specific? (sub-dli super-dli) ;; super-dli lies above sub-dli in the description lattice
  (when sub-dli
    (or
     (eq sub-dli super-dli)
     (and (referential-category-p super-dli) ;; happens in calls from check-consistent-mention
	  (itypep sub-dli super-dli))
     (cond
       ((referential-category-p sub-dli)
	(and (referential-category-p super-dli)
	     (itypep sub-dli super-dli)))
       ((gethash super-dli (indiv-not-super sub-dli))
	nil)
       ((gethash super-dli (indiv-all-supers sub-dli)))
       ((itypep sub-dli (itype-of super-dli))
	(cond ((loop for r in (and (individual-p super-dli)
				   (indiv-restrictions super-dli))
		  as rval = (and (not (category-p r))(dlvv-value r))
		  always
		    (or (null rval)
			(let* ((sub-r
				(find-if #'(lambda (dlvv)
					     (when
						 (not (category-p dlvv))
					       (eq (dlvv-variable dlvv) (dlvv-variable r))))
					 (indiv-restrictions sub-dli)))
			       (srval (and sub-r (dlvv-value sub-r))))
			  (if (or (category-p rval)(individual-p rval))
			      (and (or (category-p srval)(individual-p srval))
				   (as-specific? srval rval))
			      (equal rval srval)))))
	       (setf (gethash super-dli (indiv-all-supers sub-dli)) t))
	      (t (setf (gethash super-dli (indiv-not-super sub-dli)) t)
		 nil)))))))
;; was -- incorrectly -- (subsetp  (indiv-restrictions super-dli) (indiv-restrictions sub-dli)))

(defun find-var-from-var/name (var/name parent)
  (cond
    ((typep var/name 'lambda-variable) var/name)
    ((typep var/name 'anonymous-variable) 
     (cond
       ((null (find-variable-for-category 
	       (avar-name var/name)
	       (if (individual-p parent)
		   (itype-of parent)
		   parent)))
	#+ignore(format t "~&~&!! Can't dereference anonymous variable ~a against category ~a.~
         ~%Can't do binding. Leaving object unchanged.~%" var/name parent)
	nil)
       (t
	(dereference-variable var/name parent))))
    ((symbolp var/name)
     (or
      (cond
	((individual-p parent)
	 (find-variable-from-individual Var/name parent))
	((category-p parent)
	 (find-variable-for-category var/name parent)))
      (lambda-variable-named var/name)))
    (t (break "var/name ~s can't be mapped to a variable in ~s"
	      var/name parent))))

(defun get-binding-of (var i value)
  "Get binding in i that binds var to value"
  (loop for b in (indiv-binds i)
     when (and (eq (binding-variable b) var)
	       (equal (binding-value b) value))
     do (return b)))


;;;;; KEY METHODS TO BE WRITTEN ;;;;;;;
(defun link-to-other-parents (new-child parent binding) ;; to be written
  (declare (ignore new-child parent binding))
  nil)

(defun link-to-existing-children (new-child parent binding) ;; to be written
  (declare (ignore new-child parent binding))
  nil)

(defun same-category? (daughter-ref ref)
  (or (and (category-p daughter-ref)
           (itypep ref daughter-ref)))
  (or (and (individual-p daughter-ref)
           (equal (indiv-type daughter-ref)
                  (indiv-type ref)))))

(defparameter *dlis* nil)
(defparameter *bmax* 0)
(defparameter *maxb* nil)
(defparameter *ref-counts* (make-hash-table))

(defun survey-bindings ()
  (setq *dlis* (all-dlis))
  (format t "There are ~S dlis" (length *dlis*))
  (setq *bmax* 0)
  (setq *maxb* nil)
  (loop for d in *dlis*
    do
    (when (> (length (indiv-binds d)) *bmax*) 
      (setq *bmax* (length (indiv-binds d)))
      (setq *maxb* d))
       (push d (gethash (length (gethash d *source-ht*)) *ref-counts*))))

(defun all-dlis ()
  (setq *dlis* nil)
  (maphash #'(lambda(e dli)(declare (ignore e))(push dli *dlis*)) *lattice-ht*)
  *dlis*)

(defun all-phrasal-dlis ()
  (all-dlis)
  (loop for i in *dlis* when (retrieve-surface-string i) collect i))

(defun phrasal-dli-cat-refs ()
  (remove-duplicates
   (loop for i in (all-phrasal-dlis) collect (dli-ref-cat i))))

(defun all-mentioned-specializations (c c-mention containing-mentions)
  (declare (special *maximal-lattice-mentions-in-paragraph* c c-mention containing-mentions))
  (let* ((am-specs
	  (remove-duplicates
	   (loop for m in (gethash (itype-of c) *maximal-lattice-mentions-in-paragraph*)
	      as ps = (base-description m)
	      when
		(and  (not (eq ps c))
		      (as-specific? ps c)
		      (mention-history ps)
		      (loop for cm in containing-mentions
			 never (eq ps (base-description cm)))
		      (loop for ps-mention in (mention-history ps)
			 thereis (earlier? ps-mention c-mention)))
	      collect ps))))
    (declare (special am-specs))
    am-specs))

(defun earlier? (poss-mention source-mention)
  (cond
    ((mention-source source-mention) ;; source-mention still has an edge
     (or
      (not (mention-source poss-mention))
      (edge-precedes (mention-source poss-mention)
		     (mention-source source-mention))))
    (t nil)))
    

(defun hal (ht) (hashtable-to-alist ht))
(defun sur-string (i)(retrieve-surface-string i))
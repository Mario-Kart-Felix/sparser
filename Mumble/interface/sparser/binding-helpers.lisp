;;; -*- Mode: LISP; Syntax: Common-Lisp; Package: MUMBLE -*-
;;; copyright (c) 2017 David D. McDonald  -- all rights reserved

(in-package :mumble)

;;;-----------------------------------------------------------
;;; interface into Mumble's state at the time we make the dtn
;;;-----------------------------------------------------------

(defun current-position ()
  "Wraps the generation state variable *current-position*, which only
   has a value when Mumble has started instantiating and executing phrases.
   Returns nil if the variable does not have a meaningful value."
  (when (boundp '*current-position*)
    (when *current-position* ;; nil check
      *current-position*)))

(defun current-position-p (&rest labels)
  "Return true if the slot being generated has one of the given labels."
  (let ((slot (current-position)))
    (when slot
      (memq (name slot) labels))))

(defun current-position-is-top-level? ()
  "Is the current position something like turn or a similar
   main-clause holding slot like sentence, question, or s.
   If the current position isn't bound yet then we're in 
   declared to be at top level. 
      Controls application of command in the tense fn."
  (let* ((slot (current-position))
         (name (name slot)))
    (cond
      ((null slot) t)
      ((memq name '(turn sentence question s paragraph)) t)
      ((eq name 'item)
       ;; This is from a conjunction phrase. Toplevel if not below a clause.
       (null (dominating-clause)))
      (t nil))))

(defun display-current-position (&optional (stream *standard-output*))
  (let* ((slot (current-position))
         (toplevel? (when slot (current-position-is-top-level?))))
    (format stream "~&Current position: ")
    (cond
      (slot (format stream "[~a]" (name slot)))
      (toplevel? (format stream "toplevel"))
      (t (format stream "unknown")))))


;;;------------------------------------
;;; grammatical constraint information
;;;------------------------------------

(defparameter *slot-name-part-of-speech-table*
  '((turn (verb noun adjective adverb))
    ;; grammatical-constraints (clause np vp pp adjp advp)
    (subject (noun)) ;; (np vp)
    (direct-object (noun)) ;; (np)
    (prep-obj (noun)) ;; (np)
    (complement-of-be (adjective adverb verb noun))
    (relative-clause (verb))
    (adjp-head (adjective))
    (advp (adverb))
    )
  "Has the information we could otherwise glean (and abstract to
   the needed level) from the grammatical constraints on slot labels")

(defun current-position-compatible-with-pos (pos-label)
  "Is the current syntactic position compatible with
   realizations of this particular part-of-speech?"
  (let ((slot (current-position)))
    (when slot
      (grammatically-compatible? slot pos-label))))

(defgeneric grammatically-compatible? (position pos)
  (:documentation "Are the grammatical constraints on this position
    compatible with realizations of this part of speech")
  (:method ((slot slot) (pos symbol))
    (let* ((table *slot-name-part-of-speech-table*)
           (labels-on-slot (labels slot))
           (label-names (loop for l in labels-on-slot
                           collect (name l))))
      (let ((entries (loop for name in label-names
                        when (assoc name table)
                        collect (cadr (assoc name table)))))
        (unless entries (warn "no slot-pos entry for ~a" label-names))
        (loop for entry in entries
           when (memq pos entry)
           do (return-from grammatically-compatible? t))
        nil))))


;;;----------------------
;;; poor man's def-trace
;;;----------------------

(defparameter *trace-archie* nil)

(defun sp::trace-archie () (setq *trace-archie* t))
(defun sp::untrace-archie () (setq *trace-archie* nil))

(defun tr (string &rest args)
  (when *trace-archie*
    (let ((doctored-string (string-append "~&" string "~%")))
      (apply #'format t doctored-string args))))

;;;-----------------------------------------
;;; special cases for realizing individuals
;;;-----------------------------------------

(sp::def-k-method realize-individual ((i category::collection) &key)
  (tr "Realizing collection ~a" i)
  (let ((items (sp::value-of 'sp::items i))
        (type (sp::value-of 'sp::type i)))
    (if (null items)
      (plural (realize-via-category i type))
      (cl:labels ((conjoin (one &optional two &rest more)
                    (let ((conjunction
                           (make-dtn :referent `(and ,one ,two)
                                     :resource (phrase-named 'two-item-conjunction))))
                      (make-complement-node 'one one conjunction)
                      (make-complement-node 'two two conjunction)
                      (if more
                        (apply #'conjoin conjunction more)
                        conjunction))))
        (apply #'conjoin items)))))

(sp::def-k-method realize-individual ((i integer) &key ordinal)
  ;; (format nil "~r" 1325) => "one thousand three hundred twenty-five"
  ;; (format nil "~:r" 1325) => "one thousand three hundred twenty-fifth"
  (format nil (if ordinal "~:r" "~r") i))

(sp::def-k-method realize-individual ((i category::number) &key
                                      (ordinal (sp::itypep i 'sp::ordinal)))
  "Make a dtn for simple number words. For long, multi-word numbers recover
   the algorithm from grammar/numbers.lisp"
  (tr "Realizing number ~a" i)
  (cond ((sp::value-of 'sp::number i) ; e.g., a multiplier like "10-fold"
         (let* ((number (realize-individual (sp::value-of 'sp::number i)
                                            :ordinal ordinal))
                (noun (sp::rdata-head-word i :common-noun))
                (np (make-dtn :referent i
                              :resource (phrase-named 'number-np))))
           (make-complement-node 'number number np)
           (when noun (make-complement-node 'n noun np))
           np))
        ((sp::value-of 'sp::value i) ; e.g., an ordinal or cardinal number
         (let* ((number (realize-individual (sp::value-of 'sp::value i)
                                            :ordinal ordinal))
                (word (word-for-string number 'number))
                (np (make-dtn :referent i
                              :resource (phrase-named 'bare-np-head))))
           (make-complement-node 'n word np)
           np))
        ((sp::value-of 'sp::quantifier i) ; e.g., "many orders of magnitude"
         (let* ((quantifier (sp::value-of 'sp::quantifier i))
                (noun (sp::rdata-head-word i :common-noun))
                (np (make-dtn :referent noun
                              :resource (phrase-named 'bare-np-head)))
                (qp (make-dtn :referent i
                              :resource (phrase-named 'QpNpcomp))))
           (make-complement-node 'n noun np)
           (make-complement-node 'q quantifier qp)
           (make-complement-node 'np np qp)
           qp))
        ((sp::value-of 'sp::has-determiner i) ; e.g., "an order of magnitude"
         (sp::bind-variable 'sp::number 1 i))
        (t (error "Don't know how to realize number ~a" i))))


(sp::def-k-method realize-individual ((i category::polar-question) &key)
  (tr "Realizing polar-question ~a" i)
  (discourse-unit (question (realize (sp::value-of 'sp::statement i)))))

(sp::def-k-method realize-individual ((i category::wh-question) &key)
  (tr "Realizing wh question ~a" i)
  (let* ((wh-category (sp::value-of 'sp::wh i))
         (statement (sp::value-of 'sp::statement i))
         (top-dtn (realize statement))
         (wh-dtn (make-dtn :resource (phrase-named 'wh))))
    (make-complement-node 'wh wh-category wh-dtn)
    (add-feature top-dtn :wh wh-dtn)
    (discourse-unit (question top-dtn))))

(sp::def-k-method realize-individual ((i category::wh-question/attribute) &key)
  (tr "Realizing wh/attribute question ~a" i)
  (let* ((wh-category (sp::value-of 'sp::wh i))
         (attribute (sp::value-of 'sp::attribute i))
         (other (sp::value-of 'sp::other i))
         (statement (sp::value-of 'sp::statement i))
         (top-dtn (realize statement))
         (wh-dtn (make-dtn :resource (phrase-named 'wh-term))))
    (make-complement-node 'wh wh-category wh-dtn)
    (make-complement-node 'q (or attribute other) wh-dtn)
    (add-feature top-dtn :wh wh-dtn)
    (discourse-unit ;; supply the "?" as well as capitalizing
     (question ;; invert the aux
      top-dtn))))



(sp::def-k-method realize-individual ((i category::copular-predication) &key)
  (tr "Realizing copular-predication ~a" i)
  ;;(sp::with-bindings ((:sparser) item value prep predicate) i <= getting nil's
    ;;/// The predicate variable holds the tense, e.g.
  ;; (predicate (#<be 84923> (present #<ref-category PRESENT>)))
  (let ((item (sp::value-of 'sp::item i))
        (value (sp::value-of 'sp::value i))
        (prep (sp::value-of 'sp::prep i))
        (predicate (sp::value-of 'sp::predicate i)))
    (let* ((of-pp? (sp::itypep i 'sp::copular-predication-of-pp))
           (phrase (if of-pp?
                     (phrase-named 'SVPrepO)
                     (phrase-named 's-be-comp)))
           (dtn (make-dtn :referent i :resource phrase)))
      (when item (attach-subject item dtn))
      (when value
        (if of-pp?
          (attach-object value dtn)
          (attach-complement value dtn)))
      (when prep (attach-preposition prep dtn))
      (when predicate
        (attach-verb predicate dtn))
      (verb-aux-handler dtn i)
      dtn)))

(sp::def-k-method realize-individual ((i category::explicit-suggestion) &key)
  (tr "Realizing explicit-suggestion ~a" i)
  (let ((dtn (realize-via-bindings (sp::value-of 'sp::suggestion i)))
        (m (sp::value-of 'sp::marker i))
        (ap 'initial-adverbial))
    (make-adjunction-node (make-lexicalized-attachment ap m) dtn)
    dtn))

(sp::def-k-method realize-individual ((i category::there-exists) &key)
  (tr "Realizing there-exists ~a" i)
  (let ((be (realize-via-bindings (sp::value-of 'sp::predicate i)
                                  :pos 'verb
                                  :resource (phrase-named 's-be-comp))))
    (attach-subject (find-word "there" 'pronoun) be)
    (attach-complement (sp::value-of 'sp::value i) be)
    be))

;;;-------------------------------------------------------------
;;; additional handling to sort out potential issues in clauses
;;;-------------------------------------------------------------

(defgeneric verb-aux-handler (dtn i)
  (:documentation "Called from realize-bindings-via-common-path 
    and simpler clause-creating routines. Handle things that are
    common to any verb-centric realization.")
  (:method ((dtn derivation-tree-node) (i sp::individual))
    (when (verb-based-realization dtn)
      ;; Look for a specified tense
      (cond ((sp::value-of 'sp::past i)
             (past-tense dtn))
            ((sp::value-of 'sp::progressive i)
             (progressive dtn))
            ((sp::value-of 'sp::perfect i)
             (had dtn))
            ;; ((current-position-p 'adjective 'complement-of-be 'relative-clause)
            ;;  (past-tense dtn)) -- moved just below
            (t (unless (get-accessory-value :tense-modal dtn) ;; e.g. a modal
                 (present-tense dtn))))
      ;; Look at the status of its variables.
      ;; If some/all are abstract/missing then depending on the context
      ;; we need to make various adjustments
      (let ((parameters (get-parameters dtn)) ;; parameter objects
            (slot (current-position))
            (object (get-object i)) ;; value of object var
            (subject (get-subject i)))
        (cond
          ((current-position-is-top-level?)
           ;; ??? why did we check for a concrete object?
           (when (sp::missing-subject-vars i)
             (command dtn)))
          ((current-position-p 'relative-clause)
           (let ((head (head-of-relative-clause slot)))
             (declare (ignore head)) ;; need more info in predication
             (when (and object
                        (sp::is-lambda-var object)) ;; =? the head
               (passive dtn)
               (when (and subject
                          (explicit-subject dtn))
                 ;; That subject will be clipped by the relative-clause
                 ;; transformation. As good a reason as any for a by-phrase
                 ;; since we're alrady passivized this clause.
                 (attach-pp "by" subject dtn 'verb)))))
          ;; complement-of-be -- leads to by-phrase w/in complement-of-be
          ;; adjective
          ))
      dtn)))


(defgeneric includes-tense? (idividual)
  (:documentation "Do the bindings on the individual 
    include any of the tense carriers?")
  (:method ((i sp::individual))
    (let* ((bindings (sp::indiv-binds i))
           (variables (loop for b in bindings collect (sp::binding-variable b)))
           (names (loop for v in variables collect (sp::var-name v))))
      (or (memq 'sp::past names) ;;/// stage in syntax/tense.lisp
          (memq 'sp::progressive names)
          (memq 'sp::perfect names)
          (memq 'sp::present names)))))



;;;------------------------------------------
;;; Subroutines for attaching various things
;;;------------------------------------------

(defun attach-adjective (adjective dtn pos)
  (let ((adjp (make-dtn :referent adjective
                        :resource (phrase-named 'adjp)))
        (ap (ecase pos
              ((adjective noun) 'adjective)
              ((adverb verb)
               (if (sp::itypep adjective 'sp::intensifier)
                 'adverbial-preceding
                 (multiple-value-bind (head rpos)
                     (sp::rdata-head-word adjective t)
                   (declare (ignore head))
                   (case rpos
                     (:interjection 'adverbial-preceding)
                     (otherwise 'vp-final-adjunct))))))))
    (tr "Attaching adjective: ~a" adjective)
    (make-complement-node 'a adjective adjp)
    (make-adjunction-node (make-lexicalized-attachment ap adjp) dtn)))


(defun attach-adverb (i dtn pos)
  "Add an adverb (i) as an adjunct to the dtn. The choice of AP 
   depends XX"
  (flet ((retrieve-m-adverb (i)
           (let ((lp (find-lexicalized-phrase i)))
             (when lp
               (extract-lexicalized-word lp 'adv)))))
    (let ((ap (ecase pos ;; of the dtn we're adding to
                (adjective ;; i.e. an adjp-head slot
                 'adverbial-preceding)
                (verb 'adverbial-following)))
          (adverb (retrieve-m-adverb i)))
      (if (or (sp::indiv-binds i)
              (null adverb))
        ;; It's got properties we'll probably express, so stash
        ;; the Krisp into a phrase. Also applies if we need to
        ;; kick the can down the road on the lexical resource.
        (let ((adv-dtn (make-dtn :referent adverb
                                 :resource (phrase-named 'advp))))
          (make-complement-node 'adv i adv-dtn)
          (add-attachment ap adv-dtn dtn))
        (else
          ;; It's simple and we should go straight to the adverb
         (add-attachment ap adverb dtn)))
      dtn)))



(defun attach-pp (prep object dtn pos)
  (let ((pp (make-dtn :resource (prep prep)))
        (ap (ecase pos
              (adjective 'adjp-prep-complement)
              (noun 'np-prep-adjunct)
              (verb 'vp-prep-complement))))
    (tr "Attaching a pp: ~a ~a via ~a" prep object ap)
    (make-complement-node 'prep-object object pp)
    (make-adjunction-node (make-lexicalized-attachment ap pp) dtn)))


(defun attach-verb (verb dtn)
  "The individual representing the verb can be carrying additional
   bindings that need to be expressed, such as negation"
  (make-complement-node 'v verb dtn)
  (when (and (sp::individual-p verb) ;; vs. a word
             (sp::indiv-binds verb)) ;; has some bindings
    (loop-over-bindings verb 'verb dtn))
  dtn)


(defun possibly-pronoun (item)
  "Wrapper around subject, object, and complement below."
  (cond ((sp::itypep item 'sp::pronoun/first/singular)
         (pronoun-named 'first-person-singular))
        ((sp::itypep item 'sp::pronoun/first/plural)
         (pronoun-named 'first-person-plural))
        ((sp::itypep item 'sp::pronoun/second)
         (pronoun-named 'second-person-singular))
        ((sp::itypep item 'sp::pronoun/plural)
         (pronoun-named 'third-person-plural))
        (t item)))

(defun attach-subject (subject dtn)
  (tr "Attaching subject: ~a" subject)
  (make-complement-node 's (possibly-pronoun subject) dtn))

(defun attach-object (object dtn)
  (tr "Attaching object: ~a" object)
  (make-complement-node 'o (possibly-pronoun object) dtn))

(defun attach-complement (complement dtn)
  (tr "Attaching complement: ~a" complement)
  (make-complement-node 'c (possibly-pronoun complement) dtn))

(defun attach-preposition (prep dtn)
  (make-complement-node 'p prep dtn))


;;;-------
;;; tests
;;;-------

(defun heavy-predicate-p (i)
  "Return true if the individual is too heavy to be used as a premodifier.
   Applied to predication and location bindings in attach-via-binding"
  (and (sp::individual-p i)
       ;; Could it be a pp or a clause that has a subj or obj that's not lambda
       (or (includes-real-subj/obj? i)
           (includes-tense? i)
           (sp::itypep i 'sp::relative-location)))) ;; pp case

;; Original definition. Doesn't deal properly with "phosphorylated MEK"
;; where that instance of 'phosphorylated' should be deemed light.
       #+ignore(remove-if (lambda (b)
                    (or (eq (sp::binding-value b) sp::**lambda-var**)
                        (eq (sp::var-name (sp::binding-variable b)) 'sp::name)))
                          (sp::indiv-binds i))

;;--- accessors

(defgeneric get-subject (item)
  (:method ((i sp::individual))
    (loop for v in (sp::find-subject-vars i)
       as value = (sp::value-of v i)
       when value do (return value))))

(defgeneric get-object (item)
  (:method ((i sp::individual))
    (loop for v in (sp::find-object-vars i)
       as value = (sp::value-of v i)
       when value do (return value))))

(defgeneric explicit-subject (item)
  (:documentation "Is the subject parameter a bound complement
     in the dtn?")
  (:method ((dtn derivation-tree-node))  ;;  get-parameter-binding
    (let ((s (parameter-named 's)))
      (loop for node in (complements dtn)
         when (eq (phrase-parameter node) s)
         collect (value node)))))

(defun includes-real-subj/obj? (i)
  "Discounts binding to the lambda variable as 'real'"
  (let ((subject (get-subject i))
        ;; ignoring possibilty of intransitives since we don't know
        ;; what the realization really would be
        (object (get-object i)))
    (when subject
      (when (sp::is-lambda-var subject)
        (setq subject nil)))
    (when object
      (when (sp::is-lambda-var object)
        (setq object nil)))
    (or subject object)))

(defun wrap-if-abstracted (value)
  "Called in loop-over-some-bindings to allow some value
   to go through to the parameter, even if its realization
   is the empty string."
  (if (sp::is-lambda-var value)
    (build-trace value)
    value))



;;--- ignore these

(defparameter *variables-to-ignore-for-attach-by-binding*
  '(sp::present
    sp::raw-text  sp::uid
    sp::name sp::word
    )
  "Holds list of variables that attach-via-bindings needn't bother
   to look at because either they don't contribute to the
   content we're generating or some other process will handle them.")

(defun ignorable-variable? (v)
  (memq (sp::var-name v) *variables-to-ignore-for-attach-by-binding*))
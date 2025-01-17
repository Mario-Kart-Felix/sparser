;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1992-1994,2020 David D. McDonald  -- all rights reserved
;;;
;;;      File:   "lookup"
;;;    Module:   "objects;rules:cfr:"
;;;   Version:   June 2019

;; 5.0 (9/3/92 v2.3) bumped the version to make changes that simplify
;;      the accounting. Revised most of the routines.
;;     (11/1) did multiply-through-nary-rhs
;; 5.1 (3/8/93) added capability to search through rhs with multiple
;;      completions and tweeked some return values.
;; 5.2 (8/27) added find/cfr because it was in the documentation and
;;      tweeked Multiply-through-terms-of-rhs to check against lhs
;;     (12/30/94) added Lookup-syntactic-rule

(in-package :sparser)


;;;-----------------------------------
;;; looking up rules from expressions
;;;-----------------------------------

(defun find-cfr (lhs-expression rhs-expressions)
  "Primary way to retrieve a rule from an expression of symbols and strings.
   Not used by internal rule-creating routines. Intended for external use
   by rule developers"
  (when lhs-expression ;; i.e. allow it to be nil
    (typecase lhs-expression
      (symbol)
      (string)
      (otherwise (error "The input to find/cfr is just like that of ~
                         Def-cfr~%  i.e. the labels should be given as ~
                         symbols or strings."))))
  (unless (listp rhs-expressions)
    (error "The second argument to find/cfr, the labels for the ~
            righthand side~%of the rule, must be a list"))
  (multiple-value-bind (cfr/s lhs rhs)
                       (lookup/cfr/expression lhs-expression
                                              rhs-expressions)
    (declare (ignore lhs rhs))
    cfr/s ))



(defun lookup/cfr/expression (lhs-symbol rhs)
  "Converts expressions (symbols, lists, strings) to labels
   and calls lookup/cfr to do the actual lookup."
  (let ((lhs-label
         (resolve/make lhs-symbol :source :def-category))
        (rhs-list-of-labels
         (if (and (eq 1 (length rhs))
                  (stringp (first rhs))
                  (not-all-same-character-type (first rhs)))
           (list (or (polyword-named (first rhs))
                     (define-polyword/expr (first rhs))))
           (mapcar #'resolve/make rhs))))
    (let ((cfr (lookup/cfr lhs-label rhs-list-of-labels)))
      (values cfr lhs-label rhs-list-of-labels))))




;;;-------------------------------------------------------
;;; finding the rule that corresponds to a righthand side
;;;-------------------------------------------------------

(defun lookup/cfr (lhs-label rhs-labels)
  "This routine emulates what will happen at runtime, returning
   the cfr this rhs picks out if there is one.
   If it's a binary rule, it's straight multiplication, though if
   multiple lhs are allowed, a further check is made against the
   list that the multiplication may send back.
   If it's unary, we include the lhs label to pick out the right
   one among the several meanings (cfrs) a word might have."
  (if (null (cdr rhs-labels)) ;; length = 1
    (lookup-unary-rule lhs-label rhs-labels)
    (lookup-rule/rhs rhs-labels)))

#+ignore ;; original version when these were used for duplication
         ;; checks when rules were being created
(defun lookup-rule/rhs (rhs-labels)
  "For a binary rule all that matters for rule identity is the
   two labels (words, polywords, categories) on its righthand side.
   We Look up the rule sets and indexes. If they are there then look at
   the labels to distinguish among the three sorts of rules."
  (let* ((left-label (first rhs-labels))
         (right-label (second rhs-labels))
         (left-rs (label-rule-set left-label))
         (right-rs (label-rule-set right-label)))
    (when (and left-rs right-rs)
      (let ((left-ids (rs-right-looking-ids left-rs))
            (right-ids (rs-left-looking-ids right-rs)))
        (when (and left-ids right-ids)
          (cond
            ((and (get-tag :form-category left-label)
                  (get-tag :form-category right-label))
             (lookup-syntactic-rule left-ids right-ids))
            ((or (get-tag :form-category left-label)
                 (get-tag :form-category right-label))
             (lookup-form-rule rhs-labels left-ids right-ids))
            (t (lookup-semantic-rule left-ids right-ids))))))))

;; New version. Not used when rules are being defined
(defun lookup-rule/rhs (rhs-labels)
  "For a binary rule all that matters for rule identity is the
   two labels (words, polywords, categories) on its righthand side.
   We Look up the rule sets and indexes. If they are there then look at
   the ids of the labels to distinguish among the three sorts of rules.
   This function's operation is complicated by the fact that now we
   will let ourselves use referential-categories in form or syntactic
   rules rather than just form-categories, consequently the type of
   the rule is determined by the def forms and is reflected in the
   pattern of the ids."
  (let* ((left-label (first rhs-labels))
         (right-label (second rhs-labels))
         (left-rs (label-rule-set left-label))
         (right-rs (label-rule-set right-label)))
    (when (and left-rs right-rs)
      (let ((left-ids (rs-right-looking-ids left-rs))
            (right-ids (rs-left-looking-ids right-rs)))
        ;;(break "left-ids: ~a~%right-ids: ~a" left-ids right-ids)
        (when (and left-ids right-ids)
          ;; Most categories now participate in both semantic and
          ;; form/syntactic rules, and typically have both
          ;; ids, so we check for semantic rules first
          (or (when (and (category-multiplier left-ids)
                         (category-multiplier right-ids))
                (lookup-semantic-rule left-ids right-ids))
              (when (and (form-multiplier left-ids)
                         (form-multiplier right-ids))
                (lookup-syntactic-rule left-ids right-ids))
              (when (or (form-multiplier left-ids)
                        (form-multiplier right-ids))
                (lookup-form-rule rhs-labels left-ids right-ids))) )))))

;;;-------
;;; cases
;;;-------

(defun lookup-semantic-rule/rhs (rhs)
  (let* ((left-label (first rhs))
         (right-label (second rhs))
         (left-rs (label-rule-set left-label))
         (right-rs (label-rule-set right-label)))
    (when (and left-rs right-rs)
      (let ((left-ids (rs-right-looking-ids left-rs))
            (right-ids (rs-left-looking-ids right-rs)))
        (when (and left-ids right-ids)
          (lookup-semantic-rule left-ids right-ids))))))

(defun lookup-semantic-rule (left-ids right-ids)
  (let ((left-semantic-id (car left-ids))
        (right-semantic-id (car right-ids)))
    (when (and left-semantic-id right-semantic-id)
      (multiply-ids left-semantic-id right-semantic-id))))


(defun lookup-form-rule (rhs-labels left-ids right-ids)
  (multiple-value-bind (edge-designator ;; or :left-edge :right-edge
                        form-label regular-label)
      (check-for-just-one-form-category rhs-labels)
    (let ( form-id  regular-id )
      (ecase edge-designator
        (:left-edge
         ;; the left (first) label of the pair in the rhs is the form category
         (setq form-id (cdr left-ids)
               regular-id (cdr right-ids)))
        (:right-edge ;; right label is
         (setq form-id (cdr right-ids)
               regular-id (car left-ids))))
      (when (and form-id regular-id)
        (if (eq edge-designator :left-edge)
          (multiply-ids form-id regular-id)
          (multiply-ids regular-id form-id))))))



(defun lookup-syntactic-rule/rhs (rhs)
  ;; called from do-syntax-rule/resolved, which knowns what it needs
  (let* ((left-label (first rhs))
         (right-label (second rhs))
         (left-rs (label-rule-set left-label))
         (right-rs (label-rule-set right-label)))
    (when (and left-rs right-rs)
      (let ((left-ids (rs-right-looking-ids left-rs))
            (right-ids (rs-left-looking-ids right-rs)))
        (when (and left-ids right-ids)
          (lookup-syntactic-rule left-ids right-ids))))))

(defun lookup-syntactic-rule (left-ids right-ids)
  (let ((left-form-id (cdr left-ids))
        (right-form-id (cdr right-ids)))
    (when (and left-form-id right-form-id)
      (multiply-ids left-form-id
                    right-form-id))))


(defun lookup-unary-rule (lhs rhs)
  "Go through the unary rules for the word (or label) on the rhs
   looking for one whose lhs is the same as the one passed in,
   otherwise return nil."
  (let* ((rule-set (rule-set-for (first rhs)))
         (rules (when rule-set
                  (rs-single-term-rewrites rule-set))))
    (when rules
      (dolist (cfr rules)
        (when (eq (cfr-category cfr) lhs)
          (return-from lookup-unary-rule cfr)))
      nil )))



#| OBE  Use a 'debris analysis' rule when you want more than two terms
   on the rhs. 

(defun multiply-through-terms-of-rhs (list-of-rhs-terms
                                      &optional lhs )
  ;; a broken out version of above (rather than having a single
  ;; case statement on length) e.g. used for form rules since they
  ;; are more restricted than general cfrs
  (let ((cfr/s
         (if (> (length list-of-rhs-terms) 2)
           (multiply-through-nary-rhs list-of-rhs-terms)
           (apply #'multiply-labels list-of-rhs-terms))))

    (when cfr/s
      (if lhs ;; then we're looking to see if a particular rule
              ;; exists so we check against this lhs and return
              ;; the corresponding cfr
        (then
          (if (listp cfr/s)
            (then (dolist (cfr cfr/s)
                    (when (eq lhs (cfr-category cfr))
                      (return-from multiply-through-terms-of-rhs
                                   cfr)))
                  nil )
            (if (eq lhs (cfr-category cfr/s))
              cfr/s
              nil )))
        cfr/s ))))

(defun multiply-through-nary-rhs (rhs-terms)
  (let ((rule
         (catch :nary-multiply
           (check-for-left-rollout nil rhs-terms))))
    (if rule
      (then
        ;; it's probably the final rule in the roll-out,
        ;; so we lookup the 'real' rule it stands in for
        (if (listp rule)
          rule ;; several rules already have this rhs
          (or (get-tag :rolled-out-from rule) rule)))
      nil )))


(defun check-for-left-rollout (last-prefix-category
                               remaining-rhs-terms)
  (if last-prefix-category
    (let ((prefix
           (multiply-labels last-prefix-category
                            (first remaining-rhs-terms))))
      (if prefix
        ;; check whether there is one definition or many
        (if (listp prefix)
          (lookup/multiple-completions prefix
                                       (cdr remaining-rhs-terms))
          (if (cdr remaining-rhs-terms)
            (check-for-left-rollout (cfr-category prefix)
                                    (cdr remaining-rhs-terms))
            (throw :nary-multiply prefix)))
        (else
          (throw :nary-multiply nil))))

    (let ((prefix
           (multiply-labels (first remaining-rhs-terms)
                            (second remaining-rhs-terms))))    
      (if prefix
        (if (listp prefix)
          (lookup/multiple-completions prefix
                                       (cddr remaining-rhs-terms))
          (if (cddr remaining-rhs-terms)
            (check-for-left-rollout (cfr-category prefix)
                                    (cddr remaining-rhs-terms))
            (throw :nary-multiply prefix)))
        (else
          (throw :nary-multiply nil))))))


(defun lookup/multiple-completions (rules remaining-terms)
  (if (null remaining-terms)
    ;; if there are no more terms to be folded in, then we're done
    (throw :nary-multiply rules)

    (let ((intermediary-dotted-rules
           (remove-if-not #'(lambda (r)
                              (eq :dotted-intermediary
                                  (cfr-form r)))
                          rules)))
      (if intermediary-dotted-rules
        (then
          ;; see if any of them fit this rhs
          (dolist (r intermediary-dotted-rules)
            ;; take the first rule that fits the terms
            (when (check-for-left-rollout (cfr-category r)
                                          remaining-terms)
              (return-from lookup/multiple-completions r)))

          ;; otherwise declare there's no rule with this rhs
          (throw :nary-multiply nil))
        (else
          (throw :nary-multiply nil))))))
|#

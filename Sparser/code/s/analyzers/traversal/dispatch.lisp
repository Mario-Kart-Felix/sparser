;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1994-1996,2011-2019  David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2010 BBNT Solutions LLC. All Rights Reserved
;;; 
;;;     File:  "dispatch"
;;;   Module:  "analyzers;traversal:"
;;;  Version:  November 2019

;; initiated 6/15/94 v2.3.  9/26 Fixed :multiple-initial-edges bug
;; 9/13/95 fleshed out stub for hook being a cfr. 9/15 fixed a bug.
;; 1/1/96 put in a trap for the 'span-is-longer-than-segment' case,
;; which seems to consistently indicate that there are embedded punct's
;; and the pair passed in to here aren't the ones that are intended
;; to match. 2/23/07 Removed the ecases. Added flag to permit long
;; segments. 2/22/10 Added a form category identical to the the edge
;; category so that we can write form rules against these if we want.
;; 0.1 (8/28/11) Cleaned up. Requiring :single-span to allow hook.
;;     (9/12/11) Added function for creating the obvious edge.
;; 0.2 (2/11/13) Adding check for an ordinary word needing to be
;;      reanalyzed when it appears in all caps or capitalized
;;     (7/23/13) Extended criteria for suspecting a hook.
;; 0.3 (8/8/15) Added *special-acronym-handling* to stop it always
;;      converting acronyms to proper nouns.

(in-package :sparser)

(unless (boundp '*allow-large-paired-interiors*)
  (defparameter *allow-large-paired-interiors* t))


(defparameter *special-acronym-handling* nil
  "Flag what will prohibit the creation of a proper name
  over single-spans of :all-caps. Set when the caller want
  to do the handling itself.")

;; (trace-sections)

(defun do-paired-punctuation-interior (type
                                       pos-before-open pos-after-open
                                       pos-before-close pos-after-close)

  (declare (special *special-acronym-handling* *allow-large-paired-interiors*
                    *treat-single-Capitalized-words-as-names*))
  (tr :paired-punct-interior type pos-after-open pos-before-close)

  (let ((layout (analyze-segment-layout pos-after-open
                                        pos-before-close))
        ;; when there are multiple single-term edges this choice
        ;; of accessor gives us the topmost (most recent) of
        ;; those edges
        (first-edge (right-treetop-at/edge pos-after-open)))

    (when (word-p first-edge)
      ;; these are irrelevant, so we turn off the flag that controls
      ;; later operations.
      (setq first-edge nil))

    (case layout
      (:single-span
       ;; This check probably dates from the original DM&P work
       (when (eq (edge-category first-edge)
                 (category-named 'segment))
         ;; then it's a dummy and we have to look underneath it
         (setq first-edge (leftmost-daughter-edge first-edge)
               layout (analyze-segment-layout
                       pos-after-open pos-before-close t)))

       ;; Some stock tickers and such are ordinary words and could
       ;; be captured as such. But they will be capitalized and
       ;; we can overrule that with another edge
       (when (one-word-long? first-edge)
         (when (eq (pos-capitalization (pos-edge-starts-at first-edge))
                   :all-caps)
           ;; That's enough evidence to recast the edge and take it
           ;; as an acronym or ticker symbol, but we'll leave that
           ;; to context to determine which one
           (unless (or *special-acronym-handling*
                       (eq (edge-form first-edge) (category-named 'proper-name))
                       (eq (edge-form first-edge) (category-named 'np)))
             ;; if so, then there's probably a hook for it and
             ;; we leave it alone.
             ;; Alternatively, in some text-types it's the thing
             ;; to do. C.f. WHO for the World Health Organization
             (unless *treat-single-Capitalized-words-as-names*
               (lsp-break "About to convert ordinary word to proper name"))
             (convert-ordinary-word-edge-to-proper-name first-edge)))))

      (:contiguous-edges
       (parse-between-parentheses-boundaries pos-after-open pos-before-close)
       (setq first-edge  ;; update the flag that controls the hook
             (right-treetop-at/edge pos-after-open)))

      (:span-is-longer-than-segment
       (unless *allow-large-paired-interiors*
         (error "~&~%Paired Punctuation:~
               ~%The span of text between the ~A~
               ~%at p~A and p~A is unreasonably large.~
               ~%Probably there is some sort of undetected imbalance.~%"
                type (pos-token-index pos-before-open)
                (pos-token-index pos-before-close))))

      ((or :null-span
           :no-edges
           :some-edges
           :has-unknown-words))

      (otherwise
       (push-debug `(,pos-before-open ,pos-after-open
                     ,pos-before-close ,pos-after-close))
       (error "Unexpected layout between paired punctuation: ~a" layout)))

    (setq layout (analyze-segment-layout pos-after-open pos-before-close))
    (tr :layout-between-punct layout)

    (labels ((referent-for-vanila-edge ()
               "Edges need referents, even when they are semantically vacuous"
               (if (and first-edge
                        (edge-p first-edge))
                   (edge-referent first-edge)
                   (let ((type-category
                          (category-named
                           (if (eq type :quotation-marks)
                               'QUOTATION
                               type))))
                     (find-or-make-individual type-category))))

             (vanila-edge (pos-before-open pos-after-close type &key referent)
               "Just cover the span between the punctuation (inclusive)
              with an edge labeled according to the type of bracket."
               (tr :vanila-paired-edge pos-before-open pos-after-close)
               (make-edge-over-long-span
                pos-before-open
                pos-after-close
                (case type
                  (:angle-brackets  (category-named 'angle-brackets))
                  (:square-brackets (category-named 'square-brackets))
                  (:curly-brackets  (category-named 'curly-brackets))
                  (:parentheses     (category-named 'parentheses))
                  (:quotation-marks (category-named 'quotation))
                  (otherwise
                   (break "unexpected type: ~a" type)))
                :form (case type
                        (:angle-brackets  (category-named 'angle-brackets))
                        (:square-brackets (category-named 'square-brackets))
                        (:curly-brackets  (category-named 'curly-brackets))
                        (:parentheses     (category-named 'parentheses))
                        (:quotation-marks (category-named 'quotation))
                        (otherwise
                         (break "unexpected type: ~a" type)))
                :referent (or referent
                              (referent-for-vanila-edge))
                :rule  :default-edge-over-paired-punctuation))

             (interior-hook (label)
               "Does this label have an 'interior action' associated with it.
              Goes with define-interior-action and ties the label to the
              function to be executed."
               (cadr (member (case type
                               (:angle-brackets  :interior-of-angle-brackets)
                               (:square-brackets :interior-of-square-brackets)
                               (:curly-brackets  :interior-of-curly-brackets)
                               (:parentheses     :interior-of-parentheses)
                               (:quotation-marks :interior-of-quotation-marks)
                               (otherwise
                                (break "unexpected type: ~a" type)))
                             (plist-for label)))))

      (if (and first-edge
               (eq layout :single-span))
        ;; Look for an action that's been defined for the category
        ;; on this edge for this type of punctuation.
        ;; See define-interior-action in analyzers/traversal/form.lisp
        (let ((hook (or (interior-hook (edge-category first-edge))
                        (interior-hook (edge-form first-edge)))))
          (if hook
            (then
              (tr :paired-punct-hook hook)
              (if (cfr-p hook)
                (do-paired-punct-cfr hook first-edge
                                     pos-before-open pos-after-close)
                (funcall hook
                         first-edge
                         pos-before-open pos-after-close
                         pos-after-open pos-before-close 
                         layout)))
            (else
              ;; There's no special action for this edge label
              ;; so just make the default edge
              (tr :no-paired-punct-hook first-edge)
              (vanila-edge pos-before-open pos-after-close type
                           :referent (edge-referent first-edge))
              #+ignore (elevate-spanning-edge-over-paired-punctuation
                       first-edge pos-before-open pos-after-close pos-after-open pos-before-close 
                       layout))))
        (else
          ;; A more complex layout, which doesn't have a scheme for
          ;; hooks yet.
          (tr :pp-not-single-span layout)
          (vanila-edge pos-before-open pos-after-close type))))))




(defun do-paired-punct-cfr (cfr first-edge
                            pos-before-leading-punct
                            pos-after-closing-punct
                            ;pos-after-leading-punct
                            ;pos-before-closing-punct
                            )

  ;; Called from Do-paired-punctuation-interior when there is
  ;; a value for the paired-punct hook for the category of the
  ;; first edge and that value has been systematized into a cfr.
  ;;   We make an edge from before the open punctuation mark to
  ;; after the closing mark following the directives on the cfr.

  (let ((label (cfr-category cfr))
        (form (cfr-form cfr))
        (referent (compute-paired-punct-referent cfr first-edge)))

    (let ((edge
           (make-edge-over-long-span
            pos-before-leading-punct
            pos-after-closing-punct
            label
            :form form
            :referent referent
            :rule cfr )))
      edge )))


(defun compute-paired-punct-referent (cfr first-edge)
  ;; This is written to finish a hook that was stubbed in 10/91
  ;; so it's not clear that it's the right thing to do today.
  ;;   We're in the process of making an edge over a bracket pair
  ;; on the basis of the edge within it -- sort of cloning it.
  ;; To that end we want here to copy up the established referent
  ;; of that edge.
  (declare (special *break-on-unexpected-cases*))
  (let ((referent-expression (cfr-referent cfr)))
    (case referent-expression
      (:the-single-edge
       (edge-referent first-edge))
      (:right-daughter
       (let ((right-daughter (edge-right-daughter first-edge)))
         (unless (edge-p right-daughter)
           (when *break-on-unexpected-cases*
             (break "Doing the referent of the first edge within ~
                     paired punctuation~%for the case of the right-~
                     daughter but that field~%in ~A~%isn't an edge~%~%"
                    right-daughter)
             (return-from compute-paired-punct-referent
               :error-in-trying-to-compute-referent)))
         (edge-referent right-daughter)))
      (otherwise
       (break "Unexpected referent-expression: ~a" referent-expression)))))




;;; function for edges spaning the paired punct.

(defun elevate-spanning-edge-over-paired-punctuation (first-edge
                                                      pos-before-open pos-after-close
                                                      pos-after-open pos-before-close 
                                                      layout )
  "Used by do-paired-punctuation-interior as a version of 'vanila-edge'. It just
   exposes the 'first-edge' as though the punctuation wasn't there"
  (declare (ignore layout ;; do-paired-punctuation-interior requires :single-span
                   pos-after-open pos-before-close))
  (make-chart-edge :category (edge-category first-edge)
                   :form (edge-form first-edge) ;;(category-named 'paired-punctuation) ;; 
                   :referent (edge-referent first-edge)
                   :starting-position pos-before-open
                   :ending-position pos-after-close
                   :left-daughter first-edge
                   :right-daughter :single-term
                   :rule 'elevate-spanning-edge-over-paired-punctuation))
  

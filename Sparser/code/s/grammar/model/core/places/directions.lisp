;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 1995-1999,2016-2021 David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2007 BBNT Solutions LLC. All Rights Reserved
;;;
;;;     File:  "directions"
;;;   Module:  "model;core:places:"
;;;  version:  October 2021

;; initiated in 1/9/95. Added string printer 1/9/96.
;; 0.1 (11/25/99) Changed the realizations to use the new schema protocol
;;      and flushed the treatment of prepositions that take np complements
;;      over to its own file [spatial prepositions] with their category
;;      in [places;object]. Broke out the two types as their own subcategories
;; 1.0 (9/5/07) Dumped the schema-driven realizations since they were just
;;  for 'standalone-word' and the rules they created instantiated the specific
;;  categories rather than the more general 'direction' category which is the
;;  better semantic discriptor. 11/1 Added hack from-direction. 
;; 1/4/16 putting rules on their individuals.

(in-package :sparser)

;; words are in model/dossiers/directions.lisp

;;;----------
;;; category 
;;;----------

(define-category  direction
  :instantiates  self
  :specializes   location
  :lemma (:common-noun "direction")
  :binds ((name :primitive word))
  :documentation "This is the cover category for the different sorts
 of terms that indicate direction: compass points, orientation terms
 like 'left' or 'front', and 'prospective direction phrases' (Hudson &
 Pullum p.688) like 'inwards'.
   We have to bind another instance of the variable name here because
 it's been restricted at location to 'name-of-location' (e.g. 'London')
 and/// the restriction parser doesn't understand the :primitive notation
 that we need.")

(defun string/direction (d)
  (let ((w (value-of 'name d)))
    (word-pname w)))


;;-- when it's inside parentheses, elevate it above them
(define-interior-action category::direction  :parentheses
  'elevate-spanning-edge-over-paired-punctuation)
  

;;;-------
;;; cases
;;;-------

;;---- "(to the) {left, front} (of <reference-point>)"
;;      "the left side of the block"  "the Left Bank"

;; These are np heads. When their deictic anchors are given explicitly
;; they appear as prepositional complements: "left of the garage"
;; except in the case of proper names where they're also simple classifiers:
;; "(to) John's left". 
;;   They also can be used adjectivally: "John's left ear", and Pullum lists
;; "left" as an adjective, so we have to be careful about the choice of
;; brackets. I'm going with the brackets that start NPs but not the finishers.

(define-category relative-direction
  :specializes direction
  :mixins (relative-location)
  :restrict ((ground partonomic))
  :realization (:mumble ((of-genitive :p ground)))
  :documentation "These are 'directions' to distinguish them
 from dependent directions like 'bottom' or 'side'. They get
 their 'ground' variable from relative-location.")


(defun define-standalone-direction (string)
  (define-function-term string 'common-noun
    :super-category 'relative-direction
    :rule-label 'direction
    :brackets '( .[np )))


;;---- "leftward(s)"

;; These are standalone adjuncts (H&P pg. 688, Quirk (Brown) pg. 471).
;; Because they don't take prenominal modifiers or determiners, I'm calling
;; them NPs, which is a fine starting point for pp complements defining
;; relative directions.
;; In British English the suffix is "wards", and I'll assume that we
;; want it in general.

(defun define-ward-direction (string)
  (let* ((word (or (word-named string)
                   (define-function-word string
                     :form 'np
                     :brackets '( .[np np]. ))))
         (i (define-individual 'direction :name word))
         (rule (define-cfr category::direction `(,word)
                 :form category::np
                 :referent i)))
    (make-corresponding-mumble-resource word :common-noun i) ;; misses np aspect
    (add-rule rule i)
    i))


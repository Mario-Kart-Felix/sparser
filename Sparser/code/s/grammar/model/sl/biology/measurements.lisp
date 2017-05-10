;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER COMMON-LISP) -*-
;;; Copyright (c) 2017 SIFT LLC. All Rights Reserved
;;;
;;;    File: "measurements"
;;;  Module: "grammar/model/sl/biology/
;;; version: May 2017

;; Broken out from terms 5/10/17

(in-package :sparser)

;;;----------------------------------
;;; measurement terms and bio-scalars
;;;----------------------------------

(define-category assay :specializes measure
  :realization
  (:noun "assay"))

(define-category data :specializes measurement
		 :realization
		 (:noun ("datum" :plural "data")))

;;/// N.b. the rule is written over the literal "fold"
(define-category n-fold :specializes measurement
  :binds ((number number))
  :realization
  (:noun "fold"
         :m number))
;; only used in phrases like nnn-fold, this is here to suppress the
;;  attempt to ascribe a biological meaning to the verb

(define-category order-of-magnitude :specializes unit-of-measure
  :realization
  (:noun ("order of magnitude"
          :plural "orders of magnitude")))

;; below is needed because of a use of "transients" in the CURE corpus
(define-category transient-measurement :specializes bio-measurement
  :realization  (:noun ("transientXXX" :plural "transients"))) ;; don't pick up "transient" from COMLEX, and don't allow "transient" as a singular noun

(noun "throughput" :super measurement)

(noun "dynamics" :super bio-scalar)
(noun "extent" :super bio-scalar) 
(noun "mass" :super bio-scalar)
(noun "proportion" :super bio-scalar)
(noun "scale" :super bio-scalar)     
;; OBE (noun "concentration" :super bio-scalar) ;;levels of incorporated 32P (January sentence 34) 
;; in harvard-terms

;;;------------------
;;; Units of measure
;;;------------------
;;-- see model/dossiers/units-of-measure.lisp for more forms.


(define-unit-of-measure "cm")
(define-unit-of-measure "dalton")
(define-unit-of-measure "kD")
(define-unit-of-measure "kb")
(define-unit-of-measure "mL")
(define-unit-of-measure "mg")
(define-unit-of-measure "ml")
(define-unit-of-measure "mg")
(define-unit-of-measure "mm")
(define-unit-of-measure "nM")
(define-unit-of-measure "ng")
(define-unit-of-measure "nm")
(define-unit-of-measure "pmol")
(define-unit-of-measure "pmol/min/mg")
(define-unit-of-measure "BMD") ;; bone mineral density -- can't find ID #
(define-unit-of-measure "IC50") ;; "half maximal inhibitory concentration"
(define-unit-of-measure "IC 50");; "half maximal inhibitory concentration"
(define-unit-of-measure "μm")
;;#+sbcl (define-unit-of-measure "μm")
;;(define-unit-of-measure "µm") this fails in ACL. Reading in UTF-8 ?
;; add mug as a synonym of ug and microgram
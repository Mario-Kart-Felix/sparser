;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1993-2000,2014-2021 David D. McDonald  -- all rights reserved
;;;
;;;     File:  "measurements"
;;;   module:  "model;core:amounts:"
;;;  Version:  February 2021

;; original version initiated 10/2/91
;; completely made over 9/18/93 in new semantics.  10/24/93 gave it rdata
;; 9/7/00 Added relative measurements. 12/22/00 tweaked realization.
;; Added rate of change.
;; 5/6/14 Pulled in categories, etc. from /sl/waypoints/xtensions-to-core
;; 9/24/14 Wrote an ugly (not general enough) set of rules to handle
;; the notion of the value of a qualitative rate. Probably needs a
;; custom schema if we see anything else like it. 1/8/15 Commented that
;; out as too much complexity for its value. 

(in-package :sparser)

;;;--------
;;; object
;;;--------

(define-category  measurement  ;; "10 yards"
  :specializes scalar ;; not attribute-value
  :instantiates self
  :lemma (:common-noun "measurement")
  :binds ((units . unit-of-measure)
          (quantity  :or quantity number))
  :realization (:tree-family  quantity+kind
                :mapping ((quantity . quantity)
                          (base . units)
                          (np . :self)
                          (np-head . unit-of-measure)
                          (modifier . (number quantity))
                          (result-type . :self))))

(define-category measurement-with-uid :specializes measurement
  :mixins (has-uid))

;;;----------
;;; coersion
;;;----------

(define-mixin-category capable-of-being-measured
  :specializes adds-relation ;; should be add-property
  :instantiates nil
  :documentation "Assigned to categories of stuff that are not amounts
    but which are conventionally talked about as though they were,
    such as proteins. E.g 'phosphorylated MAP2K1 is high', is short for
    'the amount of <protein> is high'. ")


;;;----------------------
;;; kinds of measurement
;;;----------------------
#|
"What distance does he like to run?" "400 meters"
"What's the distance to New York City from here?
"How far is it to NYC?"

See QGLS 8.3 and many other places where it's classified 
as an adverbial. Specifically a spatial-measure.

The basic case is "the <measure-term> is <measurement>
and the word can stand by itself "that distance"
|#

(define-category named-measure ; 
                 ;; Provides a common supercategory. ///Easily replaced
  :binds ((name :primitive word))
  :specializes measurement)


;;;----------------------------
;;; imported from bio;taxonomy
;;;----------------------------

(define-category ratio :specializes scalar-attribute
  :binds ((measured hyphenated-triple)
	  (divisor))
  :realization
     (:noun "ratio"
      :m measured
      :of measured
      :to divisor))

(define-category value
  :specializes measurement
  :realization (:noun "value")) ;; for "a high value"

(define-category level :specializes scalar-attribute
  :realization (:noun "level"))
#| ;; should be bio-level, because it restricts the argument
;;  but I don't want to impact parsing and Spire
 ;;levels of incorporated 32P (January sentence 34)
(define-category level :specializes bio-scalar
 :restrict ((measured-item (:or bio-chemical-entity bio-process)))
 :realization (:noun "level")) |#


;; more suspect imports -- have to generalize bio-method

(define-category measure
  :specializes activity-with-a-purpose
  :mixins (measuring-verb with-instrument)
  :realization 
  (:verb "measure"
   :with instrument))

(define-category measure-as-measurement :specializes attribute
  :realization (:noun "measure")
  )
     
(define-category correlate
  :specializes measure
  :realization (:verb "correlate")
  :documentation "The result of correlating something (does it
    have to be more than one thing?) is a 'corelation',
    which would be a process-result relationship")


;;;-------
;;; rate
;;;-------

(define-category rate
  :specializes measurement
  :binds ((units unit-of-measure)
          (per-unit unit-of-measure))
  :realization (:noun "rate")
  :documentation "Wikipedia: 'a rate it the ratio between two related
 quantities in different units'. It can be expressed using 'per' to
 separate the units, or by using a slash.")

#| Wikipedia: A rate defined using two numbers of the same units (such
as tax rates) or counts (such as literacy rate) will result in a
dimensionless quantity, which can be expressed as a percentage (for
example, the global literacy rate in 1998 was 80%), fraction, or
multiple. 
   Often rate is a synonym of rhythm or frequency, a count per
second (i.e., hertz); e.g., radio frequencies, heart rates, or sample
rates |#

(defgeneric make-a-rate (unit per-unit)
  (:documentation "Find or make a rate. Paradigm case (so far) is the
    slash pattern over time-units. Initially called from no-space
    code: make-edge-over-rate")
  (:method ((unit individual) (per-unit individual))
    (define-or-find-individual 'rate
        :units unit
        :per-unit per-unit)))

;;;-------------------------
;;; rate of change measures
;;;-------------------------

;; Original version, 9/00 -- Reconcile once it's easy
;;    to trace out to the users of a category.
#| This is broken out because the meaning is so different
   as well as the realization. The fact that they have the very
   same bindings is inmaterial. |#
#|   oops!   This is identical to 'measurement' What was I really
             thinking about. |#
(define-category proportional-measurement  ;; "2 inches a year"
  :specializes measurement
  :instantiates measurement ;; ??
  :binds ((units . unit-of-measure)  ;; 'scalar' or 'measurable' might be good
          (quantity :or quantity number))
  :realization (:tree-family  N-per-unit
                :mapping ((type . :self)
                          (N . quantity)
                          (unit . units)
                          (unit-head . unit-of-measure)
                          (unit-np . per-unit-of-measure)
                          (N-np . (quantity number))
                          (top-np . :self))))


;;---- virtually identical (modulo name choices) version
;; done for Canto.

(define-category unit-of-rate-of-change
  :specializes unit-of-measure
  :binds ((distance-measure . unit-of-measure) ;; e.g. miles
          (time-measure . time-unit)  ;; e.g. hour
          (name :primitive word)) ;; need compact form for generating
  :index (:permanent :sequential-keys distance-measure time-measure)
  ;; "knot" is a rate of change all in one word: one nautical mile per hour
  :realization (:tree-family  N-per-unit
                :mapping ((type . :self)
                          (N . distance-measure)
                          (unit . time-measure)
                          (unit-head . time-unit)
                          (unit-np . time-unit)
                          (N-np . unit-of-measure)
                          (top-np . :self))))

(defmacro def-rate-of-change-unit (unit-of-measure unit-of-time abreviations)
  ;;/// confirm that they're all strings
  (def-rate-of-change-unit/expr unit-of-measure unit-of-time abreviations))

(defun def-rate-of-change-unit/expr (unit-of-measure unit-of-time abbreviations)
  (let ((distance (find-or-make-individual 'unit-of-measure :name unit-of-measure))
        (time (find-individual 'time-unit :name unit-of-time)))
    (push-debug `(,distance ,time))
    (let ((unit (find-or-make-individual 'unit-of-rate-of-change
                  :distance-measure distance
                  :time-measure time)))
      (when abbreviations
        ;;//// it needs the plural -- parenthesize the marked case        
        (let ((*inhibit-constructing-plural* t))
          (declare (special *inhibit-constructing-plural*))
          (dolist (string abbreviations)
            (let ((word (define-word/expr string)))
              (make-rules-for-head :common-noun word (category-named 'unit-of-rate-of-change) unit)))
          (setq unit (bind-dli-variable 'name (word-named (car abbreviations)) unit))))
      unit)))



(define-category rate-measurement
  :specializes measurement
  :binds ((units . unit-of-rate-of-change)
          (quantity . number)) ;;  :or quantity number)
  :index (:permanent :sequential-keys units quantity)
  :documentation "Models a rate of change independently of the thing
    that is changing, e.g. '10 mph' is a rate as this defines it
    without saying what it is whose 'speed' as '10 mph'. That link
    is developed a bit in core/qualities/attribute.lisp."
  :realization (;; (:common-noun "rate") -- "rate" is an attribute, not the measurement itself
                (:tree-family  quantity+kind
                :mapping ((quantity . quantity)
                          (base . units)
                          (np . :self)
                          (np-head . unit-of-rate-of-change)
                          (modifier . (number quantity))
                          (result-type . :self)))))

(define-category qualitative-rate
  :specializes rate-measurement
  :index (:permanent :key name)
  :documentation "The category of any word that describes the rate
    at which something happens without giving it a precise value
    (for which we use 'rate'), e.g. 'fast', 'slow'. This could
    evalove when we get a better handle on attributes and their 
    values more generally. These terms are scalar: 'fast' is
    'more' than 'slow', and they can be refined with a set of
    pretty standard modifiers: '(go) a little bit faster'. 
    Like other qualitative measures of attributes they are always
    relative to the thematic participant of the process that they're
    describing: 'fast for a snail', cf. 'big for a mouse' vs. for
    an elephant."
  :realization (:adjective name))

(define-category rate-of-process
  :specializes measurement
  :binds ((process . process)
          (value . rate))
  ;;:index (:sequential-keys process value)
  :documentation "Gives the rate at which some process in taking place. ; 
    only makes sense when there's a particlar process. Could have
    several of these about the same process, some with qualitative 
    measures and some with quantitative."
) #|
  :realization ((:tree-family empty-head-of-complement
                 :mapping ((of-item . process)
                           (np . :self)
                           (base-np . "rate")
 I want the of construction to combine with a copula that will
 supply the value and don't see the obvious way to do it yet
 and a rube goldburg scheme will be confusing
|#

#| 1/8/15 The rule spanning "of" is now beyond the pale because
   it adds such complexity to Whack-a-Rule processing
;;  Use these ugly things instead for now.
(def-cfr rate-of-process-of (rate of) ;; the spanned 'of', not literal
  :form np ;;/// ugh
  :referent (:head left-edge
             :instantiate-individual rate-of-process))

(def-cfr rate-of-process (rate-of-process-of process)
  :form np
  :referent (:head left-edge
             :bind (process right-edge)))

(find-or-make-value-categories 'qualitative-rate)
;;  =>  is-qualitative-rate

(def-cfr rate-of-process (rate-of-process is-qualitative-rate)
  :form s
  :referent (:head left-edge
             :bind (value right-edge)))
|#






;;;---------------------
;;; parentheses handler
;;;---------------------

(define-interior-action  category::measurement  :parentheses
  'elevate-measurement-within-parens)

(defun elevate-measurement-within-parens (measurement ;; first-edge
                                          pos-before-open pos-after-close
                                          pos-after-open pos-before-close 
                                          layout )
  ;; Respan the parens with a copy of the measurement edge
  (declare (ignore layout ;; do-paired-punctuation-interior requires :single-span
                   pos-after-open pos-before-close))
  (make-chart-edge :category (edge-category measurement)
                   :form (edge-form measurement)
                   :referent (edge-referent measurement)
                   :starting-position pos-before-open
                   :ending-position pos-after-close
                   :left-daughter measurement
                   :right-daughter :single-term
                   :rule :elevate-measurement-within-parens))

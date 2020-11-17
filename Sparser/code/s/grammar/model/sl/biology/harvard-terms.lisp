;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER COMMON-LISP) -*-
;;; Copyright (c) 2017-2019 SIFT LLC. All Rights Reserved
;;;
;;;    File: "harvard-terms"
;;;  Module: "grammar/model/sl/biology/
;;; version: May 2019

;; Isolating terms, etc. that are specific to handling the texts
;; from HMS.

(in-package :sparser)

;;;---------------------
;;;   scalars, et al.
;;;---------------------

(define-category bio-amount :specializes bio-scalar
  :realization
  (:noun "amount"))
#| and so are active in catalytic amounts.
the amount of α-catenin
the total amounts of α-catenin ;; similar, same, initial
their relative amounts remained unchanged
for various amounts of time
increasing amounts of recombinant XRCC1.
(dynamic-model 54 "Double the amount of total BRAF.")
|#


(define-category frequency :specializes bio-scalar
  :realization
  (:noun "frequency"))

(define-category peak
  :specializes bio-scalar
  :realization (:noun "peak"
                :in measured-item) ;; "a peak in the measured amount ..."
  :documentation "The preposition 'in' does the same work as 'of'
    in other kinds of amounts / quantities of stuff. In biology
    it seems most appropriate when we are describing locations
    in graphs, e.g. 'dip' ")

(define-category bio-concentration
  :specializes bio-scalar
  :realization
    (:noun "concentration"))

(define-category scalar-variation
  :specializes bio-predication)




;;;---------------------------------------
;;; verbs particular to Harvard sentences
;;;---------------------------------------

(define-category remain
  :specializes be
  :mixins (bio-relation)
  :restrict ((participant biological)) 
  ;; got 'subject' from be where there is no restriction, though
  ;; there is a subject v/r on bio-relation
  :realization
      (:verb "remain"
       :etf (sv)
       ;; remains to be determined
       :to-comp theme))
(make-copular-def "remain") ;; gives it the adjective rules


;; failed to find a treatment for pancreatic cancer
(define-category fail :specializes aspectual-relation
  :restrict ((theme (:or bio-process evidence)))
  :realization 
    (:verb "fail"  
     :etf (sv) ))


;; mostly passive -- "... are found ..."
(define-category bio-find
  :specializes bio-process
  :mixins (bio-rhetorical) ;; to allow composition as comp. of "fail"
  :binds ((object biological)) ;; "found a treatment for ..."
  :realization
    (:verb ("find" :past-tense "found")
     :etf (svo-passive)
     :o object))

(define-category finding
  :specializes bio-process
  :mixins (bio-rhetorical)
  :realization (:noun "finding")) ;; really for "findings"
#| From show-sents
(aspp2 62
 "These findings established ASPP2 as a tumor suppressor and an activator
 of p53 family.") 
(dry-run 13 "These data support our in vitro findings that monoubiquitination
increases the population of active, GTP–bound Ras through a defect in
sensitivity to GAP–mediated regulation.") 
(dec-test 19
 "The mechanism we describe is another paradigm of RAF activation downstream 
of RAS and based on our findings, we propose the following mechanism 
by which this occurs.") |#



;;;-----------------------------
;;; verbs that apply to scalars
;;;-----------------------------

(define-category decrease
  :specializes negative-bio-control
  :binds ((theme biological)
          (level measurement))
  :realization
  (:verb "decrease" 
   :etf (svo-passive)
   :for theme
   :in theme
   :oc level ;; 'object complement'
   :to level))
;; Potentially problematic since the plural will misparse
;; "monoubiquitination decreases". Committing horrible hack
;; of putting in a dummy plural to circumvent that.
;; When we finally encounter are legitimate use of the
;; plural noun form we'll have to reconsider all this.
(def-synonym decrease (:noun ("decrease" :plural "ddddecrease")))

   
(define-category drop
  :specializes decrease
  :realization (:verb "drop" :etf (svo-passive)))
 (define-category taper-off
  :specializes decrease
  :realization (:verb ("taper off" :present-participle "tapering off"
                              :past-tense "taper off")
               :etf (sv)))

(define-category vanish
  :specializes negative-bio-control
  :binds ((theme biological)
          (level measurement))
  :realization
  (:verb "vanish" 
   :etf (sv)
   :for theme
   :in theme
   :oc level
   :to level))

  
;;//// why such different slots from 'decrease' ??
;; added 'level' 5/31/19 ddm
(define-category increase
  :specializes positive-bio-control
  :binds ((level measurement))
  :restrict ((object (:or ;;bio-chemical-entity
                      bio-entity ;; allows for "population"
                      bio-scalar)))
  :realization
    (:verb ("increase" :third-singular "increases"  :past-tense "increased"
            :present-participle "increasing")
     :etf (svo-passive)
     :for object
     :in object
     :in affected-process
     :of object
     :oc level
     :optional-object t))
;; DAVID -- why can't I put this in the previous definition -- the NOUN form gets clobbered
(def-synonym increase
    (:noun "increase"))



;;--- bio-scalar

;; (p/s "Decrease the binding rate of NRAS and BRAF.")
(delete-noun-cfr (resolve "rate")) ;;/// override it

(define-category process-rate
 :specializes bio-scalar
 :binds ((components biological)
         (process bio-process))
 :realization 
    (:noun "rate"
     :for components
     :m process))
(def-synonym process-rate (:noun "kinetics"))

#| The parser will do "binding rate" compositionally, and will put
the 'binding' in the process slot of the process-rate object.
Unfortunately, generating from that requires coercing 'binding' 
into a particple in order to provide an adjective realization,
which if further than is worth going just now. (Same issue as we
have with phosphorylated as a preposed modifier.) |#
(define-category binding-rate
  :specializes process-rate
  :realization (:noun "binding rate"))

(define-category dissociation-rate
  :specializes process-rate
  :realization (:noun "dissociation rate"))

(define-category catalysis-rate
  :specializes process-rate
  :realization (:noun "catalysis rate"))


;; e.g. displayed sustained ERK phosphorylation
(define-category sustained
   :specializes scalar-variation
   :binds ((theme (:or process bio-scalar
                       bio-chemical-entity)) ;; see note
           (level bio-scalar)
           (above-level bio-scalar))
   :realization
      (:verb "sustain"
       :etf (svo-passive)
       :adj "sustained"
       :o theme
       :at level
       :above above-level))
#| Note -- When we say "Is ERK1 sustained at a high level"
 We really mean is 'the amount of ERK1' at a high level
 because the only kind of thing that can be at some level
 is a scalar, or better a scalar amount to reflect the
 fact that under other conditions it would be a some other
 level. In a world with more time (this is May 2019), we
 could work up a procedure for coercing the protein into
 an amount of protein. Or in general, coerce the object
 (e.g. 'the pitch of a note over time', 'the livelyhood of
 the American middle class') to whatever its  natural 
 scalar variant is. |#


;;--- positive-bio-control

(define-category make-double
  :specializes positive-bio-control
  :restrict ((object (:or biological bio-scalar)))
  :binds ((theme biological)
          (level (:or measurement bio-scalar)))
  :realization
        (:verb "double" 
         :etf (svo-passive)
         :for theme
         :in theme
         :to level))


;; "vanish" comes in from Comlex
#|(:source :comlex :comlex ((:subc ((pp :pval ("from" "into")) (intrans))))
 :inflection-of-verb #<word "vanishes"> :verb-inflections
 (#<word "vanishing"> #<word "vanished"> #<word "vanishes">))
(dynamic-model 52 "Does the BRAF-NRAS complex vanish?") 
(dynamic-model 53 "Does the BRAF-NRAS complex vanish at some time?") 
(dynamic-model 63
 "Does the BRAF-NRAS dimer vanish even if we increase the binding rate of NRAS and BRAF?")
 |#


;;--- bio-relation

(define-category reach
  :specializes bio-relation
  :restrict ((participant (:or bio-scalar measurement biological))
             (theme (:or bio-scalar measurement biological)))
  :realization
      (:verb "reach"
       :etf (svo)))


;;--- bio-event-relation

(define-category follow
  :specializes bio-event-relation
  :realization
     (:verb ("follow" :past-tense "followed" :present-participle "followingxx"
            ;; this is intended to suppress definitions of "followed" and "follows"
                      :third-singular "follows")
      :etf (svo-passive)))


(define-category precede
  :specializes bio-event-relation
  :realization
    (:verb "precede" :etf (svo-passive)))



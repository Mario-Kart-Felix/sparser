;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 1992-1998,2011-2019 David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2007-2009 BBNT Solutions LLC. All Rights Reserved
;;;
;;;     File:  "transitive"
;;;   Module:  "grammar;rules:tree-families:"
;;;  version:  October 2019

;; initiated 8/5/92 v2.3, added passives 8/24
;; 0.1 (10/13) reorganized (in)transitive to fit the paper
;; 0.2 (8/3/93) changed label on trans/passive to give the schema
;;      exploration routine something to look for.
;;     (7/23/98) Added transitive/new-head
;;     (6/26/07) Added transitive/pp
;; 0.3 (1/29/08) In intransitive, changed the vg to vp
;;     (4/20/09) moved transitive/pp to verbs-taking-pps in order to specialize it
;;     (8/7/11) moved in transitive-location, which isn't all that well designed. 
;;     (7/31/13) Added passive for "martyered" which is never active
;;     (5/12/14) Adding subj/verb+np because C3 is parsing from the left
;;      and composed "suv + enter" before it see's the new location np.
;;     (6/10/14) Added passive/with-by-phrase for "regulated by"

(in-package :sparser)


(define-exploded-tree-family  intransitive
  :description "A verb that requires only a subject to have a complete sentence.
     It may be followed by prepositional phrases that carry crucial information,
     but that information may also just be conveyed by context."
  :binding-parameters ( agent )
  :labels ( s vp np/subject ) ;; shouldn't that be vg ???
  :cases
     ((:subject (s  (np/subject vp)
                 :head right-edge
                 :binds (agent left-edge)))
      ))


(define-exploded-tree-family  transitive
    :description "A verb that requires a subject and a direct object to have 
     a complete sentence. This category is intended for verbs that -never- appear 
     in the passive; their subjects will always be agents and their objects themes."
    :binding-parameters ( agent patient )
    :labels ( s vp vg np/subject np/object )
    :cases
    ((:subject (s  (np/subject vp)
                   :head right-edge
                   :function (assimilate-subject left-edge right-edge)))

     (:direct-object (vp  (vg np/object)
                          :head left-edge
                          :binds (patient right-edge)))
     ))



(define-exploded-tree-family  transitive/new-head
  :description "The type that runs up the headline after the first composition with
     the verb is different from that of the verb, e.g. the verb might be 'be'."
  :binding-parameters ( agent patient )
  :labels ( s vp vg np/subject np/object result-type )
  :cases
     ((:subject (s  (np/subject vp)
                 :head right-edge
                 :binds (agent left-edge)))

      (:direct-object (vp  (vg np/object)
                       :instantiate-individual result-type
                       :binds (patient right-edge))
                      :head left-edge)
      ))


(define-exploded-tree-family  transitive/passive
  :description "A verb that requires a subject and a direct object 
     to have a complete sentence. These verbs can appear in the passive, 
     proceeded by some form of the auxiliary 'be'. When passive, the agent 
     may or may not be included as a later prepositional 'by' phrase"
  :incorporates transitive
  :binding-parameters ( patient )
  :labels ( vp vg np/object )
  :cases
     ((:passive (s  (np/object vg/+ed)
                       :head right-edge
                       :binds (patient left-edge)))
      ))

(define-exploded-tree-family  passive
  :description "For a verb that only appears in the passive."
  :binding-parameters ( patient )
  :labels ( vp vg np/object )
  :cases
     ((:passive (s  (np/object vg/+ed)
                       :head right-edge
                       :binds (patient left-edge)))
      ))


(define-exploded-tree-family  passive/with-by-phrase
  :description "Standard inverted logical argument passive, with a parameter
      for what the complement of the by-phrase is bound to. The preposed patient
      argument is required, and its presence instantiates the result-type."
  :incorporates transitive
  :binding-parameters ( agent patient )
  :labels ( s vp vg np/patient np/agent by-pp result-type )
  :cases 
     ((:subject (s  (np/patient vp/+ed)
                  :instantiate-individual result-type
                  :binds (patient left-edge)
                  :head right-edge))
      (:by-phrase (by-pp ("by" np/agent)
                    :form pp
                    :head right-edge
                    :daughter right-edge))
      (:passive-with-by (s (s by-pp)
                         :head left-edge
                         :binds (agent right-edge)))))


(define-exploded-tree-family  transitive-loc-comp
  :description "Two post-verb arguments, a direct object and constituent
      describing a location, e.g., 'I put the block in the box'"
  :binding-parameters ( agent patient location )
  :labels ( s vp vg np/subject np/object loc )
  :cases
     ((:subject (s (np/subject vp)
                  :head right-edge
                  :binds (agent left-edge)))
      (:direct-object (vp (vg np/object)
                        :head left-edge
                        :binds (patient right-edge)))
      ;; Note that we pick up the first (direct) object
      ;; on the vg, but the second (location) object
      ;; is on the vp, which is a crude but workable way
      ;; to enforce consituent order.
      (:location (vp (vp loc)
                   :head left-edge
                   :binds (location right-edge)))))  

(define-exploded-tree-family  transitive-location
  :description "Tailored to specific case in checkpoint domain where
     different categories of location needed to be distinguished 
     in the instantiating arguments"
  :binding-parameters ( agent  location )
  :labels ( s vp vg np/subject loc1 loc2 loc3 )
  :cases
     ((:subject (s (np/subject vp)
                 :head right-edge
                 :binds (agent left-edge)))
      (:deictic-loc (vp (vg loc1) ;; deictic-location -- only in literals
		      :head left-edge
		      :binds (location right-edge)))
      (:location (vp (vg loc2) ;; location)
		    :head left-edge
		    :binds (location right-edge)))
      (:location (vp (vg loc3) ;; spatial-orientation)
		    :head left-edge
		    :binds (location right-edge)))))


(define-exploded-tree-family subj/verb+np
  :description "This is the equivalent of transitive or transitive-location
     except that we are rolling of left to right rather than right to left"
  :binding-parameters ( object )
  :labels ( s np/object )
  :cases ((:direct-object (s (s np/object)
                           :head left-edge
                           :binds (object right-edge)))))




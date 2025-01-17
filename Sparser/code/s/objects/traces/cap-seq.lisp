;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1993-1995,2013-2021  David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "cap seq"
;;;   Module:  "objects;traces:"
;;;  Version:  September 2021   

;; initiated 5/26/93 v2.3. added two more moments 12/17. And more 1/7/94.
;; Added traces for "of" in the scan 5/3. Added start/end fns 6/13.
;; (7/22) added traces in Classify and beyond.  
;; Extended yet again 4/29/95 ..5/21. 2/4/13 Added for new path through
;; driver. And again 5/28/13 for the parsing process.

(in-package :sparser)

(defparameter *trace-pnf* nil)
(defun trace-pnf ()
  (setq *trace-pnf* t))
(defun untrace-pnf ()
  (setq *trace-pnf* nil))

(defvar *pnf-creation* nil
  "For when we introduce new names, people, etc")
(defun trace-pnf-creation ()
  (setq *pnf-creation* t))
(defun untrace-pnf-creation ()
  (setq *pnf-creation* nil))


;;;---------------
;;; driver traces
;;;---------------

(deftrace :initiating-PNF (pos)
  (when *trace-pnf*
    (trace-msg "Initiating the Proper Name Facility at p~A for ~A"
               (pos-token-index pos) (pos-terminal pos))))

(deftrace :pnf/preempted ()
  (when *trace-pnf*
    (trace-msg "PNF: the 'capitalization is uniformative flag is up~
                ~%   returning nil.")))

(deftrace :pnf/fn-word-at-sentence-start (word)
  (when *trace-pnf*
    (trace-msg "PNF: Ignoring the word \"~a\" because its at a sentence start"
               (word-pname word))))

(deftrace :pnf/sequence-ended (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the sequence ended at p~A" (pos-token-index pos))))


(deftrace :pnf/classification (edge pos)
  (when *trace-pnf*
    (trace-msg "PNF: the result is ~A~
              ~%        at p~A" edge (pos-token-index pos))))

(deftrace :pnf/aborted-during-classification ()
  (when *trace-pnf*
    (trace-msg "PNF: Aborted during classification")))
  



;;;-------------------------------
;;; traces from external routines
;;;-------------------------------

(deftrace :pnf/sm-encountered (pos)
  (when *trace-pnf*
    (trace-msg "PNF: recognized a section-marker in the course of the ~
                embedded parse~%   terminating the span at p~A"
               (pos-token-index pos))))


;;;-------------
;;; scan traces
;;;-------------

(deftrace :cap-seq-looking-at (pos)
  (when *trace-pnf*
    (trace-msg "PNF: Checking for continuation at p~A, \"~A\""
               (pos-token-index pos)
               (word-pname (pos-terminal pos)))))

(deftrace :cap-seq-continues/status (cap-state bracket)
  (when *trace-pnf*
    (trace-msg "PNF:    Its capitalization is ~A~
              ~%        Its bracket state is ~A"
               cap-state bracket)))

(deftrace :cont-caps-edge (edge)
  (when *trace-pnf*
    (trace-msg "PNF: Capitalized edge extends sequence: ~a"
               edge)))

(deftrace :lower-case-non-boundary-extends-over (word yes?)
  ;; called by lc-non-boundary-word-that-may-extend-cap-seq?
  (when *trace-pnf*
    (trace-msg "PNF:  lowercase word ~a ~a extend the sequence"
               word (if yes? "does" "does not"))))

(deftrace :lower-case-extends-over (word yes?)
  ;; called by lc-word-that-may-extend-cap-seq?
  (when *trace-pnf*
    (trace-msg "PNF:  lowercase word ~a ~a extend the sequence"
               word (if yes? "does" "does not"))))

(deftrace :continuing-over-lc (pos hyphen?)
  ;; called from cap-seq-continues-from-here?/aux
  (when *trace-pnf*
    (trace-msg "PNF:  continuing over ~a ~a"
               (pos-terminal pos)
               (if hyphen? "and the hypen after it" ""))))


(deftrace :pnf/next-pos-is-punct (pos)
  (when *trace-pnf*
    (trace-msg "PNF: The next word, \"~A\", is punctuation"
               (pos-terminal pos))))

(deftrace :pnf/no-initial ()
  (when *trace-pnf*
    (trace-msg "PNF:    there is no initial in front of it")))

(deftrace :pnf/initial (pos final?)
  ;; checkout-period-for-capseq
  (when *trace-pnf*
    (if final?
      (trace-msg "PNF: and there is an initial in front of it.~
                ~%     but it is the EOS period")
      (trace-msg "PNF: and there is an initial in front of it.~
                ~%     continuing the scan with p~A"
                 (pos-token-index pos)))))

(deftrace :pnf/abbreviation ()
  (when *trace-pnf*
    (trace-msg "PNF:    but there was an abbreviation")))

(deftrace :pnf/no-abbreviation ()
  ;; in checkout-period-for-capseq
  (when *trace-pnf*
    (trace-msg "PNF:    nor was there an abbreviation~
              ~%   Ending the scan")))

(deftrace :pnf/pw (pos)
  (when *trace-pnf*
    (trace-msg "PNF:    The single letter in front of it started ~
                a successful polyword.~
              ~%     continuing the scan with p~A"
               (pos-token-index pos))))



(deftrace :pnf/next-pos-introduces-] (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the next word, ~A, introduces a closed bracket"
               (pos-terminal pos))))

(deftrace :lc-introduces-]-but-actual-doesnt  (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the lowercase version of the next word, ~A~
              ~%     introduces a closed bracket but the actual word there ~
                doesn't" (pos-terminal pos))))

(deftrace :pnf/]-ignored-because-of-initial ()
  (when *trace-pnf*
    (trace-msg "PNF:    but we're continuing, because it's an initial")))

(deftrace :pnf/caps-after-of (pos-after)
  (declare (ignore pos-after))
  (when *trace-pnf*
    (trace-msg "PNF:    but we're continuing, because the next word is ~
                capitalized")))

(deftrace :pnf/stop-at-close-bracket ()
  (when *trace-pnf*
    (trace-msg "PNF:    so the PNF scan is stopping here.")))



(deftrace :pnf/next-pos-is-lowercase (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the next word, ~A, is lowercase"
               (pos-terminal pos))))


(deftrace :pnf/next-pos-is-digits (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the next word, ~A, is a digit sequence"
               (pos-terminal pos))))


(deftrace :pnf/next-pos-is-capitalized-continuing-scan (pos)
  (when *trace-pnf*
    (trace-msg "PNF: the next word, ~A, is capitalized~
                ~%  continuing the scan beyond p~A"
               (pos-terminal pos) (pos-token-index pos))))


;;;------------------
;;; lookahead traces
;;;------------------

(deftrace :abbrev-check-found-one (abbrev full)
  ;; called from Check-for-abbreviation-before-position
  (when *trace-pnf*
    (trace-msg "PNF Abbreviation check:~
              ~%       \"~A\" is an abbreviation for \"~A\""
               (word-pname abbrev)
               (etypecase full
                 (word (word-pname full))
                 (category (cat-name full))))))


(deftrace :abbrev-check-found-nothing (non-abbrev-word)
  ;; called from Check-for-abbreviation-before-position
  (when *trace-pnf*
    (trace-msg "PNF Abbreviation check:~
              ~%       \"~A\" isn't an abbreviation"
               (word-pname non-abbrev-word))))



(deftrace :initial-found (prior-position position)
  ;; called from Check-for-initial-before-position
  (when *trace-pnf*
    (trace-msg "PNF: initial ~A from p~A to p~A"
               (pos-terminal prior-position)
               (pos-token-index prior-position)
               (pos-token-index position))))

(deftrace ::initial-made-edge (edge)
  ;; called from Check-for-initial-before-position
  (when *trace-pnf*
    (trace-msg "     spanned it with ~A" edge)))

(deftrace :initial-fired-fsa (new-position)
  ;; called from Check-for-initial-before-position
  (when *trace-pnf*
    (trace-msg "     it triggered an fsa that went to p~A"
               (pos-token-index new-position))))




;;;-----------------------
;;; classification traces
;;;-----------------------

(deftrace :pnf/classifying-span (from to)
  ;; called from Classify-and-record-name
  (when *trace-pnf*
    (trace-msg "PNF: Classifying span from p~A to p~A"
               (pos-token-index from) (pos-token-index to))))

(deftrace :pnf/one-edge-over-multi-word-span (edge)
  ;; called from C&R-single-spanning-edge
  (when *trace-pnf*
    (trace-msg "PNF:    which is covered by one edge -- we're done.~
                ~%         ~A" edge)))


;;--- one word span

(deftrace :pnf/classifying-one-word-span (word)
  ;; called from C&R-single-word
  (when *trace-pnf*
    (trace-msg "PNF:    which is just the word \"~A\""
               (word-pname word))))

(deftrace :pnf/no-edges-over-word (word)
  (when *trace-pnf*
    (trace-msg "PNF:    no edges over \"~A\""
               (word-pname word))))

(deftrace :pnf/items-for-unknown-word (word name name-word)
  (when *trace-pnf*
    (trace-msg "PNF:  Giving \"~A\" the name ~a based on ~a"
               (word-pname word) name name-word)))

(deftrace :pnf/edges-over-word (word ev)
  (when *trace-pnf*
    (trace-msg "PNF:    There are ~a edges over \"~A\""
               (ev-number-of-edges ev)
               (word-pname word))))

(deftrace :pnf/single-edge-is (edge)
  (when *trace-pnf*
    (trace-msg "PNF:  The edge is ~a~
              ~%        form = ~a" edge (edge-form edge))))



(deftrace :found-subsequent-reference (edge referent
                                       its-referent new-edge)
  (when *trace-pnf*
    (trace-msg "SubseqRef: The referent of e~a, ~a~
              ~%   is a subsequent reference to ~a~
              ~%   so we're respanning it with e~a" 
               (edge-position-in-resource-array edge) referent
               its-referent (edge-position-in-resource-array new-edge))))


;;--- in known-sequence

(deftrace :recognized-sequence-as (ne items)
  (declare (ignore items))
  (when *trace-pnf*
    (trace-msg "SubseqRef: recognized sequence as ~a" ne)))

(deftrace :pnf-items-no-known-sequence (items)
  (when *trace-pnf*
    (trace-msg "SubseqRef: unknown sequence: ~a" items)))



(deftrace :pnf/parsing-span (from to)
  ;; called from C&R-multi-word-span
  (when *trace-pnf*
    (trace-msg "PNF/classify: parsing \"~A\""
               (string-of-words-between from to))))


(deftrace :pfwpnf (pos-before final-pos)
  (when *trace-pnf*
    (trace-msg "[pfwpnf] called from ~a to p~a"
               pos-before (pos-token-index final-pos))))

(deftrace :pfwpnf-edge (edge)
  (when *trace-pnf*
    (trace-msg "[pfwpnf] found ~a" edge)))

(deftrace :pfwpnf/fsa-succeeded (word ended-at)
  (when *trace-pnf*
    (trace-msg "[pfwpnf] fsa triggered by ~a ended at p~a"
               word (pos-token-index ended-at))))



(deftrace :terminated-early-at (pos)
  ;; called from Classify-&-record-span
  (when *trace-pnf*
    (trace-msg "PNF/classify: terminated early at p~A"
               (pos-token-index pos))))

(deftrace :c&r/continuing-at-p-after-skipping-lc-word (pos word)
  ;; called from Classify-&-record-span
  (when *trace-pnf*
    (trace-msg "PNF/classify: Resuming classification at p~A after skipping~
              ~%                 the word \"~A\""
               (pos-token-index pos) (word-pname word))))

(deftrace :c&r/continuing-at-result-pos (pos)
  ;; called from Classify-&-record-span
  (when *trace-pnf*
    (trace-msg "PNF/classify: Resuming classification at p~A"
               (pos-token-index pos))))


(deftrace :result-of-examine (result)
    ;; called from Classify-&-record-span
  (when *trace-pnf*
    (trace-msg "PNF/classify: Examine returned ~a" result)))


;;;---------
;;; Examine
;;;---------

(deftrace :examining (label tt)
  ;; called from Examine-capitalized-sequence
  (declare (ignore tt))
  (when *trace-pnf*
    (trace-msg "PNF Examine: next tt is labeled ~A" label)))

(deftrace :throwing-out-prefix (tt)
  ;; called from Examine-capitalized-sequence
  (when *trace-pnf*
    (trace-msg "PNF Examine: Throw'ing out because of ~A" tt)))


(deftrace :scan-went-beyond-inc-term (new-final-pos)
  ;; called from Examine-capitalized-sequence
  (when *trace-pnf*
    (trace-msg "PNF Examine: The scan continued beyond an 'inc-term'~
              ~%             and presumably took in too many words.~
              ~%             Truncating the sequence at p~A"
               (pos-token-index new-final-pos))))


(deftrace :pnf/of-bad-prefix (p)
  ;; called from Examine-capitalized-sequence
  (when *trace-pnf*
    (trace-msg "PNF Examine: The word/s to the left of 'of' ~
                indicate~
              ~%             that it is not part of the name.~
              ~%      Truncating it at p~A"
               (pos-token-index p))))

(deftrace :pnf/classifying-remainder (from to)
  (when *trace-pnf*
    (trace-msg "PNF: Resuming classification of the remainder:~
              ~%       \"~A\"" (string-of-words-between from to))))

(deftrace :name-category-is (category)
  ;; called from categorize-and-form-name just before it does the 
  ;; find or make for a name
  (when *trace-pnf*
    (trace-msg "PNF: Going to find or make name for a ~a" category)))



(deftrace :retrieved-from-name-word (i nw)
  ;; called from subsequent-reference-off-name-word
  (when *trace-pnf*
    (trace-msg "PNF: Retrieved ~a from name-word ~a" i nw)))

(deftrace :found-named-obj-with-name (name object)
  ;; called from find/named-object-with-name
  (when *trace-pnf*
    (trace-msg "PNF: Found ~a~
              ~%    for namd ~a" object name)))

(deftrace :did-not-find-named-object-for-name (name)
  ;; called from find/named-object-with-name
  (when *trace-pnf*
    (trace-msg "PNF: Did not find a named object for ~a"  name)))

(deftrace :made-named-object-with-name (i name)
  ;; called from make/named-object-with-name
  (when *trace-pnf*
    (trace-msg "PNF: made the named object ~a~
              ~%    from name ~a" i name)))

(deftrace :make-uncategorized-name (name sequence)
  ;; called from make/uncategorized-name
  (when (or *trace-pnf* *pnf-creation*)
    (trace-msg "PNF: make the uncategorized-named ~a~
              ~%    from the sequence ~a" name sequence)))

(deftrace :found-uncategoried-name (name sequence)
  ;; called from find/uncategorized-name
  (when (or *trace-pnf* *pnf-creation*)
    (trace-msg "PNF: found the uncategorized-name ~a~
              ~%    given the sequence ~a" name sequence)))

(deftrace :no-uncategorized-name-for (sequence)
  ;; called from find/uncategorized-name
  (when *trace-pnf*
    (trace-msg "PNF: no uncategorized-name for the sequence~
             ~%     ~a" sequence)))

(deftrace :no-sequence-for-nws (list-of-name-words)
  ;; called from find/uncategorized-name
  (when *trace-pnf*
    (trace-msg "PNF: no sequence fits the name-words~
             ~%     ~a" list-of-name-words)))


(deftrace :interpreting-name-as-person (name)
  ;; called from interpret-name-as-person
  (when (or *trace-pnf* *pnf-creation*)
    (trace-msg "Interpreting this name as a person:~
              ~%    ~a" name)))



(deftrace :establish-pn-referent (category name)
  ;; called from establish-referent-of-pn
  (when *trace-pnf*
    (trace-msg "PNF: Find-or-make referent of the ~a~
              ~%     ~a" category name)))

(deftrace :found-existing-referent-for-pn (existing-referent)
  ;; called from establish-referent-of-pn
  (when (or *trace-pnf* *pnf-creation*)
    (trace-msg "PNF:  found ~a" existing-referent)))

(deftrace :no-existing-referent-for-pn ()
  ;; called from establish-referent-of-pn
  (when *trace-pnf*
    (trace-msg "PNF: no referent found. Making one.")))


(deftrace :made-person-with-name (person name)
  ;; called from make/person-with-name
  (when (or *trace-pnf* *pnf-creation*)
    (trace-msg "PNF: made the person ~a~
              ~%    from the name ~a" person name)))

(deftrace :looking-for-person-with-name (name)
  ;; called from fine/person-with-name
  (when *trace-pnf*
    (trace-msg "PNF: looking for a person with the name ~a"
               name)))

(deftrace :found-person-with-name (person)
  ;; called from fine/person-with-name
  (when *trace-pnf*
    (trace-msg "   found ~a" person)))

(deftrace :did-not-find-person-with-name ()
  ;; called from fine/person-with-name
  (when *trace-pnf*
    (trace-msg "   no person with that name")))
  


;;------- goes with original network version of PNF
;;;--------------------------------------
;;; exhaustive trace of the PNF routines
;;;--------------------------------------

(defparameter *trace-pnf-network* nil)

(defun trace-pnf-network ()  ;; for meta-point
  (setq *trace-pnf-network* t))

(defun untrace-pnf-network ()
  (setq *trace-pnf-network* nil))


(deftrace :cap-seq-continues-from-here? (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Cap-seq-continues-from-here? p~A"
               (pos-token-index p))))

(deftrace :checkout-continuation-for-non-punctuation (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Checkout-continuation-for-non-punctuation p~A"
               (pos-token-index p))))

(deftrace :boundary-continuation (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Boundary-continuation p~A"
               (pos-token-index p))))

(deftrace :non-boundary-continuation (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Non-boundary-continuation p~A"
               (pos-token-index p))))

(deftrace :non-boundary-continuation/bracket-checked (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Non-boundary-continuation/bracket-checked p~A"
               (pos-token-index p))))

(deftrace :checkout-punctuation-for-capseq (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Checkout-punctuation-for-capseq p~A"
               (pos-token-index p))))


(deftrace :look-ahead-for-initial (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Look-ahead-for-initial p~A"
               (pos-token-index p))))

(deftrace :check-for-initial-before-position (p)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Check-for-initial-before-position p~A"
               (pos-token-index p))))

(deftrace :examine-capitalized-sequence (start-pos end-pos)
  (when *trace-pnf-network*
    (trace-msg "[PNF network] Examine-capitalized-sequence - p~A to p~A"
               (pos-token-index start-pos)
               (pos-token-index end-pos))))


;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1992-2005,2010-2021 David D. McDonald  -- all rights reserved
;;; extensions copyright (c) 2008-2009 BBNT Solutions LLC. All Rights Reserved
;;;
;;;     File:  "morphology"
;;;   Module:  "grammar;rules:tree-families:"
;;;  version:  September 2021

;; initiated 8/31/92 v2.3, fleshing out verb rules 10/12
;; 0.1 (11/2) fixed how lists of rules formed with synonyms
;; 0.2 (5/25/93) added a parameter to the drivers to distinguish categories
;;      from referents to accomodate the case of rules specific to individuals
;;      and added rule for "y -> ies" plurals
;; 0.2 (6/6) added rule in ed and ing forms to drop final "e"
;; 0.3 (6/10) put in plurals for polywords
;; 0.4 (6/18) added ].verb brackets to the verbs
;; 0.5 (10/22) tweeked common-noun to not pluralize punctuation
;; 0.6 (10/25) modified verbs and common nouns to accept specialized morphology
;; 0.7 (5/26) added 'deictic time words' and adverbs
;; 0.8 (6/7) collected all the verb bracket assignment into one routine
;;     (7/12) piggybacked on that to define Verb?
;; 0.9 (10/19) switched from 'deictic-time' to 'standalong-word'
;;     (12/1) added some predicates.  1/9 added Word-stem as :ls-stem
;;     (1/23) added Adverb?
;; 0.10 (4/14) finished known cases of Form-stem/strip-ed. 4/19 fixed missing
;;       case in ed-form-of-word for "join" -> "joinned" bug.
;;      (5/14) fixed weak dispatch in Make-verb-rules
;;      (6/13) added plural-head?
;; 0.11 (12/8) added an override to Make-rules-for-word-w/o-morph to take its rule
;;       category from the 'instantiates' of the category if they're different.
;;       12/11 did it to common-noun as well. 12/12 Backed out of the w/o-morph
;;       version because it clobbered pronouns becase they depended on the specificity
;; 0.12 (1/2/96) added string-to-word conversions to Make-verb-rules/aux2
;; 0.13 (1/16) blocked the 'subtype' in Make-cn-rules/aux
;;      (7/22) added a check in Make-rules-for-word-w/o-morph for the case of the
;;       'word' coming in as a string rather than a word. The real problem is almost
;;       certainly with the caller though.  (8/4) found the real problem and fixed it.
;; 0.14 (5/5/98) added a binding of *schema-being-instantiated* to Make-verb-rules/aux2.
;; 1.0  (10/10/99) Started adding references to schematic-rules when the concrete
;;       rules are created. Moved the dispatch into here from driver1.
;;      (11/25) Modified standalone-word to use a schematic format. (11/26) added the
;;       rest except for verbs since I'm pretty sure I don't remember all the
;;       context that went into their design. 
;;       Also left out common nouns because didn't want to do the proper design
;;       for plurals quite yet. (12/26) put schema reference into Make-cn-rules/aux
;;       so kinds would at least turn over if not have subtypes with open variables for
;;       the plurals.
;; 1.1  (3/18/00) Turned on the plural subtyping in Make-cn-rules/aux
;;      (7/11/00) Added quantifier
;; 1.2  (1/2/01) revised the plural subtyping in Make-cn-rules/aux to be simple.
;;      (2/18) fixed a typo in it.
;; 1.3  (3/31/05) Modified the call that makes the nominalized form of the verb in
;;       Make-verb-rules/aux2 to allow for it having the same pname as another case.
;;       If we didn't we wouldn't get the nominalized rule.
;;      (4/23/08) Added assign-brackets-as-a-common-noun for Make-cn-rules/aux.
;;      (4/14/09) Added *valid-keywords-for-irregular-word-forms*
;;      (7/23/09) Added interjection.
;; 1.4 (9/1/09) Modified plural rule for common nouns to just go to its referent rather
;;      than form a subtype of the referent. We're not doing subtypes right now, but it
;;      needs to be generalized when getting "external" referents as in the link to
;;      Poirot. Modified plural-version of common nouns to just as "s" to words ending
;;      in "y" when they satisfy one-syllable? -- "days". (9/6) Fixed the brackets on
;;      standalone-word.
;; 1.5 (10/13/09) Modified the w/o-morph case to not laydown any brackets and added
;;      explicit set (with brackets) for adjectives.
;; 1.6 (11/4/10) Earlier in October added vast amount to the stemming capabilities.
;;      Today resurecting define-main-verb entry point from 1993 JV work.
;; 1.7 (3/14/11) Decided I wanted more rope for hanging myself and decided that
;;      the :instantiates field of a category (which the ancient doc says, and it's
;;      true the last time I looked, governs the category an individual is indexed
;;      under in the discourse history) should now also govern the lhs of the
;;      rewrite rules. 7/11/11 Spruced up define-main-verb a bit. 7/12 fixed ing-
;;      form-of-verb for cases like "wait" or "gain".
;;      7/31 Added 'category' keyword to define-main-verb so can be used by primed verbs
;; 1.8 (8/1/11) Refactoring a bit so can operate on strings when priming a background
;;      lexicon. 8/2 added the code for recording inflections/lemmas.
;; 1.9 (9/6/11) Rationalized the 'rope' to split discourse history effects from
;;      lhs labeling with the function override-label, which originates in a new
;;      field, :rule-label, on categories. 
;; 1.10 (9/13/11) modified assign-brackets-as-a-common-noun to leave off the
;;      np]. bracket.  4/2/12 #ignored noun/verb-ambiguous?  11/25/12 1st case of
;;      lists of strings in the irregulars past in to define-main-verb. 12/3/12
;;      fixing bugs in the first treatment.
;; 1.11 (12/4/12) Moved out all the assignments to rules/brackets/assignments.
;;      (9/7/13) Put what may be a hack int make-cn-rules/aux to notice that a
;;       special case plural is still a string and not a word. 
;; 1.12 (11/27/13) Modified it further to factor out the plural creator and
;;       allow it to be blocked. (6/9/14) Added check-for-correct-irregular-word-markers
;; 1.13 (8/12/14) Reorganized make-cn-rules/aux so overriding plurals wouldn't
;;       block returning the singular rule.
;;      (9/15/14) fixed design flaw in stem-form that insisted that the stem be
;;       in Comlex before it trusted the stem that is constructed.
;;      (12/10/14) Added a check in creation of plurals that the category 'collection'
;;       is aleady defined. 
;;      (1/6/15) Fixed over-zealous application of irregulars check that was
;;       blocking simple case of multiple words with the same definition.
;;      (6/19/15) Rebuilt plural-version/pw because it was duplicating the 1st word
;; 8/16/16 Refactored as generic make-rules-for-head.

(in-package :sparser)

;;;----------
;;; dispatch
;;;----------

(defgeneric make-rules-for-head (pos word category referent &rest special-cases)
  (:documentation "Construct rules for a single word, multiple words,
 or a word with morphological special cases, e.g., :plural, :past-tense, etc.
   May be invoked on explicit words in the realization fields of categories
 (e.g. table has :realization (:common-noun table)) in which case the referent
 with be the category itself (see make-rules-for-rdata), or it may be invoked
 on individuals who are substituting a word they supply for a variable in the
 rdata (e.g. block has :realization (:proper-noun name), instances of block supply
 the word to use as the name) in which case the referent is the individual.
   This block of methods handles the general dispatch and generic cases.
 Irregulars are handled by methods for the particular part of speech cases
 that understand them.")
  (:argument-precedence-order word pos category referent)
  
  (:method (pos (rdata realization-data) category referent &rest special-cases)
    "An adapter method from the new realization-data records to the old lists."
    (declare (optimize debug))
    (check-type special-cases null)
    (case pos
      ((t) (loop for (pos head) on (rdata-head-words rdata) by #'cddr
                 append (make-rules-for-head pos head category referent)))
      (t (make-rules-for-head pos (getf (rdata-head-words rdata) pos) category referent))))
  
  (:method ((pos (eql t)) (word cons) category referent &rest special-cases)
    "Handle a generic head-word specification list, e.g., (:verb ...).
     At this stage the 'word' is a list. We pull off the pos keyword and head word
     (car & cadr), package the remainder of the list (cddr) as 'special-cases'
     for the next method to handle"
    (check-type (car word) keyword)
    (check-type (cadr word) (or list word polyword lambda-variable))
    (check-irregular-word-markers (cddr word))
    (check-type special-cases null)
    (apply #'make-rules-for-head (car word) (cadr word) category referent
           (cddr word)))
  
  (:method (pos (word list) category referent &rest special-cases)
    "Handle either a single word with special cases or a list of them."
    (declare (ignore special-cases))
    (typecase word
      ((cons (or word polyword) (cons keyword *))
       (apply #'make-rules-for-head pos (car word) category referent
              (cdr word)))
      (otherwise
       (loop for w in word
          append (make-rules-for-head pos w category referent)))))
  
  (:method (pos (word lambda-variable) category referent &rest special-cases)
    "Variables as heads refer to bindings in the referent."
    (apply #'make-rules-for-head pos (value-of word referent) category referent
           special-cases))
  
  (:method (pos word category referent &rest special-cases)
    "Default case: construct a single rule for a head word."
    (declare (ignore special-cases))
    (check-type pos keyword)
    (check-type word (or word polyword))
    (list (define-cfr category (list word)
            :referent referent
            :form (form-category pos)
            :schema (get-schematic-word-rule pos))))
  
  (:method :around (pos word (category category) referent &rest special-cases)
    "Allow categories to override the constructed rule labels."
    (apply #'call-next-method
           pos word (or (override-label category) category) referent
           special-cases))
  
  (:method :after (pos word category referent &rest special-cases)
    "Assign brackets and maybe make a Mumble word."
    (declare (ignore referent special-cases))
    (typecase word
      ((or word polyword)
       (assign-brackets-for-word word pos)
       (when *build-mumble-equivalents*
         ;;(lsp-break "After: category = ~a referent = ~a" category referent)
         (if (eq referent category) ;; we're working with a category
           (make-corresponding-mumble-resource word pos category)
           ;; otherwise we're working with an individual
           (make-corresponding-mumble-resource word pos referent)))))))


(deftype irregular-keyword ()
  '(member :plural :prep :phrase
           :nominalization :past-tense
           :present-participle :past-participle
           :third-singular :third-plural))

(defun check-irregular-word-markers (plist)
  (loop for (keyword word) on plist by #'cddr
        do (check-type keyword irregular-keyword "an irregular-marking keyword")
           (check-type word (or string word polyword) "a valid word")))


;;;-------------------------------------------------------
;;; keeping track of lemma / inflected form relationships
;;;-------------------------------------------------------

;; Presently only applies to nouns and verbs, could be expanded to
;; other forms like comparative adjectives or even derivational
;; variants. Somewhat redundant with the bundling created by categories
;; but useful when working with a large latient vocabulary.

(defun record-inflections (inflections lemma type)
  (ecase type
    (:noun (setf (get-tag :noun-inflections lemma) inflections))
    (:verb (setf (get-tag :verb-inflections lemma) inflections))))

(defun record-lemma (inflection lemma type)
  (ecase type
    (:noun (setf (get-tag :inflection-of-noun lemma) inflection))
    (:verb (setf (get-tag :inflection-of-verb lemma) inflection))))

(defun noun-forms-of (w)
  (let ((value (get-tag :noun-inflections w)))
    (when value
      (pushnew w value))))

(defun verb-forms-of (w)
  (let ((value (get-tag :verb-inflections w)))
    (when value
      (pushnew w value))))


;;;-------------
;;; determiners
;;;-------------
 #|  Simpler version in the generic function in rules/syntax/articles.lisp
(defun determiner? (word)
  ;; ///need to revise their definitions in rules:words; so this
  ;; is easier to compute
  (or (let ((module (get-tag :grammar-module word)))
        (when module
          (eq (gmod-symbol module) '*determiners*)))
      (let* ((rs (label-rule-set word))
             (brackets (when rs (rs-phrase-boundary rs)))
             (.[ (when brackets (ba-begins-before brackets))))
        (eq .[ .[np))))
|#

;;;---------
;;; adverbs
;;;---------

(defun adverb? (word)
  (let ((rs (word-rules word)))
    (when rs
      (let ((brackets (rs-phrase-boundary rs)))
        (when brackets
          (eq (ba-ends-before brackets)
              (find-bracket :end :before 'adverb)))))))


(defun adverbial-morphology? (word)
  (eq (word-morphology word)
      :ends-in-ly ))


;;;-------
;;; verbs
;;;-------

(defun verb? (word)
  (let ((rs (rule-set-for word)))
    (when rs
      (let ((brackets (rs-phrase-boundary rs)))
        (when brackets
          (eq (ba-ends-after brackets)
              (find-bracket :end :after 'mvb)))))))

#+ignore
(defun noun/verb-ambiguous? (word) ;; verb/noun-category-name undefined
  (let ((ambiguity (get-tag :dis-multiple-pos word)))
    (when ambiguity
      (and (member (verb-category-name) ambiguity)
           (member (noun-category-name) ambiguity)))))


(defun verbal-form? (edge)
  ;; a useful predicate when doing dm&p explorations
  (member (edge-form edge)
          (list category::verb
                category::verb+ed
                category::verb+s
                category::verb+ing
                category::infinitive
                category::verb+present
                category::verb+passive )
          :test #'eq ))


(defun verb-form-corresponding-to-word-morph (word)
  (let ((keyword (word-morphology word)))
    (if keyword
      (ecase keyword
        (:ends-in-s   category::verb+s)
        (:ends-in-ed  category::verb+ed)
        (:ends-in-ing category::verb+ing))
      category::verb )))



(defun define-main-verb (verb &key
                         (category (find-or-make-category verb))
                         (referent (category-named 'perdurant))
                         (infinitive        ;; "to give"
                          (error "Must supply at least the infinitive form."))
                         tensed/singular    ;; "he gives"
                         tensed/plural      ;; "they give"
                         past-tense         ;; "they gave"
                         past-participle    ;; "they have given"
                         present-participle ;; "they are giving"
                         prep  phrase
                         nominalization)
  "Standalone entry point developed in the early 1990s. Can be very lightweight
because the referent can be trivial. Provides overrides to make-verb-rules."
  (add-rules (make-rules-for-head :verb (define-word/expr infinitive)
                                  category referent
                                  :nominalization nominalization
                                  :prep prep
                                  :phrase phrase
                                  :present-participle present-participle
                                  :past-participle past-participle
                                  :past-tense past-tense
                                  :third-singular tensed/singular
                                  :third-plural (or tensed/plural infinitive))
             category))

(defmethod make-rules-for-head ((pos (eql :verb)) word category referent
                                &key
                                  nominalization
                                  prep  phrase
                                  past-tense past-participle present-participle
                                  third-singular third-plural
                                  (s-form third-singular)
                                  (ed-form past-tense)
                                  (ing-form present-participle)
                                  &aux verb-already-done )
  "Define rules for a verb and its various inflections."
  (if s-form
    (make-irreg-mword word :verb :third-singular s-form)
    (setq s-form (s-form-of-verb word)))
  (if ed-form
    (make-irreg-mword word :verb :past-tense ed-form)
    (setq ed-form (ed-form-of-verb word)))
  (if ing-form
    (make-irreg-mword word :verb :present-participle ing-form)
    (setq ing-form (ing-form-of-verb word)))
  (let ( inflections )
    (labels ((convert-if-needed (raw)
               (etypecase raw
                 ((or word polyword) raw)
                 (string (resolve/make raw))
                 (list (mapcar #'convert-if-needed raw))))
             (update-inflections (result)
               (etypecase result
                 ((or word polyword) (push result inflections))
                 (list (setq inflections (append-new result inflections))))))
      (when s-form
        (update-inflections (setq s-form (convert-if-needed s-form))))
      (when ed-form
        (update-inflections (setq ed-form (convert-if-needed ed-form))))
      (when ing-form
        (update-inflections (setq ing-form (convert-if-needed ing-form))))
      (when past-tense
        (update-inflections (setq past-tense (convert-if-needed past-tense))))
      (when past-participle
        (update-inflections (setq past-participle (convert-if-needed past-participle))))
      (when present-participle
        (update-inflections (setq present-participle (convert-if-needed present-participle))))
      (when third-singular
        (update-inflections (setq third-singular (convert-if-needed third-singular))))
      (when third-plural
        (update-inflections (setq third-plural (convert-if-needed third-plural))))
      (when nominalization
        (setq nominalization (convert-if-needed nominalization)))

      (assign-brackets-as-a-main-verb word) ;; infinitive or 3d plural
      (record-inflections inflections word :verb)
      (dolist (w inflections)
        (assign-brackets-as-a-main-verb w)
        (record-lemma w word :verb)) ;; record-lemma (inflection lemma type)
      (when nominalization
        ;; Makes rules and a category as well.
        (assign-brackets-as-a-common-noun nominalization))

    ;; make the rules
    (when (and category referent)
      (let* ((*schema-being-instantiated* word)
             rules  )
        (labels ((make-rule (word form)
                   (let ((rule (define-cfr category (list word)
                                 :form form
                                 :referent referent
                                 :schema (get-schematic-word-rule pos))))
                     (push rule rules)))
                 (rule-macro (word/s form)
                   (if (consp word/s)
                     (loop for word in word/s do
                       (make-rule word form))
                   (make-rule word/s form))))
          
          ;; infinitive, 1st, 2d, 3d person plural
          (rule-macro word category::verb)

          ;; 3rd person singular
          (if third-singular
            (rule-macro third-singular category::verb+present)
            (when s-form
              (rule-macro s-form category::verb+present)))
          
          ;; past tense, past participle          
          (when past-tense
            (rule-macro past-tense category::verb+ed))
          (when past-participle
            (rule-macro past-participle category::verb+ed))
          (unless past-tense
            (rule-macro ed-form category::verb+ed))
               
          ;; present participle
          (if present-participle
            (rule-macro present-participle category::verb+ing)
            (when ing-form
              (rule-macro ing-form category::verb+ing)))

          (when third-plural
            (rule-macro third-plural category::verb+present))

          (when past-participle
            (rule-macro past-participle category::verb+ed)) 

          (when prep
            (setup-bound-preposition word prep category))

          (when phrase
            (setup-phrasal-verb word phrase category))

          (nreverse rules)))))))


;;;--------------------
;;; stripping suffixes
;;;--------------------

;; These are too hard to write rules for so that they don't strip,
;; or that are quite irregular or too short to get a multi-case
;; suffix from
(defparameter *do-not-stem*
  '(
    "alias"
    "atlas"
    "beings"
    "booking"
    "christmas"
    "corps"
    "mars"
    "mumps"
    "perhaps"
    "seasoning"
    "standings"
    "string"
    "tens"
    "thanks"
    "underling"
    ))


(defun word-stem (word)
  (get-tag :stem word))

(defgeneric stem-form (word)
  (:documentation "Lookup the morphological properties of the word
    and use them to remove the suffix and attempt to recover the
    appropriate lemma")
  (:method ((s symbol))
    (stem-form (symbol-name s)))
  (:method  ((s string))
    (cond ((> (length s) 100)
           ;; we got a very long (incorrect) word which caused an break
           ;; this is a patch to avoid that break
           s)
          ((member s *do-not-stem* :test #'string-equal)
           s)
          ((< (length s) 3) ;; "fed" -- maybe < 4 ?
           s)
          (t (let ((word (resolve/make s)))
               (stem-form word)))))
  (:method ((word word))
    ;; Redundant with stem-form-of-verb but adds more cases and
    ;; does a Comlex check. Stores the stem once it finds it.
    (or (word-stem word)
        (let ((morphology (word-morphology word)))
          ;; the word-morphology field of a word is filled at the
          ;; time it is defined. 
          (if morphology
            (let* ((putative-stem (construct-stem-form word morphology))
                   ;; If Comlex says the reduced form is in its ~50k
                   ;; word dictionary then we accept it as the lemma
                   ;; form of the word and store it as the stem
                   (attested-stem (when putative-stem
                                    (test-against-comlex putative-stem morphology))))
              (let ((stem
                     ;; Some words are not in Comlex, especially in biology,
                     ;; in these cases we'll take the stem that we construct.
                     (or attested-stem
                         putative-stem)))
                (if stem
                  (setf (get-tag :stem word) stem)
                  word)))
            ;; without morphology information we can't stem
            word)))))

(defun stem-form-of-verb (word)
  ;; Called from older code: mine-as-a-verb in dmp;mine-terms,
  ;; and the dialog in interface/grammar/defining-verbs.
  (let ((morphology (word-morphology word)))
    (if morphology ;;/// mistakenly stems "this",
      ;; and "species" => "specy", "during" => "dur"
      (construct-stem-form word morphology)
      word)))

;;--- cases

(defun construct-stem-form (word morphology)
  ;; subroutine of stem-form and stem-form-of-word
  (typecase morphology
    (symbol
     (case morphology
       (:ends-in-s (form-stem/strip-s word))
       (:ends-in-ed (form-stem/strip-ed word))
       (:ends-in-ing (form-stem/strip-ing word))
       (:ends-in-ly (form-stem/strip-ly word))
       (otherwise
        (push-debug `(,word ,morphology))
        (break "Unexpected morphology keyword ~a~%on ~a"
               morphology word))))
    (cons
     ;; e.g. ("ible" ADJ)
     (let ((suffix (first morphology)))
       (cond
        ((string= suffix "ed")
         (form-stem/strip-ed word))
        ((string= suffix "ing")
         (form-stem/strip-ing word))
        (t ;;(push-debug `(,word ,morphology))
         ;;  To judge from a large sample, these are already in stem form.
         ;;    There's nothing to remove from them
         ;;(warn "Unexpected morphology keyword ~a~%on ~a" morphology word)
         word))))
    (otherwise
     (push-debug `(,word ,morphology))
     (error "Unexpected type of morph keyword: ~a~%~a"
            (type-of morphology) morphology))))


(defun test-against-comlex (putative-stem morphology)
  (declare (ignore morphology)
           (special *comlex-word-lists-loaded*)) ;; if we want more educated extensions
  (if (and
       (boundp '*comlex-word-lists-loaded*)
       *comlex-word-lists-loaded*) ;; do (load-comlex)
    (or (and (is-in-comlex? putative-stem)
	     putative-stem)
        ;; If this form isn't in Comlex, maybe a small variant
        ;; of it is -- adding something back to the reduced
        ;; form and rechecking. Otherwise it returns nil, indicating
        ;; either that the word really isn't in Comlex
        ;; (so we don't know whether we have a lemma form or
        ;; not), or we need to extend this. 
	(let ((pname-with-an-e (pname-with-an-e putative-stem)))
	  (when (is-in-comlex? pname-with-an-e)
	    (define-word/expr pname-with-an-e)))
	(let ((pname-with-a-d (pname-with-a-d putative-stem)))
	  (when (is-in-comlex? pname-with-a-d)
	    (define-word/expr pname-with-a-d))))
    putative-stem))

(defun pname-with-an-e (stem)
  (if (word-ends-in-e stem)
    stem
    (concatenate 'string (word-pname stem) "e")))
;; Should try to avoid these patches
(defun pname-with-a-d (stem)
  (if (word-ends-in-e stem)
    stem
    (concatenate 'string (word-pname stem) "d")))
      

;;--- A start at some abstractions

(defmethod last-letter ((w word))
  (last-letter (word-pname w)))
(defmethod last-letter ((s string))
  (elt s (1- (length s))))

(defun ends-in? (string suffix-string)
  (let ((string-length (length string))
	(suffix-length (length suffix-string)))
    (string-equal suffix-string
		  (subseq string (- string-length suffix-length)))))

(defmethod word-ends-in-e ((w word))
  (word-ends-in-e (word-pname w)))
(defmethod word-ends-in-e ((s string))
  (eql #\e (last-letter s)))

(defmethod word-ends-in-d ((w word))
  (word-ends-in-d (word-pname w)))
(defmethod word-ends-in-d ((s string))
  (eql #\d (last-letter s)))

(defmethod word-ends-in-s ((w word))
  (word-ends-in-s (word-pname w)))
(defmethod word-ends-in-s ((s string))
  (eql #\s (last-letter s)))




(defgeneric form-stem/strip-s (word)
  ;; the word ends in 's'
  (:method ((w word))
    (let ((stem (form-stem/strip-s (word-pname w))))

      (resolve/make stem)))
  (:method ((pname string))
    (let* ((length (length pname))
           (stem-pname (subseq pname 0 (1- length)))
           (char-before (elt pname (- length 2))))          
      (cond
        #+ignore((< (length stem-pname) 3) ;/// collect these
         pname)
        ((ends-in? pname "ies")
         (concatenate 'string (subseq pname 0 (- length 3)) "y"))
        ((or (ends-in? pname "es") ; "roaches"
             (ends-in? pname "us") ; "cactus" "status" "alumnus"
             (ends-in? pname "is")) ; "oasis" "crisis"
         (subseq pname 0 (- length 2)))
        ((or (ends-in? pname "ass") ; "amass" "pass"
             (ends-in? pname "ess") ; "access" "dress" "address" "impress"
             (ends-in? pname "iss") ; "dismiss" "miss"
             (ends-in? pname "ness") ; "witness"
             (ends-in? pname "oss") ; "toss"
             (ends-in? pname "uss")) ; "fuss"
         pname)
        (t ;; (break "Fell through pname: ~s  stem: ~s" pname stem-pname)
         stem-pname)))))

;(form-stem/strip-s (define-word "flies"))
;(form-stem/strip-s (define-word "describes"))


(defgeneric form-stem/strip-ed (word) 
  (:documentation "Remove the ending, return the stemmed word")
  (:method ((w word))
    (let ((stem (form-stem/strip-ed (word-pname w))))
      (resolve/make stem)))
  (:method ((pname string))
    (declare (special *primed-words*))
    (let ((length (length pname)))
      (if (< length 5)
        (form-stem/strip-ed/short-word pname length)

        (let ((char-minus-1 (elt pname (- length 3)))
              (char-minus-2 (elt pname (- length 4)))
              (char-minus-3 (elt pname (- length 5))))
          (cond
            ((doubled-consonants? char-minus-1 char-minus-2)
             ;; "..cced" -> "..c"
             (cond ((gethash (subseq pname 0 (- length 3)) *primed-words*)
                    (subseq pname 0 (- length 3)))
                   ((gethash (subseq pname 0 (- length 2)) *primed-words*)
                    (subseq pname 0 (- length 2)))
                   (t pname))) ;/// or break?

            ((and (consonant? char-minus-1)
                  (not (eql char-minus-1 #\x))
                  (not (and (or (eql char-minus-1 #\r)  ;; wondered
                                (eql char-minus-1 #\n)) ;; weakened
                            (eql char-minus-2 #\e)))
                  (vowel? char-minus-2)        ;; "named" => "name"
                  (not (vowel? char-minus-3))) ;; "coiled" => "coil"
             ;; "..vced" -> "..vce"
             ;; use COMLEX info to distinguish is cases of short vowel sounds like "visited"
             (cond ((gethash (subseq pname 0 (- length 1)) *primed-words*)
                    (subseq pname 0 (- length 1)))
                   ((gethash (subseq pname 0 (- length 2)) *primed-words*) ;; e.g. "visited"
                    (subseq pname 0 (- length 2)))
                   (t (subseq pname 0 (- length 1)))))

            ((eql #\i char-minus-1)
             ;; "..ied"  -> "..y"
             (concatenate 'string (subseq pname 0 (- length 3)) "y"))

            ((and (semi-vowel? char-minus-1)
                  (consonant? char-minus-2))
             ;; "..csed" -> "..cse"  where 's' is a semi-vowel: "l" "r"
             ;;    e.g. "riddled with grief"
             (subseq pname 0 (- length 1)))

            ((ends-in? pname "eed") ; "bleed" "speed"
             pname)

            (t ;;(break "~s fell through" pname)
             (subseq pname 0 (- length 2)))))))))
#|
 (test-stemmer "coiled") -> "coil"
 (form-stem/strip-ed "coiled") -> "coil"

//// (form-stem/strip-ed "called") --> "call"

 (form-stem/strip-ed "expected") ;; default
 (form-stem/strip-ed "named")    ;; "..vced" -> "..vce"
 (form-stem/strip-ed "riddled")  ;; "..csed" -> "..cse"  where 's' is a semi-vowel
 (form-stem/strip-ed "cried")    ;; "..ied"  -> "..y"
|#

(defun form-stem/strip-ed/short-word (stem-pname length)
  ;; 'short' is less than 5 characters
  ;; I haven't got any examples yet.
  (declare (ignore length))
  (define-word/expr stem-pname))


(defgeneric form-stem/strip-ing (word)
  (:method ((w word))
    (let ((stem (form-stem/strip-ing (word-pname w))))
      (resolve/make stem)))
  (:method ((pname string))
    (let ((length (length pname)))
      (if (< length 6)
        (then ; "bring" "being"
          pname)
        (let ((stem-pname (subseq pname 0 (- length 3))) ;; remove "ing"
              (char-before (elt pname (- length 4))))
          (cond
            ((ends-in? stem-pname "bl") ;; "assemble
             (string-append stem-pname "e"))
            ((and (doubled-consonants? char-before (elt pname (- length 5)))
                  (> (length stem-pname) 3)) ;; "cell" "add"
             (subseq pname 0 (- length 4)))
            (t stem-pname)))))))

; (form-stem/strip-ing "setting") -- "set"
; (form-stem/strip-ing "assembling") -- "assemble"


(defun form-stem/strip-ly (word)
  ;; It's not obvious that we should do this since we'll be changing
  ;; part of speech from an adverb to (most of the time) an adjective.
  ;; This is a placeholder. 
  word)


;;--- test harness

(defun test-stemmer (pname)
  (let ((word (word-named pname)))
    (if word
      (remove-tag :stem word)
      (setq word (define-word/expr pname)))
    (stem-form word)))






;;;---------------------------------
;;; character examining subroutines
;;;---------------------------------

(defparameter *vowels* (list #\a #\e #\i #\o #\u #\y))

(defparameter *stop-consonants* (list #\p #\t #\k ; voiceless
                                      #\b #\d #\g) ; voiced
  "Forming past tense we can double last consonant if it's a stop")

(defun semi-vowel? (character)
  (or (eql character #\l)
      (eql character #\r)))

(defun consonant? (character)
  (when (stringp character)
    (setq character (elt character 0)))
  (not (member character *vowels* :test #'eql)))

(defun vowel? (character)
  (when (stringp character)
      (setq character (elt character 0)))
  (member character *vowels* :test #'eql))


(defun doubled-consonants? (c1 c2)
  (when (eql c1 c2)
    (unless (member c1 *vowels* :test #'eql)
      ;; this gets digits and punctuation too, but it works
      t)))

(defun one-syllable? (pname)
  ;; a c/v analysis would be best 
  (= 1 (count-vowels pname)))

(defun count-vowels (pname)
  "Basic question is how many CV's are there as a sort of
   syllable count. //could observe more features in the 
   process, like doubled vowels, vowel initial ..."
  (let ((count 0))
    (loop for i from 0 to (1- (length pname))
       as c = (aref pname i)
       when (vowel? c) do (incf count))
    count))
         

(defun stem-with-final-consonant/s-stripped (pname)
  (if (= (length pname) 0)
      nil
      (if (consonant? (elt pname (1- (length pname))))
        (stem-with-final-consonant/s-stripped
         (subseq pname 0 (1- (length pname))))
        pname )))

(defun v-of-final-vc-is-two-vowels? (pname)
  "e.g. 'join', used to stop the doubling of the final consonant
   in ed-form-of-verb"
  (let ((reduced-stem (stem-with-final-consonant/s-stripped pname)))
    (when reduced-stem
      ;; If there was any vowel in this pname then the reduction
      ;; will return a string
      (when (> (length reduced-stem) 1) ;; e.g. pname = "in"
        (vowel? (elt reduced-stem (1- (length reduced-stem))))))))

   
(defun no-morph-on-short-words (word)
  ;; called from assign-morph-brackets-to-unknown-word where
  ;; it feeds a setq of morph-keyword with either the original
  ;; or nil if the word sould be stemmed and the morphology
  ;; it has cannot be trusted to provide part-of-speech 
  ;; information: "bed", "sing", "this".
  (unless (one-syllable? (word-pname word))
    (word-morphology word)))

;;;-----------------
;;; adding suffixes
;;;-----------------

(defgeneric s-form-of-verb (base)
  (:documentation "comlex-util uses the plural noun routine to generate
    this form, so since the original version here just
    added #\s why not try it.")
  (:method ((base word))
    (let* ((s-form-pname (s-form-of-verb (word-pname base)))
           (word (resolve/make s-form-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))
  (:method ((base polyword))
    (let* ((s-form-pname (s-form-of-verb (pw-pname base)))
           (word (resolve/make s-form-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))
  (:method ((pname string))
    (plural-version pname)))


(defparameter *words-not-doubling-past*
  '("cancel" "travel"))

(defgeneric ed-form-of-verb (base)
  (:documentation "We double the final consonant when (a) the word has
    more than one syllable, and (b) the final syllable is stressed.
    Stress isn't a property of text, to we have to fake it by looking
    at patterns of characters that could carry stress, like the stop consonants.
    Other heuristics: A one-syllable word ending in cvc ('stop -> stopped'),
    exceptions: 'travel', 'cancel' don't double.
    Not if word ends in two consonants ('start', 'burn').
    Not if there are there are two vowels before the final letter ('remain')
    Never if the final consonant is #\w.
    If the base ends in #\y, change it to #\i when the #\y is preceded by a consonant.
    https://speakspeak.com/resources/english-grammar-rules/english-spelling-rules/ ")
  
  (:method ((word word))
    "Feeder methods call the pname method to get the correct form
     then then they create the word to be returned"
    (let* ((ed-pname (ed-form-of-verb (word-pname word)))
           (word (resolve/make ed-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))
  
  (:method ((word polyword))
    (let* ((ed-pname (ed-form-of-verb (pw-pname word)))
           (word (resolve/make ed-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))

  (:method ((pname string))
    "Initially adapted version from verb-past in comlex-util with the consonant
     doubling heuristic they cite."
    (let ((length (length pname)))
      (if (= length 2) ; "ax' -- during prime-comlex
        (string-append pname "ed")
        (let ((lastchar (aref pname (- length 1)))
              (last2char (aref pname (- length 2)))
              (last3char (aref pname (- length 3))))
          ;;(format t "~c ~c ~c" last3char last2char lastchar)
          (cond
            ((and (vowel? last2char)
                  (vowel? last3char))
             (string-append pname "ed"))

            ((eql lastchar #\y)
             (if (vowel? last2char) ; "delay" -> "delayed"
               (string-append pname "ed")
               (let ((minus-y (subseq pname 0 (- length 1))))
                 (string-append minus-y "ied")))) ; "query" -> "queried"

            ((eql lastchar #\w)
             (string-append pname "ed"))
            
            ((eql lastchar #\e)
             (concatenate 'string pname "d"))

            ((and (consonant? lastchar)
                  (consonant? last2char))
             (string-append pname "ed"))

            ((eql lastchar #\x)
             (string-append pname "ed"))

            ((member pname *words-not-doubling-past* :test #'string-equal)
             (string-append pname "ed"))

            ((and (consonant? last3char)
                  (vowel? last2char)
                  (consonant? lastchar))
             ;; double the last character
             (string-append pname lastchar "ed"))

            (t (string-append pname "ed"))))))))

#|
 (ed-form-of-verb "travel") -- "traveled"
 (ed-form-of-verb "amplify") -- "amplified"
 (ed-form-of-verb "query") -- "queried"
"purified" and "identified"
 (ed-form-of-verb "bat")  -- "batted"
 (ed-form-of-verb "call") -- "called"
 (ed-form-of-verb "join")  -- "joined"
 (ed-form-of-verb "stop")  -- "stopped"
 (ed-form-of-verb "follow") -- "followed"
|#



;;--- ing

(defgeneric ing-form-of-verb (word)
  (:method ((word word))
    (let* ((ing-pname (ing-form-of-verb (word-pname word)))
           (word (resolve/make ing-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))
  
  (:method ((word polyword))
    (let* ((ing-pname (ing-form-of-verb (pw-pname word)))
           (word (resolve/make ing-pname)))
      (assign-brackets-as-a-main-verb word)
      word ))

  (:method ((pname string))
    (let* ((length (length pname))
           (last-letter (elt pname (1- length)))
           (2d-to-last (elt pname (- length 2)))
           (3d-to-last (when (>= length 3) ;; "ax"
                         (elt pname (- length 3))))
           (ends-in-a-consonant? (consonant? last-letter))
           (number-of-vowels (count-vowels pname))
           (double nil))
      ;; http://dictionary.cambridge.org/us/grammar/british-grammar/spelling

      ;; list the reason not to double and by default
      ;; we'll double a final consonant. 
      (cond
        ((eql #\e last-letter)
         (setq pname (subseq pname 0 (1- (length pname))))
         ;; "ie" => "ying
         (when (eql 2d-to-last #\i)
           (setq pname (string-append
                        (subseq pname 0 (1- (length pname))) ;; need to remove the "i" too
                        "y"))))
        
        ((eql #\w last-letter)) ;; "snow"
        ((eql #\x last-letter)) ;; "tax"
        ((eql #\y last-letter)) ;; "play"

        (ends-in-a-consonant? ;; something to double
         (cond
           ((= 1 number-of-vowels)
            (cond
              ((vowel? 2d-to-last) "put" "run" "get"
               ;; applies to adding "-er", "-en" "-ish"
               (setq double t))))
           
           ((and (vowel? 2d-to-last) (vowel? 3d-to-last))
            (setq double nil)) ;; "remain" "dream" "need"
           ((consonant? 2d-to-last)
            (setq double nil)) ;; "start" "burn"

           ;; when more that one syllable depends on placement
           ;; of the stress. What resource could provide that?
           (t
            (setq double t)))))
      
      (when double
        (setq pname (string-append pname
                                   last-letter)))
      (string-append pname "ing"))))


;(ing-form-of-verb (define-word "describe"))
;(ing-form-of-verb (define-word "set"))
;(ing-form-of-verb (define-word "look"))


;;;------------
;;; adjectives
;;;------------

(defmethod make-rules-for-head ((pos (eql :adjective)) word category referent &rest special-cases)
  "Define rules for an adjective and possibly its comparative & superlative variants."
  (declare (special *inhibit-constructing-comparatives*))
  (let ((adj-rules (call-next-method)))
    (if (or (punctuation? word)
            (not (word-p word))
            *inhibit-constructing-comparatives*)
      adj-rules
      (append adj-rules
              (make-comparative-rules word category referent)
              (make-superlative-rules word category referent)))))


;;--- comparative/superlative

(defun make-comparative/superlative (word &key (suffix "er") (y-suffix "ier"))
  (declare (type word word)
           (type string suffix y-suffix))
  (let* ((pname (pname word))
         (lastchar (elt pname (- (length pname) 1)))
         (butlastchar (elt pname (- (length pname) 2)))
    ;;/// we should abstract out the criteria for doubling the final
    ;; consonant.
         (derived-pname
          (cond
            ((char= lastchar #\y)
             (string-append (subseq pname 0 (- (length pname) 1)) y-suffix))

            ((and (vowel? lastchar)
                  (vowel? (elt suffix 0)))
             (string-append (subseq pname 0 (- (length pname) 1)) suffix))

            ((and (consonant? lastchar)
                  (vowel? butlastchar)
                  (eql #\w lastchar))
             (string-append pname suffix))
            
            ((and (consonant? lastchar)
                  (vowel? butlastchar))
             (string-append pname (string lastchar) suffix))
            
            (t (string-append pname suffix)))))

    ;; the word might exist, so look before redefining
    (resolve/make derived-pname)))



;;;--------------
;;; common nouns
;;;--------------

(defparameter *inhibit-constructing-plural* nil
  "Intended to be bound by word-constructors when they know that 
   the noun does not make sense in the plural.")

(defmethod make-rules-for-head ((pos (eql :common-noun)) word category referent &rest special-cases)
  "Define rules for a common noun and possibly its plurals."
  (declare (special *inhibit-constructing-plural*))
  (let ((singular-rules (call-next-method)))
    (if (or *inhibit-constructing-plural* (punctuation? word))
      singular-rules
      (append singular-rules
              (apply #'make-cn-plural-rules word category referent
                     special-cases)))))

(defmethod make-rules-for-head ((pos (eql :proper-name))  word category referent &rest special-cases)
  ;; cargo-cult from common-noun case
  (let ((singular-rules (call-next-method)))
    singular-rules))

(defun make-cn-plural-rules (word category referent &key plural)
  (if plural ;; a marked irregular
    (unless (eq plural :none)
      (make-irreg-mword word :noun :plural plural))
    (setq plural (etypecase word
                   (polyword (plural-version/pw word))
                   (word (plural-version word)))))
  (unless (eq plural :none)
    (loop for plural in (ensure-list plural)
       as plural-word = (etypecase plural
                          ((or word polyword) plural)
                          (string (resolve/make plural)))
       collect plural-word into inflections
       collect (make-cn-plural-rule plural-word category referent) into rules
       finally
         (record-inflections inflections word :noun)
         (loop for i in inflections ;; may not be right - needs review
            do (record-lemma i word :noun))
         (return rules))))

(defun make-cn-plural-rule (plural category referent)
  (assign-brackets-as-a-common-noun plural)
  (define-cfr category (list plural)
    :form  category::common-noun/plural
    :schema (get-schematic-word-rule :common-noun)
    :referent (resolve-referent-expression
                `(:head ,referent
                  :subtype ,(category-named 'plural)))))

(defgeneric plural? (i)
  (:documentation "Look for the plural category in the individual's
    type field. Follows design choice in make-cn-plural-rule")
  (:method ((i individual))
    (member (category-named 'plural) (indiv-type i))))


(defun unresolved-plural-referent? (item)
  "We have an unsolved issue with some plurals referents remaining as expressions.
   rather than being resolved. This is to detect that pattern."
  (when (listp item)
    (and (= 2 (length item))
         (eq (car (first item)) :head)
         (eq (car (second item)) :subtype))))

(defgeneric plural-version (word)
  (:documentation "Given the singular version of a noun, construct its plural
   by rule.")
  (:method ((pname string))
    ;; Revised 8/1/11 to draw on Comlex utilties, which says these
    ;; are from the Oxford Advanced Learners Dictionary
    (let ((lastchar (subseq pname (- (length pname) 1)))
          (last2char (subseq pname (max (- (length pname) 2) 0))))
      (cond
        ((or (member lastchar '("s" "z" "x") :test #'string-equal)
             (member last2char '("ch" "sh") :test #'string-equal))
         (string-append pname "es"))
        ((member last2char '("ay" "ey" "iy" "oy" "uy")
                 :test #'string-equal)
         (string-append pname "s"))
        ((string-equal lastchar "y")
         (string-append (subseq pname 0 (- (length pname) 1)) "ies"))
        (t (string-append pname "s")))))
  
  (:method ((w word))
    (let* ((plural-pname (plural-version (word-pname w)))
           (plural (define-word/expr plural-pname)))
      (when (word-p plural) ;; "μ"+ s" -> a polyword
        (unless (word-morphology plural)
          (setf (word-morphology plural) :ends-in-s)))
      plural))

  (:method ((pw polyword))
    (plural-version/pw pw)))

(defun plural-version/pw (pw)
  "Form the plural of a polyword. Naieve version that just forms the
   plural of the last word. Doesn't handle irregulars -- 'chairmen',
   and doesn't handle cases where the plurality should be marked on
   an earlier word."
  (declare (special *defining-a-polyword*)) ; don't catalog interior words
  (let* ((words (pw-words pw))
         (last-word (car (last words)))
         (*defining-a-polyword* pw)
         (last-word-plural (plural-version last-word)))
    (let* ((word-list (copy-list words))
           (final-cell (last word-list)))
      (rplaca final-cell last-word-plural)
      (let* ((word-strings (mapcar #'word-pname word-list))
             (pw-string
              (apply #'string-append word-strings)))
        (define-polyword/expr pw-string)))))


;;--- comparative / superlative called from make-rules-for-head (:adjective)

(defun make-comparative-rules (word category referent)
  (declare (special category::comparative))
  (let ((c-word (make-comparative/superlative
                 word :suffix "er" :y-suffix "ier")))
    (list ;; caller append's
     (if (eq category referent)
       ;; If they're different then it's probably deliberate.
       ;; Otherwise we use the default.
       (define-comparative c-word)
       (define-cfr category (list c-word)
         :form category::comparative-adjective
         :referent referent)))))

(defun make-superlative-rules (word category referent)
  (declare (special category::superlative))
  (let ((s-word (make-comparative/superlative
                 word :suffix "est" :y-suffix "iest")))
    (list
     (if (eq category referent)
       (define-superlative s-word)
       (define-cfr category (list s-word)
         :form category::superlative-adjective
         :referent referent)))))




;;--- predicate over plural things

(defun plural-head? (edge)
  ;; The caller has determined that this edge is the head of its phrase
  ;; and wants to know whether its head noun is plural. The test is
  ;; done off the morphology of the word rather than requiring anything
  ;; to have been predefined.
  (let* ((position (chart-position-before (pos-edge-ends-at edge)))
         (word (pos-terminal position)))
    (eq (word-morphology word)
        :ends-in-s)))

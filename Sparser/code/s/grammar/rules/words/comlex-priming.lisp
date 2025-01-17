;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; Copyright (c) 2010-2016 David D. McDonald  -- all rights reserved
;;;
;;;     File: "comlex-priming"
;;;   Module: "grammar/rules/words/
;;;  Version:  October 2016

;; Extracted from one-offs/comlex 12/3/12.
;; 0.1 (8/12/13) Wrapped the eval of the def-word expression in an
;;      ignore-errors because the mlisp load in my ACL 8.2 was choking
;;      on unicode characters in French words.
;; 0.2 (8/7/14) Rewrote prime-word-from-comlex to do away with the
;;      original notion that we did not prime a word if (word-named string)
;;      wasn't nil. That's already stronger than the check in unknown-word? 
;;      which looks for a rule set. Now we want the subcategorization
;;      information for all the words, 'known' or not, so we need to prime
;;      them all even though we will often not be using that scheme in
;;      the word lookup and object creation. 
;;     (9/11/14) moved out the subcategorization stub. 
;; 8.3 (10/20/14) removed the ignore-errors that was wrapped around
;;      the eval's of the def-word forms. 

(in-package :sparser)

;;;-----------------------
;;; Priming all of Comlex
;;;-----------------------

(defvar *comlex-words-primed* nil
  "Flag that indicates that the priming has been done")

(defparameter *primed-words* (make-hash-table :size 70000 ;; 56k
                                              :rehash-size 5000
                                              :test #'equal)
  ;; After first full run came to 65,713
  "Holds priming data for all the words we know something about
   but don't want to load as part of the regular system.")

;;///// Deal with "go" (defined in /sl/checkpoint/vocabulary/ and
;; other instances of cases where there's a :3psing feature in the
;; Comlex verb data.   As part of that, figure out what happens if
;; we've already expanded the word (e.g. via /dossiers/irregular-verbs)
;; when we want to fold it into the realization of a category.

(defun prime-comlex ()
  ;; called from load-the-grammar, gated by *incorporate-generic-lexicon*
  (establish-version-of-def-word :comlex)
  (prime-all-comlex-words "sparser:one-offs;comlex-def-forms.lisp")
  (setq *comlex-words-primed* t))

(defun prime-all-comlex-words (full-filename) ;;(break "top of prime-all")
  (with-open-file (stream full-filename
                   :direction :input
                   :if-does-not-exist :error)
    (let ((*package* (find-package :sparser)))
      (do ((entry (read stream nil :eof)
                  (read stream nil :eof)))
          ((eq entry :eof))
        (unless (eq (car entry) 'def-word)
          (error "Comlex entry based on something other than ~
                def-word:~%  ~a" entry))
        ;;(ignore-errors 
        ;; We need to detect any problems within the Comlex
        ;; forms. Problems with accent characters have blocked
        ;; large swaths of the entries from loading.
        (eval entry)))))



;; This is the expansion of a macro, so any change to it requires an
;; update of its integration site
;;   (establish-version-of-def-word :comlex)
;;
(defun prime-word-from-comlex (string entries)
  ;; This is an expansion for the def-word macro. There's a complication
  ;; that the same spelling form can be part of muliple Comlex entries,
  ;; usually with quite different parts of speech. We have to merge them
  ;; as we see them. 

  ;; Data checks
  (unless (null (cdr entries))
    (push-debug `(,string ,entries))
    (error "Expected just one item in an entry"))
  (let ((entry (car entries)))
    (unless (eq (car entry) :comlex)
      (error "Entry doesn't begin with :comlex~%  ~a" entry))

    (let* ((clauses (cdr entry))
           (variants-and-parts-of-speech
            (unless (string-equal string "be")
              (collect-strings-from-comlex-entry string clauses)))
           (variants
            (if (stringp (car variants-and-parts-of-speech))
                variants-and-parts-of-speech
                (loop for alt in variants-and-parts-of-speech
                      when (consp alt)
                        append alt)))
           (all-words (pushnew string variants :test #'string-equal)))
      (when (and (consp variants-and-parts-of-speech)
                 (member (car variants-and-parts-of-speech)
                         '(:comparative :superlative)))
        (setq entries
              (merge-variants-and-parts-of-speech-into-entry
               string
               clauses
               variants-and-parts-of-speech))
        )
      ;;(break "check for verb variants")
      (let* ((prior-entry ;;/// only ever one? Need to test for this !
               ;; New code to avoid merging definititions into incorrect root
               ;;  e.g. don't merge the noun "building" into the roor form "build"
               (cond ((and (gethash string *primed-words*)
                           (or (is-in-p 'sp::adjective entries)
                               (is-in-p 'sp::adverb entries)
                               (is-in-p 'sp::noun entries)
                               (is-in-p 'sp::prep entries)) ;; "bar" as in "bar none"ck
                           (or (ends-in? string "ing")
                               (ends-in? string "ed")
                               (ends-in? string "er") ;; "cleaner" as a noun
                               (ends-in? string "est")
                               (ends-in? string "ly")
                               (ends-in? string "s"))) ;; "bats" as an adjective
                      ;; how do we detect "broke" as an adjective, "bound"
                      ;; "does" as an aux vs plural "doe"
                      ;; "does" as an aux vs plural "doe"
                     
                      ;;(format t "~%(rejecting merge of ~s ~s)" string entries)
                      nil)
                     (t (gethash string *primed-words*))))
             (entry-to-store
               (cond (prior-entry
                      ;;(format t "~%(ACCEPTING merge of ~s ~s into ~s)" string entries prior-entry)
                      (merge-comlex-entries prior-entry clauses))
                     (t
                      `(:comlex ,string ;; lemma form
                                ,@(cdr entry))))))
        (dolist (string all-words)
          ;;(format t "~&priming \"~a\"~%" string)
          #+ignore
          (when (is-in-p 'gradable entries)
            (format t "comlex for adjectiv ~s~%"
                    entry-to-store))
          (setf (gethash string *primed-words*) entry-to-store))
        all-words))))

(defun merge-comlex-entries (prior-entry current-clauses)
  #+ignore
  (lsp-break "~%merge-comlex-entries prior: ~s     new: ~a~%"
          prior-entry current-clauses)
  (let* ((pname (cadr prior-entry))
         (earlier-clauses (cddr prior-entry))
         (final-clauses earlier-clauses))
    (dolist (clause current-clauses)
      (let* ((label (car clause))
             (matching-clause (assq label earlier-clauses)))
        (unless matching-clause
          (push clause final-clauses))
        ;;/// really ought to check and merge the matching ones
        ;; but I'm putting that off 12/3/12 ddm.
        ))
    `(:comlex ,pname ,@final-clauses)))


(defun merge-variants-and-parts-of-speech-into-entry (lemma entries pos-variants)
  (let ((adjective (assoc 'adjective entries)))
    (when adjective
      (setf (second adjective)
            (append pos-variants (second adjective)))
      #+ignore
      (format t "~%merge-variants-and-parts-of-speech-into-entry ~% entry: ~s entries ~s~% pos-variants ~s~%====> ~s%"
              lemma entries pos-variants
              entries))
    entries))
    

;;--- aux

(defun collect-strings-from-comlex-entry (lemma clauses) ;; lemma is a string
  (let ( strings )
    (dolist (clause clauses)
      (ecase (car clause) 
        (noun
         (let ((plurals (extract-plurals-from-comlex-entry lemma clause)))
           (when plurals
             (dolist (plural plurals)
               (pushnew plural strings :test #'string-equal)))))
        (verb
         ;; if a variant isn't given then we have to make it.
         (let* ((plist (cadr clause))
                (i  (cadr (memq :infinitive plist)))
                (ts (cadr (memq :tensed/singular plist)))
                (p  (cadr (memq :past-tense plist)))
                (pp (cadr (memq :present-participle plist))))
           (if i ;; infinitive
             (pushnew i strings :test #'string-equal)
             (pushnew lemma strings :test #'string-equal))

           (if ts ;; singular, tensed
             (pushnew ts strings :test #'string-equal)
             (pushnew (s-form-of-verb lemma) strings
                      :test #'string-equal))

           (if p ;; past
             (if (consp p) ;; multiple past tense forms
               (dolist (form p)
                 (pushnew form strings :test #'string-equal))
               (pushnew p strings :test #'string-equal))
             (pushnew (ed-form-of-verb lemma) strings
                      :test #'string-equal))
           (if pp ;; present participle
             (if (consp pp)
               (dolist (form pp)
                 (pushnew form strings :test #'string-equal))
               (pushnew pp strings :test #'string-equal))
             (pushnew (ing-form-of-verb lemma) strings
                      :test #'string-equal))))

        (adjective
         (let* ((plist (cadr clause))
                (features (cadr (memq :features plist)))
                (comparative (cadr (memq :comparative plist)))
                (superlative (cadr (memq :superlative plist)))
                (gradable (assoc 'gradable features))
                (er-est (or (memq :er-est gradable)
                            (memq :both gradable)))
                (more-most (not (memq :er-est gradable)))
                (adj-entry
                 (when gradable
                   (append
                    `(:comparative
                      ,(cond ((consp comparative) comparative)
                             (comparative (list comparative))
                             (t (append (when er-est (make-er-comparatives lemma))
                                   (when more-most (make-more-comparatives lemma))))))
                    `(:superlative
                      ,(cond ((consp superlative) superlative)
                             (superlative (list superlative))
                             (t (append
                                 (when er-est (make-est-superlatives lemma))
                                 (when more-most (make-most-superlatives lemma))))))))))
           (when adj-entry
             (setq strings adj-entry)
             ))) ;; just the lemma, so the caller handled it
        (adverb)
        ;; These below should mostly be lifted from comlex-function-words
        ;; and integrated carefully so they'll be 'known' when we upload
        ;; the def-word file
        (prep)
        (det) ;; determiner
        (pronoun) ;; "anybody"
        (cardinal)
        (ordinal)
        (scope) ;; "either"
        (quant) ;; "enough"
        (cconj) ;; "nor"
        (advpart) ;; "across"
        (word)  ;; "whatever"
        (title) ;; e.g. "Cpl."
        (sconj) ;; "according as"
        (aux))) ;; for "d" and "ll" -- ignore them?
    ;;(format t "~%collect-strings-from-comlex-entry ~s ~s" lemma strings )
    strings))

(defmethod extract-plurals-from-comlex-entry ((lemma word) clause)
  (let ((plural-strings 
         (extract-plurals-from-comlex-entry (word-pname lemma) clause)))
    (when plural-strings 
      (mapcar #'define-word/expr plural-strings))))

(defmethod extract-plurals-from-comlex-entry ((lemma string) clause)
  (let ((plural-entry (cadr (assoc :plural (cdr clause)))))
    (cond
      ((eq plural-entry '*none*)
       nil)
      (plural-entry
       (typecase plural-entry
         (cons plural-entry)
         (string `(,plural-entry))
         (otherwise
          (error "Unexpected plural clause: ~a" plural-entry))))
      (t ;; Nothing unusual, so use the built-in machinery
       (let ((plural (plural-version lemma)))
         `(,plural))))))

(defun make-er-comparatives (lemma &aux new-lemma)
  (when
      (setq new-lemma (fix-base-to-add-suffix lemma "er"))
    ;;(setq lemma (maybe-replace-final-y-by-i lemma))
    #+ignore (when (equal "e" (subseq lemma (1- (length lemma))))
               (setq lemma (subseq lemma 0 (1- (length lemma)))))
    (list (format nil "~aer" new-lemma))))

(defun make-more-comparatives (lemma)
  (list (format nil "more ~a" lemma)))

(defun make-est-superlatives (lemma &aux new-lemma)
  (when
      (setq new-lemma (fix-base-to-add-suffix lemma "est"))
    (list (format nil "~aest" new-lemma))))

(defun make-most-superlatives (lemma)
  (list (format nil "most ~a" lemma (maybe-replace-final-y-by-i lemma))))

(defun maybe-replace-final-y-by-i (lemma)
  (if (equal "y" (subseq lemma (1- (length lemma))))
      (format nil "~ai" (subseq lemma 0 (1- (length lemma))))
      lemma))

;;;--------
;;; traces        
;;;--------

(defvar *trace-lexicon-unpacking* nil)

(defun trace-lexicon-unpacking ()
  (setq *trace-lexicon-unpacking* t))

(defun untrace-lexicon-unpacking ()
  (setq *trace-lexicon-unpacking* nil))

(deftrace :unpacking (instance-word)
  ;; Called from unpack-primed-word
  (when *trace-lexicon-unpacking*
    (trace-msg "Unpacking ~a" instance-word)))

(deftrace :unpacking-unambiguous (tag)
  ;; called from unambiguous-comlex-primed-decoder
  (when *trace-lexicon-unpacking*
    (trace-msg "  it is an unambiguous ~a" tag)))

(deftrace :unpacking-ambiguous (combination)
  ;; called from unambiguous-comlex-primed-decoder
  (when *trace-lexicon-unpacking*
    (trace-msg "  it is ambiguous between ~a" combination)))


(defun fix-base-to-add-suffix (base suffix &key (initial-letter-suffix (subseq suffix 0 1)))
  (declare (special *consonants* *vowels*))
  (cond ((and (vowel? initial-letter-suffix)
	      (>= (length base) 3))
	 (let ((lastchar (subseq base (- (length base) 1)))
	       (2lastchar (subseq base
				  (- (length base) 2)
				  (- (length base) 1)))
	       (3lastchar (subseq base
				  (- (length base) 3)
				  (- (length base) 2))))
	   (cond ((string-equal lastchar "y")
		  (cond 
                    ;; additional possible condition, which we are marking as
                    ;; irregular
                    ;;		   ((string-equal 2lastchar "e")
                    ;;			 (concatenate 'string
                    ;;			   (subseq base 0 (- (length base) 2))
                    ;;			   "i"))
                    ((vowel? 2lastchar) base)
                    (t (concatenate 
                        'string
			(subseq base 0 (- (length base) 1))
			"i"))))
		 ((member lastchar '("h" "w" "x") :test #'string-equal)
		  base)
		 ((and (member suffix '("er" "est") :test #'string-equal)
		       (string-equal (subseq base
					     (- (length base) 3))
				     "ous"))
		  nil)
		 ;; affix-specific for er and est - 
		 ;; there is no comparative/superlative forms for
		 ;; adjectives ending in "ous" - I hope there are
		 ;; no verbs ending in "ous" or the ones that
		 ;; do do not take "er" endings - also
		 ;; I am ignoring the phrase "curiouser and curiouser"
		 ;; from Alice in Wonderland/through the looking glass
		 
		 ;; add in other suffix specific stuff here *****
		 
		 ((vowel? lastchar)
		  (cond ((string-equal lastchar initial-letter-suffix)
			 (subseq base 0 (- (length base) 1)))
			(t base)))
		 ((consonant? lastchar)
		  (cond ((consonant? 2lastchar)
			 base)
			((vowel? 2lastchar)
			 (cond ((vowel? 3lastchar)
				base)
			       ((consonant? 3lastchar)
				(concatenate
                                 'string
                                 base
                                 lastchar))
			       (t nil)))
			(t nil)))
		 (t nil))))
	((< (length base) 3) nil)
	((consonant? initial-letter-suffix)
	 (error "A general routine for suffixes beginning with a consonant has not been written"))
	(t (error "The suffix ~s does not begin with a consonant or a vowel" 
		  suffix))))

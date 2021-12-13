;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 2019-2021 David D. McDonald  -- all rights reserved
;;; 
;;;     File:  "prescan"
;;;   Module:  "analyzers;char-level:"   ("character level processing")
;;;  Version:   November 2021

;; Initiated 4/16/19 -- Before doing any analysis, sweep through the input
;; text at the character level to normalize newlines (paragraphs), convert
;; character encodings to characters, etc.

(in-package :sparser)

#|
sp> (decode-file-expression/pathname "~/sift/nlp/Grok/corpus/WP_clean_article_data/11")
#P"~/sift/nlp/Grok/corpus/WP_clean_article_data/11"

analyze-text-from-file
  -> (establish-character-source/file pathname)
     ;; opens the file, sets *filepos-at-beginning-of-source*
  -> (establish-character-source/open-file file-stream)
     ;; sets the buffer globals (see analyzers/char-level/state.lisp)
     ;; designates *first-character-input-buffer* as the buffer to fill
     ;; Calls read-chars-into-buffer/maximum-count to fill the buffer
     ;; Returns the buffer (which is all nulls (^@) after the ^B)

 -> analysis-core
     ;; calls per-article-initializations
         -- clear-context-variables reinitializes dynamic vars like *topic-company*
            that are created by define-context-variable
         -- calls initialize-document-element-resources and then
            begin-new-article, which ripples downward to initialize
            all the others, e.g. initialize-paragraphs (which uses chart positions
            as its indexes)  -> initialize-sentences (also chart positions)
-> chart-based-analysis
     ;; Does dispatch on *kind-of-chart-processing-to-do* which is usually
     ;; going to be :successive-sweeps --> initiate-successive-sweeps

scan-name-position -> add-terminal-to-chart 
  -> next-terminal (parameterized on *definition-of-next-terminal*)
     -> next-terminal/pass-through-all-tokens
        -> next-token
           -> run-token-fsa 
                (elt *character-buffer-in-use* (incf *index-of-next-character*))))
|#

;;--- flags

(defparameter *prescan-character-input-buffer* nil
  "Used as a flag read by analyze-text-from-file for whether or not we do the
   buffer switch and prescan. Read in both analyze-text-from-file, where we
   need it to run in order to rationalize the sequences of newline characters
   used to delimit paragraphs, and in analyze-text-from-string, where it
   only does the prescan if this flag is up.")

;;--- testing jig

(defun test-prescan (string &optional echo?)
  (let ((*prescan-character-input-buffer* t))
    (declare (special *prescan-character-input-buffer*))
    (establish-character-source/string string)
    (scan-and-swap-character-buffer :echo echo?)
    (let ((end (position #\^B *character-buffer-in-use*)))
      (subseq *character-buffer-in-use* 0 (1+ end)))))



;;--- driver

(defvar *post-hyphen-chars* nil
  "Collects characters that follow hyphen is that line is uncommented out")


(defun scan-and-swap-character-buffer (&key (echo nil))
  "Character-level preprocessor -- Called by one of the text staging
 functions (analyze-text-from-file or analyze-text-from-string) when
 the flag *prescan-character-input-buffer* is up. Copies the just-populated
 character buffer in use to the alternative buffer, character by character
 while normalizing it, e.g., multiple newlines are reduced to just one,
 leading spaces are removed, quotation marks and punctuation are flipped,
 html character-coding escape strings decoded, ..."

  (declare (special *paragraphs-from-orthography*))
  
  (multiple-value-bind (source sink) (character-buffer-being-used)
    (declare (special source sink))
    (let* ((index-into-source 0)
           (index-into-sink 0)
           (starting? t)
           (source-exhausted nil)
           (pending-newline? nil)
           char  replacement-char )

      (labels ((push-char (c)
                 "Copy the character to the sink buffer and bump
                  both indicies."
                 (setf (schar sink index-into-sink) c)
                 (incf index-into-sink)
                 (incf index-into-source))
               (handle-newline (c)
                 "Retain just one newline character"
                 (if pending-newline?
                   (incf index-into-source)
                   (else (push-char c)
                         (when echo (write-char #\newline))
                         (setq pending-newline? t)))))

        (until source-exhausted (swap-in-sink-buffer sink)
          ;; Loop until the 'source-exhausted' flag is non-nil,
          ;; then call the swap buffer function to make the
          ;; buffer be the sink that we just populated.
          
          (setq char (elt source index-into-source))
          
          (case char
            (#\^D ;; :end-of-buffer
             (push-debug `(,source ,sink))
             (error "Prescan walked off the end of the buffer"))
            (#\^A ;; source start
             (unless (= index-into-source 0)
               (error "Encountered source-start character (\#^A) at ~
                       index ~a" index-into-source))
             (push-char char))
                        
            (#\-
             (cond ((and (> index-into-source 0)
                         (alphabetic-char? (elt source (1- index-into-source)))
                         (eql (elt source (1+ index-into-source)) #\space))
                    ;;(pushnew (elt source (1+ index-into-source)) *post-hyphen-chars* :test #'equalp)
                    (incf index-into-source 2))
                   (t (push-char char))))

            (#\space ;; remove leading spaces
             (if starting?
               (incf index-into-source)
               (else (when echo (write-char #\space))
                     (push-char char))))

            (#\<
             (if (embedded-html-newline index-into-source source) ;; "<nl/>"
               (then
                 (unless (eql #\newline (aref source (1- index-into-source)))
                   (push-char #\newline)) ;; double newlines confuses paragraphing
                 (setf index-into-source (+ 4 index-into-source)))                    
               (push-char char)))

            (#\&
             (multiple-value-setq (replacement-char index-into-source)
               (replace-html-char-encoding source index-into-source))
             (setf (schar sink index-into-sink) replacement-char)
             (when echo (write-char replacement-char))
             (incf index-into-sink))

            (#\newline
             (handle-newline char))

            (#\^M ;;(break "cntrl-M")
             (handle-newline char))

            (#\' ;; detect and convert paired single quotes
             (if (eql (schar sink (1- index-into-sink)) #\')
               (then
                 ;; There is a single-quote already on the sink,
                 ;; which plus the one we just encountered means we have two adjacent ones.
                 ;; Back the sink up over to remove the #\' that we just pushed,
                 ;; and then push a double quote instead
                 (setf index-into-sink (1- index-into-sink))
                 (push-char #\"))
               (else ; let the first one go through to the sink
                 (push-char char))))
               
            ((#\. #\,)
             (if (eql (schar source (1+ index-into-source)) #\")
               (then ;; swap them
                 (setf (schar sink index-into-sink) #\")
                 (setf (schar sink (1+ index-into-sink)) char)
                 (when echo (write-char #\") (write-char char))
                 (setf index-into-sink (+ 2 index-into-sink)
                       index-into-source (+ 2 index-into-source)))
               (else
                 (when echo (write-char char))
                 (push-char char))))

            (#\^B
             (unless (eql (schar sink (1- index-into-sink)) #\newline)
               (when *paragraphs-from-orthography*
                 ;; To fit the assumptions in new-orth-paragraph about how to
                 ;; determine the bounds of the the paragraph it creates,
                 ;; we have to ensure than the buffer ends with a newline character
                 (setf (schar sink index-into-sink) #\newline)
                 (incf index-into-sink)))
             (setf (schar sink index-into-sink) char)
             (setq source-exhausted t)) ;; :end-of-source

            (otherwise
             (setq starting? nil
                   pending-newline? nil)
             (when echo (write-char char))
             (push-char char))))

        (when echo
          (format t "~&~%~%"))))))


;;--- keeping track of the buffers

(defvar *source-char-buffer* nil
  "Points to the character buffer that was 'in-use'
   when we started the scan.")

(defvar *sink-char-buffer* nil
  "Points to the character buffer that was 'next'
   when we started the scan.")

(defun character-buffer-being-used ()
  "Set the two state variables so we can setup the correct
   buffer state when we're done. The reference code for this is
   establish-character-source/open-file where they use absolute
   buffer references."
  (let ((source *character-buffer-in-use*)
        (sink *the-next-character-buffer*))
    (setq *source-char-buffer* source
          *sink-char-buffer* sink)
    (values source sink)))


(defun swap-in-sink-buffer (sink)
  "Called as the exit operation in the until loop that scans
   the characters. Makes the sink the official character
   buffer and initializes the key state variables.
   Note that the index of the next character is -1 because
   scan-next-position increments this variable before it accesses
   a character (see run-token-fsa) and the first call to it is
   supposed to pull the ~A into the chart as the start marker."
  (setq *character-buffer-in-use* sink)
  (setq *index-of-next-character* -1)
  (setq *length-accumulated-from-prior-buffers* 0))


;;--- HTML character encodings

(defparameter *html-char-encodings*
  '(("mdash" #\-) ;; "--" would be better
    ("ndash" #\-) ;; ditto
    ("laquo" #\')
    ("rsquo" #\')
    ("rdquo" #\')
    ("ldquo" #\")
    ("rdquo" #\")
    )
  "See, e.g., dev.w3.org/html5/html-author/charref for a bigger list
   or https://www.rapidtables.com/web/html/html-codes.html for the
   full list.")


(defun replace-html-char-encoding (source index)
  "The index is right on the ampersand character. We search for 
   a semi-colon and if we find one (not too far away) we take the
   substring between them as the symbolic encoding and look for
   the corresponding character in the table. Alternatively we look
   for the '#' that indicates a numerical encoding."
  (let* ((index-of-semicolon (position #\; source :start index))
         (encoding (when index-of-semicolon
                     (subseq source (1+ index) index-of-semicolon))))
    (if (and encoding
             (not (string= encoding "")) ;; it's not listed or it's bad syntax
             (< (length encoding) 7)) ;;/// lookup the spec
      (let ((replacement (cadr (assoc encoding *html-char-encodings* :test #'string=))))
        (unless replacement
          (if (eql (aref encoding 0) #\#)
            (let* ((code-string (subseq encoding 1))
                   (code (when code-string (read-from-string code-string))))
              (setq replacement (code-char code)))
            (else
              (format t "~&~%~%==== No encoding recorded for ~s ====~%~%~%"
                      encoding)
              (setq replacement #\space))))
        (values replacement
                (1+ index-of-semicolon)))
      (else
        (values #\& (1+ index))))))

(defun embedded-html-newline (index source)
  "There is an angle bracket at the index. Search ahead to see whether
   it's the start of the html pattern for a newline"
  ;; 
  #+ignore(push-debug `(,index
                  ,(subseq source 0 (position #\^B source))))
  (let* ((characters (loop for i from index to (+ 4 index) collect (aref source i)))
         (string (apply #'string-append characters)))
    (search "<nl/>" string)))


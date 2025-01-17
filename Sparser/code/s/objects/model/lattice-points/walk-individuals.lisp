;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:(SPARSER LISP) -*-
;;; copyright (c) 2017 David D. McDonald  -- all rights reserved
;;;
;;;     File:  "walk-individuals"
;;;   Module:  "objects;model:lattice-points:"
;;;  version:  July 2017

;; Initialized 6/12/17. Routines for walking around the description lattice
;; to find individuals with various properties.

(in-package :sparser)

#| An uplink is a cons of a v+v and an individual, e.g.
    ((#<dl-vv has-determiner + #<the 106>> . #<protein 74245>))
 The uplinks field of an individual is presently a list of just
 one uplink. The uplink of an individual i is the variable+value
 of the binding that was added the individual j to creeate i.
|#

;; sugar for the uplink sexp
(defun uplink-indiv (uplink) (cdr uplink))
(defun uplink-vv (uplink) (car uplink))


(defun uplinks-of (i)
  (let ((up (indiv-uplinks i)))
    (when up
      (unless (eq (dlvv-variable (caar up)) :superc)
        (cons (car up) (uplinks-of (cdar up)))))))


(defun most-recent-binding (i)
  "Return the variable that was most recent bound on this individual"
  (let* ((uplink (car (indiv-uplinks i)))
         (vv (uplink-vv uplink))
         (var (dlvv-variable vv))
         (j (uplink-indiv uplink)))
    (values var j)))

(defun prior-individual (i)
  "Use the uplink information to return the individual that 
   was bound to the most recent variable+value to produce this
   individual (i)"
  (uplink-indiv (car (indiv-uplinks i))))



;;/// Still being sorted out -- we'd like a base individual
;; plus a list of bindings
(defun unwind-from-right (i)
  (let* ((uplinks (reverse (uplinks-of i)))
         (j (uplink-indiv (car uplinks)))
         (vv (loop for uplink in (cdr uplinks)
                collect (uplinks-of (uplink-indiv uplink)))))
    (values j vv)))

#|sp> (unwind-from-right i)
#<protein 2183>
(#<dl-vv non-cellular-location + #<liver 81969>>
 #<dl-vv organism + #<human 1830>>
 #<dl-vv predication + #<phorphorylate 81972>>
 #<dl-vv has-determiner + #<the 106>>) |#                  

#|
sp> (p/s "the phorphorylated human liver protein")
[the phorphorylated human liver protein]
                    source-start
e10   PROTEIN       1 "the phorphorylated human liver protein" 6
                    end-of-source
(#<protein 74246> 
   (has-determiner (#<the 106> (word "the")))
   (predication (#<phorphorylate 74244> (object *lambda-var*)))
   (organism (#<human 1830>)) 
   (non-cellular-location (#<liver 74240>))
   (raw-text "protein"))

sp> (defvar i (i# 74246))
i
sp> (indiv-uplinks i)
((#<dl-vv has-determiner + #<the 106>> . #<protein 74245>))
sp> (caar *)
#<dl-vv has-determiner + #<the 106>>
sp> (indiv-uplinks (i# 74245))
((#<dl-vv predication + #<phorphorylate 74244>> . #<protein 74243>))
sp> (indiv-uplinks (i# 74243))
((#<dl-vv organism + #<human 1830>> . #<protein 74242>))
sp> (indiv-uplinks (i# 74242))
((#<dl-vv non-cellular-location + #<liver 74240>> . #<protein 74241>))
sp> (indiv-uplinks (i# 74241))
((#<dl-vv raw-text + protein> . #<protein 2183>))
sp> (indiv-uplinks (i# 2183))
((#<dl-vv superc + nil> . #<in-ras2-model 2189>)
 (#<dl-vv superc + nil> . #<reactome-category 2188>)
 (#<dl-vv superc + nil> . #<peptide 2184>))
|#


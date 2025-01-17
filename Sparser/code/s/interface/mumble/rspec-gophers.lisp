;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 2013 David D. McDonald  -- all rights reserved
;;;
;;;     File:  "rspec-gophers"
;;;   Module:  "/interface/mumble/"
;;;  version:  April 2013

;; Broken out from interface 4/7/13 

(in-package :sparser)

(defmethod mumble-phrase ((s-name symbol))
  "Given a symbol in the sparser package, return the phrase
   from mumble that has that name."
  (let* ((m-name (intern (symbol-name s-name)
                         (find-package :mumble)))
         (phrase (mumble::phrase-named m-name)))
    (unless phrase
      (push-debug `(,s-name ,m-name))
      (error "There is no phrase in Mumble with the name ~a" m-name))
    phrase))

;;--- words

(defmethod binds-a-word? ((i individual))
  (or (binds-variable i 'name)
      (binds-variable i 'word)))

(defmethod bound-word ((i individual))
  (let* ((binding/s (binds-a-word? i))
	 ;; in principle there could be more than one
	 (binding (typecase binding/s
		    (cons (car binding/s))
		    (binding binding/s)
		    (otherwise
		     (error "New type: ~a~%~a" 
			    (type-of binding/s) binding/s)))))
    (binding-value binding)))

;;--- determiners

(defun convert-determiner-value-to-policy (value)
  (push-debug `(,value))
  (unless (category-p value) (error "Expected value to be a category"))
  (case (cat-symbol value)
    ;; Read by mumble::process-np-accessories and values interpreted by
    ;; process-determiner-accessory
    (category::indefinite
     ;;///////// Generalize to get-accessory-value or some such
     `(:determiner-policy 'mumble::kind))
    (category::definite
     `(:determiner-policy 'mumble::known-individual))
    (otherwise
     (error "Unexpected value"))))




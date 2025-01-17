;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; Copyright 2010-2011,2018 David D. McDonald, all rights reserved
;;;
;;;     File: "loader"
;;;   Module: "grammar;rules:words:one-offs:"
;;;  Version:  March 2018

;; initiated 8/13/10. Added treebank-reader 11/1. 7/27/11 added
;; def-word. 11/26/14 added obo-reader.

(in-package :sparser)

(gload "one-offs;def-word")
(gload "one-offs;comlex")
(gload "one-offs;comlex-adjectives")
(gload "one-offs;comlex-adverbs")
(gload "one-offs;comlex-nouns")
(gload "one-offs;comlex-verbs")
(gload "one-offs;comlex-function-words") ;; !!! disperse
(gload "one-offs;ERG")
(gload "one-offs;treebank-reader")
(gload "one-offs;obo-reader")
(gload "one-offs;bob-ont-reader")
;(gload "one-offs;")



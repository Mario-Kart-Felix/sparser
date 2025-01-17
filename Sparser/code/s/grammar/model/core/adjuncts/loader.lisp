;;; -*- Mode:LISP; Syntax:Common-Lisp; Package:SPARSER -*-
;;; copyright (c) 1994-1997,2013 David D. McDonald  -- all rights reserved
;;;
;;;      File:  "loader"
;;;    Module:  "grammar;model:core:adjuncts:"
;;;   version:  January 2013

;; initiated 5/25/94 v2.3 merging files from next level down. 6/25/96 added
;; gate around the autodef'inition. 1/18/13 Added [others]

(in-package :sparser)

;;;-------------
;;; the modules
;;;-------------

(gate-grammar *standard-adjuncts*
  (gload "adjuncts;others"))

(gate-grammar *approximators*
  (gload "approx;object"))

(gate-grammar *frequency*
  (gload "frequency;object")
  (gload "frequency;aux rules"))

(gate-grammar *sequencers*
  (gload "sequence;object"))



;;;-------------------------------------------------------------------
;;; autodef for the whole set (since they don't have a common parent)
;;;-------------------------------------------------------------------

(define-autodef-data 'modifier
  :display-string "modifier"
  :not-instantiable t)

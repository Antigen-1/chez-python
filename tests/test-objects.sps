#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi environment) (chez-python ffi system) (chez-python ffi config))

(load-python)
(setup-environment)

(for-each
 (lambda (e) (eval e (current-environment)))
 '((import (srfi :64 testing) (python-c-api))
   (define-ftype c-string
     (* unsigned-8))
   
   (test-begin "objects")
   (initialize-python)
   (test-assert (python-initialized?))
   
   (define builder1 (make-object-builder "(sii)" string int int))
   (define t (builder1 "a" 0 1))
   (define len (object-length t))
   (test-equal len 3)
   
   (define parser (make-object-parser "(sii)" c-string int int))
   (define-values (slot1 slot2 slot3) (parser t))
   (test-equal (ftype-ref c-string (0) slot1) 97)
   (test-equal (ftype-ref int () slot2) 0)
   (test-equal (ftype-ref int () slot3) 1)
   
   (define builder2 (make-object-builder "[dii]" double int int))
   (define one-arg-tuple-builder (make-object-builder "(O)" (tag PyObj)))
   (define empty-dict-builder (make-object-builder "{}"))
   (define l (builder2 1.2 0 1))
   (test-assert (object-has-attr? l "append"))
   (define l-append! (object-get-attr l "append"))
   (call l-append! (one-arg-tuple-builder (get-constant 1)) (empty-dict-builder))
   (test-equal (object-length l) 4)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

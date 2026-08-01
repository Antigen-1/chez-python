#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi functions) (chez-python ffi utilities))

(load-python)
(define env (setup-environment))

(for-each
 (lambda (e) (eval e env))

 '((import (srfi :64 testing))
   (define-ftype c-string
     (* unsigned-8))
   
   (test-begin "objects")
   (initialize-python)
   (define builtins (pyimport "builtins"))
   (define builder1 (make-object-builder "(i)" int))
   (define builder2 (make-object-builder "{}"))
   (define builder3 (make-object-builder "(O)" void*))
   (define parser (make-object-parser "s" c-string))
   (define ->str (object-get-attr builtins "str"))
   (define r (call ->str (builder1 1) (builder2)))
   (define c (ftype-ref c-string (0) (parser (builder3 r))))
   (test-equal c 49)
   (finalize-python)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

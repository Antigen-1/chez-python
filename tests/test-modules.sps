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
   
   (test-begin "modules")
   (initialize-python)
   (define builtins (pyimport "builtins"))
   (define builder1 (make-object-builder "(i)" int))
   (define builder2 (make-object-builder "{}"))
   (define parser (make-object-parser "s" c-string))
   (define ->str (object-get-attr builtins "str"))
   (define r (call ->str (builder1 1) (builder2)))
   (define c (ftype-ref c-string (0) (parser r)))
   (test-equal c 49)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

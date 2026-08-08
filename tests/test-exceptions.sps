#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme)
	(chez-python ffi environment)
	(chez-python ffi utilities)
	(chez-python ffi config)
	(chez-python ffi coerce)
	(chez-python exn))

(load-python)
(current-environment (setup-environment))
(enable-coerce-functions)

(for-each
 (lambda (e) (eval e (current-environment)))
 '((import (srfi :64 testing) (chez-python exn) (python-c-coerce))
   
   (test-begin "exceptions")
   (initialize-python)
   (define tl (->py-list (list (->py-int 1))))
   (define builtins (pyimport "builtins"))
   (define type-error (object-get-attr builtins "TypeError"))
   (define exc #f)
   (guard (exn (python-condition? (let ((pyexn (get-current-exception)))
				    (set! exc pyexn)
				    (test-assert (exception-match? pyexn type-error))
				    (exception-clear!)))
	       (else (void)))
     (object-ref tl (->py-string "a")))
   (test-assert exc)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

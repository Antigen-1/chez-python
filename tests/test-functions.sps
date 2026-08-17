#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme)
	(chez-python ffi environment)
	(chez-python ffi system)
	(chez-python ffi config)
	(chez-python ffi coerce)
	(chez-python ffi function)
	(chez-python exn))

(load-python)
(current-environment (setup-environment))
(enable-coerce-functions)
(enable-function-library)

(for-each
 (lambda (e) (eval e (current-environment)))
 '((import (srfi :64 testing) (chez-python exn) (python-c-coerce) (python-c-function))
   
   (test-begin "exceptions")
   (initialize-python)
   (define tl (->py-list (list (->py-int 1))))
   (define builtins (pyimport "builtins"))
   (define type-error (object-get-attr builtins "TypeError"))
   (define exc #f)
   (with-python-handler (lambda (exn pyexn)
			  (set! exc pyexn)
			  (test-assert (exception-match? pyexn type-error))
			  (exception-clear!))
			(object-ref tl (->py-string "a")))
   (test-assert exc)
   (test-equal
       (->scm-int
	(pyapply (object-get-attr builtins "sum")
		 (list '(1 2 3))))
     6)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

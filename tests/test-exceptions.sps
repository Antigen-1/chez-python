#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme)
	(chez-python ffi system)
	(chez-python ffi config)
	(chez-python exn))

(load-python)

(current-environment (copy-environment (environment '(chezscheme)
						    '(chez-python ffi env api)
						    '(chez-python ffi env function)
						    '(chez-python ffi env coerce)
						    '(chez-python ffi config))))

(for-each
 (lambda (e) (eval e (current-environment)))
 '((import (srfi :64 testing) (chez-python exn))
   
   (test-begin "exceptions")
   (initialize-python)
   (define tl (->py-list (list (->py-int 1))))
   (define builtins (pyimport "builtins"))
   (define type-error (object-get-attr builtins "TypeError"))
   (define exc1 #f)
   (guard (exn (python-condition? (let ((pyexn (get-current-exception)))
				    (set! exc1 pyexn)
				    (test-assert (exception-match? pyexn type-error))
				    (exception-clear!)))
	       (else (void)))
     (object-ref tl (->py-string "a")))
   (test-assert exc1)
   (define exc2 #f)
   (guard (exn (python-runtime-condition? (let ((pyexn (get-current-exception)))
					    (set! exc2 pyexn)
					    (test-assert (exception-match? pyexn type-error))
					    (exception-clear!)))
	       (else (void)))
     (object-ref tl (->py-string "a")))
   (test-assert exc2)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

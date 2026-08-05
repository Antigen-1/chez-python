#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi environment) (chez-python ffi utilities) (chez-python ffi config))

(load-python)
(current-environment (setup-environment))

(for-each
 (lambda (e) (eval e (current-environment)))

 '((import (srfi :64 testing))
   (define-ftype c-string
     (* unsigned-8))
   
   (test-begin "environment")
   (initialize-python)
   (define (number-list-builder ns)
     (define fmt (string-append "[" (apply string-append (make-list (length ns) "n")) "]"))
     (define types (make-list (length ns) 'ssize_t))
     (apply (eval `(make-object-builder ,fmt ,@types) (current-environment)) ns))
   (let loop ((n 0))
     (cond ((> n 20))
	   (else (test-equal (object-length (number-list-builder (make-list n 10))) n)
		 (loop (+ n 1)))))
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

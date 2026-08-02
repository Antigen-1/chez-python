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
   
   (test-begin "data")
   (initialize-python)
   (define tuple
     (make-object-builder "(O)" void*))
   (define parse-integer
     (let ((proc (make-object-parser "n" ssize_t)))
       (lambda (o)
	 (ftype-ref ssize_t () (proc (tuple o))))))
   (define build-integer
     (make-object-builder "n" ssize_t))
   (define (python-sum pyseq)
     (let ((len (object-length pyseq)))
       (let loop ((i 0))
	 (if (= i len)
	     0
	     (+
	      (parse-integer (object-ref pyseq (build-integer i)))
	      (loop (+ i 1)))))))
   (define (py-make-list n i)
     (apply
      (eval `(make-object-builder ,(format "[~a]" (apply string-append (make-list n "n")))
				  ,@(make-list n 'ssize_t))
	    (current-environment))
      (make-list n i)))
   (test-equal (python-sum (py-make-list 10 10)) 100)
   (collect)
   (finalize-python)
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

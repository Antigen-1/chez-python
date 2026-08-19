#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi environment) (chez-python ffi system) (chez-python ffi config) (chez-python ffi coerce))

(load-python)
(setup-environment)
(enable-coerce-functions)

(for-each
 (lambda (e) (eval e (current-environment)))

 '((import (srfi :64 testing) (python-c-api))
   
   (test-begin "data")
   (initialize-python)
   (define tuple
     (make-object-builder "(O)" (tag PyObj)))
   (define parse-integer
     (let ((proc (make-object-parser "n" ssize_t)))
       (lambda (o)
	 (ftype-ref ssize_t () (proc o)))))
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
   (test-end)

   (test-begin "coerce")
   (import (python-c-coerce))
   (test-equal (->scm-int (->py-int 1234)) 1234)
   (test-equal (->scm-string (->py-string "abcd")) "abcd")
   (let* ((py-list (->py-list (list (->py-string "a") (->py-int 1))))
	  (scm-list (->scm-list py-list)))
     (test-equal (->scm-string (car scm-list)) "a")
     (test-equal (->scm-int (cadr scm-list)) 1))
   (let* ((py-list (->py-tuple (list (->py-string "a") (->py-int 1))))
	  (scm-list (->scm-list py-list)))
     (test-equal (->scm-string (car scm-list)) "a")
     (test-equal (->scm-int (cadr scm-list)) 1))
   (test-equal (length (->scm-list (mapping-keys (make-empty-py-dict)))) 0)
   (let ((d (list 1 '#(2.0 "") (pyimport "builtins") #t #f)))
     (test-equal (->scm-datum (->py-datum d)) d))
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

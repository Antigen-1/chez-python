;; -*- mode: scheme; coding: utf-8 -*-
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs
(import (chezscheme) (chez-python ffi utilities) (chez-python ffi environment))

(scheme-start
 (lambda args
   (define loading? #t)
   (define setup? #t)
   (define initializing? #t)
   (define env #f)
   (define fns '())
   (for-each
    (lambda (a)
      (case a
	(("no-loading") (set! loading? #f))
	(("no-setup") (set! setup? #f))
	(("no-initializing") (set! initializing? #f))
	(else (set! fns (cons a fns)))))
    args)
   (if loading? (load-python))
   (if (and loading? setup?) (set! env (setup-environment)))
   (if (and env initializing?) (eval '(initialize-python) env))
   (if (null? fns)
       (parameterize ((interaction-environment env))
	 (new-cafe))
       (for-each
	(lambda (f)
	  (load f (lambda (e) (eval e env))))
	(reverse fns)))))

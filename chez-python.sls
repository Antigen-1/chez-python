;; -*- mode: scheme; coding: utf-8 -*-
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs
(import (chezscheme)
	(chez-python ffi utilities)
	(chez-python ffi environment)
	(chez-python ffi config))

(scheme-start
 (lambda args
   (define loading? #t)
   (define setup? #t)
   (define initializing? #t)
   (define gil? #f)
   (define fns '())
   (for-each
    (lambda (a)
      (case a
	(("--help")
	 (for-each
	  (lambda (s) (display s) (newline))
	  '("no-loading: disable loading python"
	    "no-setup: disable setting up the environment"
	    "no-initializing: disable initializing python"
	    "attach-thread-state: attach a new thread state to the current thread"
	    "--help: display these messages and then exit"))
	 (exit))
	(("no-loading") (set! loading? #f))
	(("no-setup") (set! setup? #f))
	(("no-initializing") (set! initializing? #f))
	(("attach-thread-state") (set! gil? #t))
	(else (set! fns (cons a fns)))))
    args)
   (if loading? (load-python))
   (if (and loading? setup?) (current-environment (setup-environment)))
   (if (and (current-environment) initializing?)
       (eval '(begin (initialize-python)
		     (exit-handler
		      (let ((handler (exit-handler)))
			(lambda args
			  (finalize-python)
			  (apply handler args)))))
	     (current-environment)))
   (if (and (eval '(python-initialized?) (current-environment)) gil?)
       (eval '(let ((st (new-thread-state (thread-state-get-interp (get-current-thread-state)))))
		(current-thread-state st)
		(swap-thread-state st))
	     (current-environment)))
   (if (null? fns)
       (parameterize ((interaction-environment (current-environment)))
	 (new-cafe))
       (let ((env (current-environment)))
	 (for-each
	  (lambda (f)
	    (load f (lambda (e) (eval e env))))
	  (reverse fns))))))

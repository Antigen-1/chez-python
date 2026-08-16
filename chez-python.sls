;; -*- mode: scheme; coding: utf-8 -*-
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs
(import (chezscheme)
	(chez-python ffi system)
	(chez-python ffi environment)
	(chez-python ffi config)
	(chez-python ffi coerce))

(scheme-start
 (lambda args
   (define loading? #t)
   (define setup? #t)
   (define initializing? #t)
   (define gil? #f)
   (define ext? #t)
   (define fns '())
   (for-each
    (lambda (a)
      (case a
	(("help")
	 (for-each
	  (lambda (s) (display s) (newline))
	  '("no-loading: disable loading python"
	    "no-setup: disable setting up the environment"
	    "no-initializing: disable initializing python"
	    "attach-thread-state: attach a new thread state to the current thread"
	    "disable-extensions: disable loading and importing extensions"
	    "help: display these messages and then exit"))
	 (exit))
	(("no-loading") (set! loading? #f))
	(("no-setup") (set! setup? #f))
	(("no-initializing") (set! initializing? #f))
	(("attach-thread-state") (set! gil? #t))
	(("disable-extensions") (set! ext? #f))
	(else (set! fns (cons a fns)))))
    args)
   (if loading? (load-python))
   (if (and loading? setup?) (current-environment (setup-environment)))
   (let ((env (current-environment)))
     (if env
	 (if initializing?
	     (eval '(initialize-python) env))
	 (if (and (eval '(python-initialized?) env) gil?)
	     (eval '(let ((st (new-thread-state (get-current-interp))))
		      (current-thread-state st)
		      (swap-thread-state st))
		   env))
	 (if (and (eval '(python-initialized?) env) ext?)
	     (begin
	       (enable-coerce-functions)
	       (eval '(import (python-c-coerce)) env))))
     (if (null? fns)
	 (parameterize ((interaction-environment env))
	   (new-cafe))
	 (for-each
	  (lambda (f)
	    (load f (lambda (e) (eval e env))))
	  (reverse fns))))))

;; -*- mode: scheme; coding: utf-8 -*-
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs
(import (chezscheme)
	(chez-python ffi system)
	(chez-python ffi config)

	(chez-python ffi utility)
	(chez-python ffi helper)
	(chez-python exn)
	(rnrs conditions))

;; For packaging
call-with-new-c-string

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
   (let* ((prims '((chezscheme)
		   (chez-python exn)
		   (chez-python ffi helper)
		   (chez-python ffi utility)
		   (chez-python ffi config)
		   (rnrs conditions)))
	  (base (if (and loading? setup?) '(chez-python ffi env api) #f))
	  (exts
	   (if (and base ext?)
	       (list
		'(chez-python ffi env coerce)
		'(chez-python ffi env function))
	       '()))
	  (all (filter (lambda (x) x) (append prims (cons base exts)))))
     (current-environment (copy-environment (apply environment all) #t)))
   (let ((env (current-environment)))
     (if (and loading? setup?)
	 (begin
	   (if initializing?
	       (eval '(initialize-python) env))
	   (if (and (eval '(python-initialized?) env) gil?)
	       (eval '(let ((st (new-thread-state (get-current-interp))))
			(current-thread-state st)
			(swap-thread-state st))
		     env)))))
     ;; Get the current environment dynamically
     (let ((current-eval (lambda (e) (eval e (current-environment)))))
       (if (null? fns)
	   (new-cafe current-eval)
	   (for-each
	    (lambda (f)
	      (load f current-eval))
	    (reverse fns))))))

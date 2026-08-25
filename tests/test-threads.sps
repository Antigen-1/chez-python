#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi system) (chez-python ffi config))

(load-python)

(current-environment (copy-environment (environment '(chezscheme)
						    '(chez-python ffi env api)
						    '(chez-python ffi env function)
						    '(chez-python ffi env coerce)
						    '(chez-python ffi config))))

(for-each
 (lambda (e) (eval e (current-environment)))
 '((import (srfi :64 testing))
   
   (test-begin "threads")
   (initialize-python)
   (new-thread-state (get-current-interp))
   (define ts (new-thread-state (get-current-interp)))
   (swap-thread-state ts)
   (current-thread-state (save-thread-state))
   (restore-thread-state (current-thread-state))
   (test-end)
   
   (exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))))

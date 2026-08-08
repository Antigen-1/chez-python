#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi environment) (chez-python ffi system))

(load-python)
(define env (setup-environment))

(for-each
 (lambda (e) (eval e env))
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

#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi utility) (chez-python utilities) (srfi :64 testing))

(test-begin "utility")
(test-equal (string-replace! "a-b-c_d" #\_ #\-) "a-b-c-d")
(test-equal (string-split "a-b-c-d" #\-) '("a" "b" "c" "d"))
(test-equal (string-prefix "a-b-c-d" '(#\a #\- #\b)) "a-b-")

(foreign-alloc/auto-free (ftype-sizeof int))
(test-assert (not (call-with-new-c-string (lambda (x) x) (make-transcoder (utf-8-codec)))))
(test-equal (call-with-new-c-int-64 (lambda (x) x)) 0)
(collect)
(test-end)

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))

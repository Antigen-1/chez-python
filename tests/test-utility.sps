#!/usr/bin/env scheme-script
;; -*- mode: scheme; coding: utf-8 -*- !#
;; Copyright (c) 2026 Guy Q. Schemer
;; SPDX-License-Identifier: MIT
#!r6rs

(import (chezscheme) (chez-python ffi utility) (srfi :64 testing))

(test-begin "utility")
(foreign-alloc/auto-free (ftype-sizeof int))
(test-assert (not (call-with-new-c-string (lambda (x) x) (make-transcoder (utf-8-codec)))))
(test-equal (call-with-new-c-int-64 (lambda (x) x)) 0)
(collect)
(test-end)

(exit (if (zero? (test-runner-fail-count (test-runner-get))) 0 1))

(library (ffi functions)
  (export increase-refcnt decrease-refcnt)
  (import (chezscheme) (utilities))

  (define-syntax make-foreign-procedure
    (syntax-rules ()
      ((_ (conv ...) entry (param-type ...) res-type)
       (foreign-procedure
	conv ...
	(string-replace! entry #\- #\_)
	(param-type ...) res-type))
      ((_ entry (param-type ...) res-type)
       (foreign-procedure
	#f
	(string-replace! entry #\- #\_)
	(param-type ...) res-type))))

  (define (int->bool n)
    (not (= n 0)))
  
  ;; Reference Counting
  (define increase-refcnt
    (make-foreign-procedure "Py-IncRef" (void*) void))
  (define decrease-refcnt
    (make-foreign-procedure "Py-DecRef" (void*) void))

  ;; Objects
  (define build-object
    (make-foreign-procedure ((__varargs_after 1)) "Py-BuildValue" (string) void*))
  (define object-set!
    (make-foreign-procedure "PyObject-SetItem" (void* void* void*) int))
  (define object-remove!
    (make-foreign-procedure "PyObject-DelItem" (void* void*) int))
  (define object-ref
    (make-foreign-procedure "PyObject-GetItem" (void* void*) void*))
  (define object-length
    (make-foreign-procedure "PyObject-Length" (void*) ssize_t))
  (define object-has-attr?
    (make-foreign-procedure "PyObject-HasAttrString" (void* string) int))
  (define true?
    (make-foreign-procedure "PyObject-IsTrue" (void*) int))
  (define pynot
    (make-foreign-procedure "PyObject-Not" (void*) int)))

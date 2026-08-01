(library (ffi functions)
  (export increase-refcnt decrease-refcnt
	  build-object object-set! object-remove! object-ref object-length
	  object-has-attr? object-set-attr! object-get-attr
	  true? false?

	  current-guardian
	  
	  failure?)
  (import (chezscheme) (utilities) (exn))

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

  (define (make-predicate proc)
    (lambda vs
      (not (= 0 (apply proc vs)))))
  (define (failure? n)
    (or (not n) (eq? n -1)))

  ;; Initialization and Finalization
  (define initialize-python
    (make-foreign-procedure "Py-Initialize" () void))
  (define python-initialized?
    (make-predicate (make-foreign-procedure "Py-IsInitialized" () int)))
  (define finalize-python
    (make-foreign-procedure "Py-FinalizeEx" () int))
  
  ;; Reference Counting
  (define increase-refcnt
    (make-foreign-procedure "Py-IncRef" (void*) void))
  (define decrease-refcnt
    (make-foreign-procedure "Py-DecRef" (void*) void))

  ;; Automatic Garbage Collection
  (define current-guardian (make-parameter (make-guardian)
					   (lambda (g)
					     (unless (guardian? g)
					       (raise-contract-error 'current-guardian "guardian?" g))
					     g)))
  (collect-request-handler
   (lambda ()
     (collect)
     (let loop ((x ((current-guardian))))
       (when x
	 (decrease-refcnt x)
	 (loop)))))
  (define (make-new-reference-maker proc)
    (lambda vs
      (let ((r (apply proc vs)))
	((current-guardian) r)
	r)))

  ;; Objects
  (define build-object
    (make-new-reference-maker (make-foreign-procedure ((__varargs_after 1)) "Py-BuildValue" (string) void*)))
  (define object-set!
    (make-foreign-procedure "PyObject-SetItem" (void* void* void*) int))
  (define object-remove!
    (make-foreign-procedure "PyObject-DelItem" (void* void*) int))
  (define object-ref
    (make-new-reference-maker (make-foreign-procedure "PyObject-GetItem" (void* void*) void*)))
  (define object-length
    (make-foreign-procedure "PyObject-Length" (void*) ssize_t))
  (define object-has-attr?
    (make-predicate (make-foreign-procedure "PyObject-HasAttrString" (void* string) int)))
  (define object-get-attr
    (make-new-reference-maker (make-foreign-procedure "PyObject-GetAttrString" (void* string) void*)))
  (define object-set-attr!
    (make-foreign-procedure "PyObject-SetAttrString" (void* string void*) int))
  (define true?
    (make-predicate (make-foreign-procedure "PyObject-IsTrue" (void*) int)))
  (define false?
    (make-predicate (make-foreign-procedure "PyObject-Not" (void*) int)))

  ;; Exceptions
  (define get-current-exception
    (make-new-reference-maker (make-procedure "PyErr_GetRaisedException" () void*)))
  (define exception-match
    (make-predicate (make-foreign-procedure "PyErr_GivenExceptionMatches" (void* void*) int)))
  (define exception-clear
    (make-foreign-procedure "PyErr-Clear" () void))
  )

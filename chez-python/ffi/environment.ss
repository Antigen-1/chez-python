(library (chez-python ffi environment)
  (export setup-environment)
  (import (for (chezscheme) run expand)
	  (chez-python utilities)
	  (for (chez-python exn) run expand))

  (define cache #f)

  ;;Names
  (define basic-names
    (environment-symbols (environment '(chezscheme))))
  (define primitive-names
    '(failure?
      initialize-python
      python-initialized?
      finalize-python
      increase-refcnt
      decrease-refcnt
      current-python-guardian
      current-alloc-guardian
      make-new-reference-maker
      foreign-alloc/auto-free
      object-set!
      object-remove!
      object-ref
      object-length
      object-has-attr?
      object-get-attr
      object-set-attr!
      true?
      false?
      get-constant
      get-current-exception
      exception-match?
      exception-clear!
      pyimport
      call
      ))
  (define complicated-macro-names '(make-object-builder make-object-parser))
  (define type-names '(pycomplex))
  (define exported-names
    (append basic-names primitive-names complicated-macro-names type-names))
  
  ;; Implementations
  ;; python must be loaded before running this function
  (define (obs:setup-environment)
    ;; Basic Environment
    (define env
      (copy-environment
       (environment
	'(for (chezscheme) run expand)
	'(for (chez-python exn) run expand)
	'(chez-python utilities))
       #t))

    (define (register-values names values)
      (for-each
       (lambda (nm val) (eval `(define ,nm ,val) env))
       names values))
    (define (register-syntaxes names transformers)
      (for-each
       (lambda (n t) (eval `(define-syntax ,n ,t) env))
       names transformers))
    (define (register-ftypes names sig)
      (for-each (lambda (n s) `(define-ftype ,n ,s)) names sig))

    ;; Types
    (register-ftypes
     type-names
     '((struct (real double) (imag double))))
    
    ;; Basic Functions and Parameters
    (eval '(define-syntax make-foreign-procedure
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
	  env)
    (register-values
     primitive-names
     '((lambda (n) (or (not n) (eq? n -1)))
       (make-foreign-procedure "Py-Initialize" () void)
       (make-foreign-procedure "Py-IsInitialized" () boolean)
       (make-foreign-procedure "Py-FinalizeEx" () int)
       (make-foreign-procedure "Py-IncRef" (void*) void)
       (make-foreign-procedure "Py-DecRef" (void*) void)
       (make-parameter (make-guardian)
		       (lambda (g)
			 (unless (guardian? g)
			   (raise-contract-error 'current-python-guardian "guardian?" g))
			 g))
       (make-parameter (make-guardian)
		       (lambda (g)
			 (unless (guardian? g)
			   (raise-contract-error 'current-alloc-guardian "guardian?" g))
			 g))
       (lambda (proc)
	 (lambda vs
	   (let ((r (apply proc vs)))
	     ((current-python-guardian) r)
	     r)))
       (lambda (size)
	 (let ((p (foreign-alloc size)))
	   ((current-alloc-guardian) p)
	   p))
       (make-foreign-procedure "PyObject-SetItem" (void* void* void*) int)
       (make-foreign-procedure "PyObject-DelItem" (void* void*) int)
       (make-new-reference-maker (make-foreign-procedure "PyObject-GetItem" (void* void*) void*))
       (make-foreign-procedure "PyObject-Length" (void*) ssize_t)
       (make-foreign-procedure "PyObject-HasAttrString" (void* string) boolean)
       (make-new-reference-maker (make-foreign-procedure "PyObject-GetAttrString" (void* string) void*))
       (make-foreign-procedure "PyObject-SetAttrString" (void* string void*) int)
       (make-foreign-procedure "PyObject-IsTrue" (void*) boolean)
       (make-foreign-procedure "PyObject-Not" (void*) boolean)
       (let ((func (make-new-reference-maker
		    (make-foreign-procedure "Py-GetConstant" (unsigned-int) void*))))
	 (lambda (name)
	   (let ((id
		  (case name
		    ((None) 0)
		    ((False) 1)
		    ((True) 2)
		    ((Ellipsis) 3)
		    ((NotImplemented) 4)
		    ((0) 5)
		    ((1) 6)
		    (("") 7)
		    ((#vu8()) 8)
		    ((()) 9)
		    (else
		     (raise-contract-error
		      'get-constant
		      "(or/c 'None 'False 'True 'Ellipsis 'NotImplemented 0 1 \"\" #vu8() '())"
		      name)))))
	     (func id))))
       (make-new-reference-maker (make-foreign-procedure "PyErr_GetRaisedException" () void*))
       (make-foreign-procedure "PyErr_GivenExceptionMatches" (void* void*) boolean)
       (make-foreign-procedure "PyErr-Clear" () void)
       (make-new-reference-maker
	(make-foreign-procedure "PyImport-ImportModule" (string) void*))
       (make-new-reference-maker
	(make-foreign-procedure "PyObject_Call" (void* void* void*) void*))
       ))

    ;; Complicated Macros for Objects
    (register-syntaxes
     complicated-macro-names
     '((lambda (stx)
	 (syntax-case stx ()
	   ((_ fmt type ...)
	    (let ()
	      (unless (string? (syntax->datum #'fmt))
		(raise-contract-error 'make-object-builder "string?" (syntax->datum #'fmt)))
	      #`(let ((func (make-new-reference-maker
			     (make-foreign-procedure ((__varargs_after 1))
						     "Py_BuildValue" (string type ...) void*))))
		  (lambda vs (apply func fmt vs)))))))
       (lambda (stx)
	 (syntax-case stx ()
	   ((k fmt type ...)
	    (let ()
	      (unless (string? (syntax->datum #'fmt))
		(raise-contract-error 'make-object-parser "string?" (syntax->datum #'fmt)))
	      (let ((pointers (map (lambda (_) (datum->syntax #'k (gensym "slot")))
				   (syntax->list #'(type ...)))))
		#`(let ((func (make-foreign-procedure ((__varargs_after 2)) "PyArg_ParseTuple"
						      (void*
						       string
						       #,@(map
							   (lambda (t) #`(* #,t))
							   (syntax->list #'(type ...))))
						      int)))
		    (lambda (obj)
		      (let (#,@(map (lambda (p t)
				      #`(#,p
					 ;; Coerce to the specific type
					 (make-ftype-pointer
					  #,t
					  (foreign-alloc/auto-free (ftype-sizeof #,t)))))
				    pointers (syntax->list #'(type ...))))
			(if (failure? (func obj fmt #,@pointers))
			    (error 'parse-object "Fail to parse the object: ~a" obj)
			    (void))
			(values #,@pointers)))))))))))

    ;; Setup the garbage collector
    (eval
     '(collect-request-handler
       (lambda ()
	 (collect)
	 (let ((g (current-python-guardian)))
	   (let loop ((x (g)))
	     (when x
	       (decrease-refcnt x)
	       (loop (g)))))
	 (let ((g (current-alloc-guardian)))
	   (let loop ((x (g)))
	     (when x
	       (foreign-free x)
	       (loop (g)))))
	 ))
     env)

    (set! cache env)
    env)

  (define (setup-environment)
    (if cache
	(copy-environment cache #t exported-names)
	(copy-environment (obs:setup-environment) #t exported-names)))
  )

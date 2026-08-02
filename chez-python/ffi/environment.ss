(library (chez-python ffi environment)
  (export setup-environment)
  (import (for (chezscheme) run expand)
	  (for (chez-python exn) expand)
	  (chez-python ffi helper)
	  (chez-python ffi config))

  (define cache #f)

  ;;Names
  (define basic-names
    (environment-symbols (environment '(chezscheme))))
  (define config-names
    '(current-python-guardian
      current-alloc-guardian
      current-thread-state
      current-environment))
  (define primitive-names
    '(failure?
      initialize-python
      python-initialized?
      finalize-python
      increase-refcnt
      decrease-refcnt
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
      child-thread-reset-interp!
      save-thread-state
      restore-thread-state
      clear-thread-state!
      make-thread-state-maker
      new-thread-state
      swap-thread-state
      get-current-thread-state
      delete-thread-state!
      delete-current-thread-state!
      thread-state-get-interp
      ))
  (define complicated-macro-names '(make-object-builder make-object-parser))
  (define type-names '(pycomplex))
  (define exported-names
    (append basic-names config-names primitive-names complicated-macro-names type-names))
  
  ;; Implementations
  ;; python must be loaded before running this function
  (define (obs:setup-environment)
    ;; Basic Environment
    (define env
      (copy-environment
       (environment '(chezscheme))
       #t))

    (define (register-values names values)
      (map
       (lambda (nm val) `(define ,nm ,val))
       names values))
    (define (register-syntaxes names transformers)
      (map
       (lambda (n t) `(define-syntax ,n ,t))
       names transformers))
    (define (register-ftypes names sig)
      (map (lambda (n s) `(define-ftype ,n ,s)) names sig))

    (eval
     `(library (python-c-api)
	(export ,@exported-names)
	(import (for (chezscheme) run expand)
		(for (chez-python exn) expand)
		(chez-python ffi helper)
		(chez-python ffi config))
       ;; Types
	,@(register-ftypes
	   type-names
	   '((struct (real double) (imag double))))
      
	;; Basic Functions and Parameters
	,@(register-values
	   primitive-names
	   '((lambda (n) (or (not n) (eq? n -1)))
	     (make-foreign-procedure "Py-Initialize" () void)
	     (make-foreign-procedure "Py-IsInitialized" () boolean)
	     (make-foreign-procedure "Py-FinalizeEx" () int)
	     (make-foreign-procedure "Py-IncRef" (void*) void)
	     (make-foreign-procedure "Py-DecRef" (void*) void)
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
	     (make-foreign-procedure "PyOS_AfterFork_Child" () void)
	     (make-foreign-procedure "PyEval_SaveThread" () void*)
	     (make-foreign-procedure "PyEval_RestoreThread" (void*) void)
	     (make-foreign-procedure "PyThreadState_Clear" (void*) void)
	     (lambda (proc)
	       (lambda vs
		 (let ((r (apply proc vs)))
		   (exit-handler
		    (let ((handler (exit-handler)))
		      (lambda args
       			(clear-thread-state! r)
			(let ((cur (get-current-thread-state)))
			  (if (and cur (= (ftype-pointer-address cur) (ftype-pointer-address r)))
			      (delete-current-thread-state! r)
			      (delete-thread-state! r)))
			(apply handler args))))
		   r)))
	     (make-thread-state-maker (make-foreign-procedure "PyThreadState_New" (void*) void*))
	     (make-foreign-procedure "PyThreadState_Swap" (void*) void*)
	     (make-foreign-procedure "PyThreadState_GetUnchecked" () void*)
	     (make-foreign-procedure "PyThreadState_Delete" (void*) void)
	     (make-foreign-procedure "PyThreadState_DeleteCurrent" () void)
	     (make-foreign-procedure "PyThreadState_GetInterpreter" (void*) void*)
	     ))
	
	;; Complicated Macros for Objects
	,@(register-syntaxes
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
	(collect-request-handler
	 (let ((collect-guardian
		(lambda (g free)
		  (let loop ((x (g)))
		    (when x
		      (free x)
		      (loop (g))))))
	       (handler (collect-request-handler)))
	   (lambda ()
	     (handler)
	     (collect-guardian (current-python-guardian) decrease-refcnt)
	     (collect-guardian (current-alloc-guardian) foreign-free)))))
     env)

    (let ((real-env (eval '(environment '(python-c-api)) env)))
      (set! cache real-env)
      real-env))

  (define (setup-environment)
    (if cache
	(copy-environment cache #t)
	(copy-environment (obs:setup-environment) #t)))
  )

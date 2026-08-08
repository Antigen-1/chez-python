(library (chez-python ffi environment)
  (export setup-environment)
  (import (for (chezscheme) run expand)
	  (for (chez-python exn) expand)
	  (chez-python ffi helper)
	  (chez-python ffi config)
	  (rnrs conditions))

  (define cache #f)

  ;;Names
  (define basic-names
    (environment-symbols (environment '(chezscheme) '(chez-python exn) '(rnrs conditions))))
  (define config-names
    '(current-python-guardian
      current-alloc-guardian
      current-thread-state
      current-environment))
  (define primitive-names
    '(initialize-python
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
      mapping-keys
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
      get-current-interp
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
		(chez-python ffi config)
		(rnrs conditions))

	(define simple-ret-checker/int
	  (let ((checker
		 (make-ret-checker
		  (lambda (n) (not (= n 0))))))
	    (lambda (proc name)
	      (checker proc name 'internal-error "Unknown internal errors"))))
	(define simple-ret-checker/PyObj
	  (let ((checker
		 (make-ret-checker
		  (lambda (t) (= 0 (tagged-pointer-ptr t))))))
	    (lambda (proc name)
	      (checker proc name 'internal-error "Unknown internal errors"))))
	(define simple-ret-checker/bool
	  (let ((checker (make-ret-checker not)))
	    (lambda (proc name)
	      (checker proc name 'internal-error "Unknown internal errors"))))
	
       ;; Types
	,@(register-ftypes
	   type-names
	   '((struct (real double) (imag double))))
      
	;; Basic Functions and Parameters
	,@(register-values
	   primitive-names
	   '((make-foreign-procedure "Py-Initialize" () void)
	     (make-foreign-procedure "Py-IsInitialized" () boolean)
	     (simple-ret-checker/int (make-foreign-procedure "Py-FinalizeEx" () int)
				     'finialize-python)
	     (t:-> (make-foreign-procedure "Py-IncRef" (void*) void) (PyObj) _)
	     (t:-> (make-foreign-procedure "Py-DecRef" (void*) void) (PyObj) _)
	     (lambda (proc)
	       (lambda vs
		 (let ((r (apply proc vs)))
		   ((current-python-guardian) r)
		   r)))
	     (lambda (size)
	       (let ((p (foreign-alloc size)))
		 ((current-alloc-guardian) p)
		 p))
	     (simple-ret-checker/int
	      (t:-> (make-foreign-procedure "PyObject-SetItem" (void* void* void*) int)
		    (PyObj PyObj PyObj) _)
	      'object-set!)
	     (simple-ret-checker/int
	      (t:-> (make-foreign-procedure "PyObject-DelItem" (void* void*) int)
		    (PyObj PyObj) _)
	      'object-remove!)
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyObject-GetItem" (void* void*) void*)
		     (PyObj PyObj) PyObj))
	      'object-ref)
	     (t:-> (make-foreign-procedure "PyObject-Length" (void*) ssize_t)
		   (PyObj) _)
	     (t:-> (make-foreign-procedure "PyObject-HasAttrString" (void* string) boolean)
		   (PyObj _) _)
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyObject-GetAttrString" (void* string) void*)
		     (PyObj _) PyObj))
	      'object-get-attr)
	     (simple-ret-checker/int
	      (t:-> (make-foreign-procedure "PyObject-SetAttrString" (void* string void*) int)
		    (PyObj _ PyObj) _)
	      'object-set-attr!)
	     (t:-> (make-foreign-procedure "PyObject-IsTrue" (void*) boolean)
		   (PyObj) _)
	     (t:-> (make-foreign-procedure "PyObject-Not" (void*) boolean)
		   (PyObj) _)
	     (let ((func
		    (simple-ret-checker/PyObj
		     (make-new-reference-maker
		      (t:-> (make-foreign-procedure "Py-GetConstant" (unsigned-int) void*)
			    (_) PyObj))
		     'get-constant)))
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
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyMapping-Keys" (void*) void*)
		     (PyObj)
		     PyObj))
	      'mapping-keys)
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyErr_GetRaisedException" () void*)
		     () PyObj))
	      'get-current-exception)
	     (t:-> (make-foreign-procedure "PyErr_GivenExceptionMatches" (void* void*) boolean)
		   (PyObj PyObj) _)
	     (make-foreign-procedure "PyErr-Clear" () void)
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyImport-ImportModule" (string) void*)
		     (_) PyObj))
	      'pyimport)
	     (simple-ret-checker/PyObj
	      (make-new-reference-maker
	       (t:-> (make-foreign-procedure "PyObject_Call" (void* void* void*) void*)
		     (PyObj PyObj PyObj) PyObj))
	      'call)
	     (make-foreign-procedure "PyOS_AfterFork_Child" () void)
	     (t:-> (make-foreign-procedure "PyEval_SaveThread" () void*)
		   () PyThreadState)
	     (t:-> (make-foreign-procedure "PyEval_RestoreThread" (void*) void)
		   (PyThreadState) _)
	     (t:-> (make-foreign-procedure "PyThreadState_Clear" (void*) void)
		   (PyThreadState) _)
	     (lambda (proc)
	       (lambda vs
		 (let ((r (apply proc vs)))
		   (exit-handler
		    (let ((handler (exit-handler)))
		      (lambda args
       			(clear-thread-state! r)
			(let ((cur (get-current-thread-state)))
			  (if (and cur
				   (=
				    (tagged-pointer-ptr cur)
				    (tagged-pointer-ptr r)))
			      (delete-current-thread-state!)
			      (delete-thread-state! r)))
			(apply handler args))))
		   r)))
	     (make-thread-state-maker
	      (t:-> (make-foreign-procedure "PyThreadState_New" (void*) void*)
		    (PyInterpreterState) PyThreadState))
	     (t:-> (make-foreign-procedure "PyThreadState_Swap" (void*) void*)
		   (PyThreadState) PyThreadState)
	     (t:-> (make-foreign-procedure "PyThreadState_GetUnchecked" () void*)
		   () PyThreadState)
	     (t:-> (make-foreign-procedure "PyThreadState_Delete" (void*) void)
		   (PyThreadState) _)
	     (make-foreign-procedure "PyThreadState_DeleteCurrent" () void)
	     (let ((proc
		    (t:-> (make-foreign-procedure "PyThreadState_GetInterpreter" (void*) void*)
			  (PyThreadState) PyInterpreterState)))
	       (lambda ()
		 (let ((st (get-current-thread-state)))
		   (if (= 0 (tagged-pointer-ptr st))
		       (raise-contract-error 'get-current-interp
					     "An attached thread state"
					     st))
		   (proc st))))
	     ))
	
	;; Complicated Macros for Objects
	,@(register-syntaxes
	   complicated-macro-names
	   '((lambda (stx)
	       (syntax-case stx ()
		 ((_ fmt type ...)
		  (let ((tagged? (lambda (t) (and (list? t) (eq? (car t) 'tag) (symbol? (cadr t)) (null? (cddr t)))))
			(get-tag (lambda (t) (cadr t))))
		    (unless (string? (syntax->datum #'fmt))
		      (raise-contract-error 'make-object-builder "string?" (syntax->datum #'fmt)))
		    #`(let ((func
			     (simple-ret-checker/PyObj
			      (make-new-reference-maker
			       (t:->
			       (make-foreign-procedure ((__varargs_after 1))
						       "Py_BuildValue"
						       (string #,@(map (lambda (ts) (if (tagged? (syntax->datum ts))
											#'void*
											ts))
								       (syntax->list #'(type ...))))
						       void*)
			       (#,@(map (lambda (t) (if (tagged? t) (datum->syntax #'k (get-tag t)) #'_))
					(cons 'string (syntax->datum #'(type ...)))))
			       PyObj))
			      'build-object)))
			(lambda vs
			  (apply func fmt vs)))))))
	     (lambda (stx)
	       (syntax-case stx ()
		 ((k fmt type ...)
		  (let ()
		    (unless (string? (syntax->datum #'fmt))
		      (raise-contract-error 'make-object-parser "string?" (syntax->datum #'fmt)))
		    (let ((pointers (map (lambda (_) (datum->syntax #'k (gensym "slot")))
					 (syntax->list #'(type ...)))))
		      #`(let ((func
			       (simple-ret-checker/bool
				(t:->
				 (make-foreign-procedure ((__varargs_after 2)) "PyArg_Parse"
							 (void*
							  string
							  #,@(map
							      (lambda (t) #`(* #,t))
							      (syntax->list #'(type ...))))
							 boolean)
				 (PyObj #,@(map (lambda (_) #'_) (cons 'string (syntax->datum #'(type ...)))))
				 _)
				'parse-object)))
			  (lambda (obj)
			    (let (#,@(map (lambda (p t)
					    #`(#,p
					       ;; Coerce to the specific type
					       (make-ftype-pointer
						#,t
						(foreign-alloc/auto-free (ftype-sizeof #,t)))))
					  pointers (syntax->list #'(type ...))))
			      (func obj fmt #,@pointers)
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

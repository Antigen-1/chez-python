(library (chez-python ffi env api)
  (export initialize-python
	  python-initialized?
	  finalize-python
	  increase-refcnt
	  decrease-refcnt
	  make-new-reference-maker
	  object-set!
	  object-remove!
	  object-ref
	  object-length
	  object-has-attr?
	  object-get-attr
	  object-set-attr!
	  object-type
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

	  make-object-builder make-object-parser

	  pycomplex

	  initialize-python-with-config
	  free-config
	  make-config-maker
	  create-config
	  config-has-option?
	  config-set-string!
	  config-set-int!
	  config-get-string
	  config-get-int
	  config-get-error)
  (import (for (chezscheme) run expand)
	  (for (chez-python exn) expand)
	  (chez-python ffi helper)
	  (chez-python ffi config)
	  (chez-python ffi utility)
	  )
  
  ;; Implementations
  ;; python must be loaded before loading this library
  (define simple-ret-checker/int
    (let ((checker
	   (make-ret-checker
	    (lambda (n) (not (= n 0)))
	    raise-python-runtime-error)))
      (lambda (proc name)
	(checker proc name 'internal-error "Unknown internal errors"))))
  (define simple-ret-checker/PyObj
    (let ((checker
	   (make-ret-checker
	    (lambda (t) (= 0 (tagged-pointer-ptr t)))
	    raise-python-runtime-error)))
      (lambda (proc name)
	(checker proc name 'internal-error "Unknown internal errors"))))
  (define simple-ret-checker/bool
    (let ((checker (make-ret-checker not raise-python-runtime-error)))
      (lambda (proc name)
	(checker proc name 'internal-error "Unknown internal errors"))))
  (define config-ret-checker/PyInitConfig
    (let ((checker (make-ret-checker (lambda (t) (= 0 (tagged-pointer-ptr t)))
				     raise-python-config-error)))
      (lambda (proc name)
	(checker proc name 'internal-error "Unknown internal errors"))))
  (define config-ret-checker/int
    (let ((checker
	   (make-ret-checker
	    (lambda (n) (not (= n 0)))
	    raise-python-config-error)))
      (lambda (proc name)
	(checker proc name 'internal-error "Unknown internal errors"))))
  
  ;; Types
  (define-ftype pycomplex (struct (real double) (imag double)))
  
  ;; Basic Functions and Parameters
  (define initialize-python (make-foreign-procedure "Py-Initialize" () void))
  (define python-initialized? (make-foreign-procedure "Py-IsInitialized" () boolean))
  (define finalize-python (simple-ret-checker/int (make-foreign-procedure "Py-FinalizeEx" () int)
						  'finialize-python))
  (define increase-refcnt (t:-> (make-foreign-procedure "Py-IncRef" (void*) void) (PyObj) _))
  (define decrease-refcnt (t:-> (make-foreign-procedure "Py-DecRef" (void*) void) (PyObj) _))
  (define make-new-reference-maker
    (lambda (proc)
      (lambda vs
	(let ((r (apply proc vs)))
	  ((current-python-guardian) r)
	  r))))
  (define object-set!
    (simple-ret-checker/int
     (t:-> (make-foreign-procedure "PyObject-SetItem" (void* void* void*) int)
	   (PyObj PyObj PyObj) _)
     'object-set!))
  (define object-remove!
    (simple-ret-checker/int
     (t:-> (make-foreign-procedure "PyObject-DelItem" (void* void*) int)
	   (PyObj PyObj) _)
     'object-remove!))
  (define object-ref
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyObject-GetItem" (void* void*) void*)
	    (PyObj PyObj) PyObj))
     'object-ref))
  (define object-length
    (t:-> (make-foreign-procedure "PyObject-Length" (void*) ssize_t)
	  (PyObj) _))
  (define object-has-attr?
    (t:-> (make-foreign-procedure "PyObject-HasAttrString" (void* string) boolean)
	  (PyObj _) _))
  (define object-get-attr
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyObject-GetAttrString" (void* string) void*)
	    (PyObj _) PyObj))
     'object-get-attr))
  (define object-set-attr!
    (simple-ret-checker/int
     (t:-> (make-foreign-procedure "PyObject-SetAttrString" (void* string void*) int)
	   (PyObj _ PyObj) _)
     'object-set-attr!))
  (define object-type
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyObject_Type" (void*) void*)
	    (PyObj) PyObj))
     'object-type))
  (define true?
    (t:-> (make-foreign-procedure "PyObject-IsTrue" (void*) boolean)
	  (PyObj) _))
  (define false?
    (t:-> (make-foreign-procedure "PyObject-Not" (void*) boolean)
	  (PyObj) _))
  (define get-constant
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
	  (func id)))))
  (define mapping-keys
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyMapping-Keys" (void*) void*)
	    (PyObj)
	    PyObj))
     'mapping-keys))
  (define get-current-exception
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyErr_GetRaisedException" () void*)
	    () PyObj))
     'get-current-exception))
  (define exception-match?
    (t:-> (make-foreign-procedure "PyErr_GivenExceptionMatches" (void* void*) boolean)
	  (PyObj PyObj) _))
  (define exception-clear!
    (make-foreign-procedure "PyErr-Clear" () void))
  (define pyimport
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyImport-ImportModule" (string) void*)
	    (_) PyObj))
     'pyimport))
  (define call
    (simple-ret-checker/PyObj
     (make-new-reference-maker
      (t:-> (make-foreign-procedure "PyObject_Call" (void* void* void*) void*)
	    (PyObj PyObj PyObj) PyObj))
     'call))
  (define child-thread-reset-interp!
    (make-foreign-procedure "PyOS_AfterFork_Child" () void))
  (define save-thread-state
    (t:-> (make-foreign-procedure "PyEval_SaveThread" () void*)
	  () PyThreadState))
  (define restore-thread-state
    (t:-> (make-foreign-procedure "PyEval_RestoreThread" (void*) void)
	  (PyThreadState) _))
  (define clear-thread-state!
    (t:-> (make-foreign-procedure "PyThreadState_Clear" (void*) void)
	  (PyThreadState) _))
  (define make-thread-state-maker
    (lambda (proc)
      (lambda vs
	(let ((r (apply proc vs))
	      (p (current-thread-state-pool)))
	  (current-thread-state-pool (cons r p))
	  r))))
  (define new-thread-state
    (make-thread-state-maker
     (t:-> (make-foreign-procedure "PyThreadState_New" (void*) void*)
	   (PyInterpreterState) PyThreadState)))
  (define swap-thread-state
    (t:-> (make-foreign-procedure "PyThreadState_Swap" (void*) void*)
	  (PyThreadState) PyThreadState))
  (define get-current-thread-state
    (t:-> (make-foreign-procedure "PyThreadState_GetUnchecked" () void*)
	  () PyThreadState))
  (define delete-thread-state!
    (t:-> (make-foreign-procedure "PyThreadState_Delete" (void*) void)
	  (PyThreadState) _))
  (define delete-current-thread-state!
    (make-foreign-procedure "PyThreadState_DeleteCurrent" () void))
  (define get-current-interp
    (let ((proc
	   (t:-> (make-foreign-procedure "PyThreadState_GetInterpreter" (void*) void*)
		 (PyThreadState) PyInterpreterState)))
      (lambda ()
	(let ((st (get-current-thread-state)))
	  (if (= 0 (tagged-pointer-ptr st))
	      (raise-contract-error 'get-current-interp
				    "An attached thread state"
				    st))
	  (proc st)))))
	
  ;; Complicated Macros for Objects
  (define-syntax make-object-builder
    (lambda (stx)
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
		 (apply func fmt vs))))))))
  (define-syntax make-object-parser
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
		     (values #,@pointers))))))))))

  (define python-3-14? (>= (cadr (current-python-version)) 14))
	
  ;; Python 3.14 features
  (define initialize-python-with-config
    (and
     python-3-14?
     (config-ret-checker/int
      (t:-> (make-foreign-procedure "Py_InitializeFromInitConfig" (void*) int)
	    (PyInitConfig) _)
      'initialize-python-with-config)))
  (define free-config
    (and python-3-14?
	 (t:-> (make-foreign-procedure "PyInitConfig_Free" (void*) void)
	       (PyInitConfig) _)))
  (define make-config-maker
    (and python-3-14?
	 (lambda (proc)
	   (lambda vs
	     (let ((r (apply proc vs))
		   (l (current-init-config-pool)))
	       (current-init-config-pool (cons r l))
	       r)))))
  (define create-config
    (and python-3-14?
	 (config-ret-checker/PyInitConfig
	  (make-config-maker
	   (t:-> (make-foreign-procedure "PyInitConfig_Create" () void*)
		 () PyInitConfig))
	  'create-config)))
  (define config-has-option?
    (and python-3-14?
	 (t:-> (make-foreign-procedure "PyInitConfig_HasOption" (void* string) boolean)
	       (PyInitConfig _) _)))
  (define config-set-string!
    (and python-3-14?
	 (config-ret-checker/int
	  (t:-> (make-foreign-procedure "PyInitConfig_SetStr" (void* string string) int)
		(PyInitConfig _ _) _)
	  'config-set-string!)))
  (define config-set-int!
    (and python-3-14?
	 (config-ret-checker/int
	  (t:-> (make-foreign-procedure "PyInitConfig_SetInt" (void* string integer-64) int)
		(PyInitConfig _ _) _)
	  'config-set-int!)))
  (define config-get-string
    (and python-3-14?
	 (let ((config-get-string
		(config-ret-checker/int
		 (t:-> (make-foreign-procedure "PyInitConfig_GetStr"
					       (void* string (* c-string))
					       int)
		       (PyInitConfig _ _) _)
		 'config-get-string)))
	   (lambda (config name)
	     (call-with-new-c-string
	      (lambda (slot)
		(config-get-string config name slot))
	      (make-transcoder (utf-8-codec)))))))
  (define config-get-int
    (and python-3-14?
	 (let ((config-get-int
		(config-ret-checker/int
		 (t:-> (make-foreign-procedure "PyInitConfig_GetInt"
					       (void* string (* integer-64))
					       int)
		       (PyInitConfig _ _) _)
		 'config-get-int)))
	   (lambda (config name)
	     (call-with-new-c-int-64
	      (lambda (slot)
		(config-get-int config name slot)))))))
  (define config-get-error
    (and python-3-14?
	 (let ((config-get-error
		(t:-> (make-foreign-procedure "PyInitConfig_GetError"
					      (void* (* c-string))
					      int)
		      (PyInitConfig _) _)))
	   (lambda (config)
	     (call-with-new-c-string
	      (lambda (slot)
		(config-get-error config slot))
	      (make-transcoder (utf-8-codec)))))))
	
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
       (collect-guardian (current-python-guardian) decrease-refcnt))))
  (exit-handler
   (let ((handler (exit-handler)))
     (lambda args
       (for-each
	(lambda (r)
	  (clear-thread-state! r)
	  (let ((cur (get-current-thread-state)))
	    (if (and cur
		     (=
		      (tagged-pointer-ptr cur)
		      (tagged-pointer-ptr r)))
		(delete-current-thread-state!)
		(delete-thread-state! r))))
	(current-thread-state-pool))
       (and python-3-14?
	    (for-each
	     (lambda (c)
	       (free-config c))
	     (current-init-config-pool)))
       (apply handler args)))))

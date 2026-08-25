(library (chez-python ffi env function)
  (export with-python-runtime-handler call-with-new-config pyapply)
  (import (for (chezscheme) run expand) (chez-python exn) (chez-python ffi config)
	  (chez-python ffi env api) (chez-python ffi env coerce))

  (define python-3-14?
    (>= (cadr (current-python-version))
	14))
  
  (define (pyapply proc vs)
    (unless (list? vs)
      (raise-contract-error 'pyapply "list?" vs))
    (->scm-datum
     (call proc
	   (->py-datum (list->vector vs))
	   (make-empty-py-dict))))
  
  (define-syntax (with-python-runtime-handler stx)
    (syntax-case stx ()
      ((_ handler body0 body ...)
       #'(guard
	     (exn (python-runtime-condition?
		   (let ((cur (get-current-exception)))
		     (exception-clear!)
		     (handler exn cur))))
	   body0 body ...))))
  (define call-with-new-config
    (and python-3-14?
	 (lambda (proc)
	   (let ((c
		  (parameterize ((current-init-config-pool '()))
		    (create-config))))
	     (dynamic-wind
	       void
	       (lambda ()
		 (guard (exn (python-config-condition?
			      (raise-python-config-error
			       (condition-who exn)
			       (python-condition-type exn)
			       "~a"
			       (config-get-error c))))
		   (proc c)))
	       (lambda ()
		 (free-config c))))))))

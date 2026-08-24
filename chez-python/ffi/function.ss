(library (chez-python ffi function)
  (export enable-function-library)
  (import (for (chezscheme) run expand) (chez-python exn) (chez-python ffi config))

  (define (enable-function-library)
    (define env (current-environment))
    (eval
     `(library (python-c-function)
	(export with-python-runtime-handler call-with-new-config pyapply)
	(import (for (chezscheme) run expand) (chez-python exn) (python-c-api) (python-c-coerce))

	(define (pyapply proc vs)
	  (unless (list? vs)
	    (raise-contract-error 'pyapply "list?" vs))
	  (->scm-datum
	   (call proc
		 (->py-datum (list->vector vs))
		 (make-empty-py-dict))))
	
	(define-syntax (with-python-runtime-handler stx)
	  (syntax-case stx ()
	    ((_ handler body)
	     #'(guard
		   (exn (python-runtime-condition?
			 (let ((cur (get-current-exception)))
			   (exception-clear!)
			   (handler exn cur))))
		 body))))
	,(let ((ver (current-python-version)))
	   (if (>= (cadr ver) 14)
	       `(define (call-with-new-config proc)
		  (let ((c (create-config)))
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
			(free-config c)))))
	       `(define call-with-new-config #f))))
     env)
    'python-c-function))

(library (chez-python ffi function)
  (export enable-function-library)
  (import (for (chezscheme) run expand) (chez-python exn) (chez-python ffi config))

  (define (enable-function-library)
    (define env (current-environment))
    (eval
     '(library (python-c-function)
	(export with-python-handler pyapply)
	(import (for (chezscheme) run expand) (chez-python exn) (python-c-api) (python-c-coerce))

	(define (pyapply proc vs)
	  (unless (list? vs)
	    (raise-contract-error 'pyapply "list?" vs))
	  (call proc
		(->py-datum (list->vector vs))
		(make-empty-py-dict)))
	
	(define-syntax (with-python-handler stx)
	  (syntax-case stx ()
	    ((_ handler body)
	     #'(guard
		   (exn (python-condition?
			 (let ((cur (get-current-exception)))
			   (exception-clear!)
			   (handler exn cur))))
		 body)))))
     env)
    'python-c-function))

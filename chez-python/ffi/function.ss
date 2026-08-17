(library (chez-python ffi function)
  (export enable-function-library)
  (import (for (chezscheme) run expand) (chez-python exn) (chez-python ffi config))

  (define (enable-function-library)
    (eval
     '(library (python-c-function)
	(export with-python-handler pyapply)
	(import (for (chezscheme) run expand) (chez-python exn) (python-c-api) (python-c-coerce))

	(define (pyapply proc vs)
	  (call proc (->py-tuple vs) (make-empty-py-dict)))
	
	(define-syntax (with-python-handler stx)
	  (syntax-case stx ()
	    ((_ handler body)
	     #'(guard
		   (exn (python-condition?
			 (let ((cur (get-current-exception)))
			   (exception-clear!)
			   (handler exn cur))))
		 body)))))
     (current-environment))))

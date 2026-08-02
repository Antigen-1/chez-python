(library (chez-python ffi config)
  (export
   current-python-guardian
   current-alloc-guardian
   current-thread-state
   current-environment
   )
  (import (chezscheme) (chez-python exn) (chez-python ffi helper))
  
  (define current-python-guardian
    (make-parameter (make-guardian)
		    (lambda (g)
		      (unless (guardian? g)
			(raise-contract-error 'current-python-guardian "guardian?" g))
		      g)))
  (define current-alloc-guardian
    (make-parameter (make-guardian)
		    (lambda (g)
		      (unless (guardian? g)
			(raise-contract-error 'current-alloc-guardian "guardian?" g))
		      g)))
  (define current-thread-state
    (make-thread-parameter
     #f
     (lambda (v)
       (unless (or (not v) (and (tagged-pointer? v) (eq? (tagged-pointer-tag v) 'PyThreadState)))
	 (raise-contract-error 'current-thread-state "(or/c #f PyThreadState*)" v))
       v)))
  (define current-environment
    (make-parameter
     #f
     (lambda (v)
       (unless (or (not v) (environment? v))
	 (raise-contract-error 'current-environment "(or/c #f environment?)" v))
       v)))
  )

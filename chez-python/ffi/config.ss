(library (chez-python ffi config)
  (export
   current-python-guardian
   current-alloc-guardian
   current-thread-state
   current-thread-state-pool
   current-environment
   current-python-version
   current-init-config-pool
   )
  (import (chezscheme) (chez-python exn) (chez-python ffi helper))

  (define current-python-version
    (make-parameter '(3 13)
		    (lambda (v)
		      (unless (and (list? v)
				   (andmap (lambda (n) (and (exact? n) (integer? n))) v)
				   (>= (length v) 2))
			(raise-contract-error
			 'current-python-version
			 "(let ((version? (and/c exact? integer?))) (cons/c version? (cons/c version? (listof version?))))"
			 v))
		      (unless (= (car v) 3)
			(raise-contract-error 'current-python-version "3" (car v)))
		      (unless (>= (cadr v) 13)
			(raise-contract-error 'current-python-version "(>=/c 13)" (cadr v)))
		      v)))
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
  (define current-thread-state-pool
    (make-parameter '()
		    (lambda (l)
		      (unless (list? l)
			(raise-contract-error 'current-thread-state-pool "list?" l))
		      (for-each
		       (lambda (v)
			 (unless (and (tagged-pointer? v) (eq? (tagged-pointer-tag v) 'PyThreadState))
			   (raise-contract-error 'current-thread-state-pool
						 "PyThreadState"
						 v)))
		       l)
		      l)))
  (define current-thread-state
    (make-thread-parameter
     #f
     (lambda (v)
       (unless (or (not v) (and (tagged-pointer? v) (eq? (tagged-pointer-tag v) 'PyThreadState)))
	 (raise-contract-error 'current-thread-state "(or/c #f PyThreadState*)" v))
       v)))
  (define current-init-config-pool
    (make-parameter '()
		    (lambda (l)
		      (unless (list? l)
			(raise-contract-error 'current-init-config-pool "list?" l))
		      (for-each
		       (lambda (v)
			 (unless (and (tagged-pointer? v) (eq? (tagged-pointer-tag v) 'PyInitConfig))
			   (raise-contract-error 'current-init-config-pool "PyInitConfig" v)))
		       l)
		      l)))
  (define current-environment
    (make-parameter
     (copy-environment (environment '(chezscheme)) #t)
     (lambda (v)
       (unless (environment? v)
	 (raise-contract-error 'current-environment "environment?" v))
       v)))
  )

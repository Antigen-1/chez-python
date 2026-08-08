;; This library also serves as an example of writing extensions for chez-python.
(library (chez-python ffi coerce)
  (export enable-coerce-functions)
  (import (chezscheme) (chez-python ffi config) (chez-python exn))

  (define (enable-coerce-functions)
    (let ((env (current-environment)))
      (eval
       '(library (python-c-coerce)
	  (export ->py-int ->scm-int
		  ->py-string ->scm-string
		  ->py-list ->py-tuple ->scm-list)
	  (import (chezscheme)
		  (chez-python exn) (chez-python ffi config) (chez-python ffi helper)
		  (python-c-api))

	  (define-ftype c-string
	    (* unsigned-8))
	  
	  (define ->py-int
	    (let ((builder (make-object-builder "n" ssize_t)))
	      (lambda (n)
		(unless (and (integer? n) (exact? n))
		  (raise-contract-error '->py-int "(and/c integer? exact?)" n))
		(builder n))))
	  (define ->scm-int
	    (let ((parser (make-object-parser "n" ssize_t)))
	      (lambda (o)
		(ftype-ref ssize_t () (parser o)))))
	  (define ->py-string
	    (let ((builder (make-object-builder "s" utf-8)))
	      (lambda (str)
		(unless (or (not str) (string? str))
		  (raise-contract-error '->py-string "(or/c #f string?)" str))
		(builder str))))
	  (define ->scm-string
	    (let ((parser (make-object-parser "s" c-string))
		  (transcoder (make-transcoder (utf-8-codec))))
	      (lambda (o)
		(let* ((p (parser o)))
		  ((lambda (b-list)
		     (bytevector->string (apply bytevector b-list) transcoder))
		   (let loop ((i 0))
		     (let ((cur (ftype-ref c-string (i) p)))
		       (if (= cur 0) '() (cons cur (loop (+ i 1)))))))))))
	  (define ->py-list
	    (let ((make-builder
		   (lambda (n)
		     (eval
		      `(make-object-builder ,(format "[~a]" (apply string-append (make-list n "O")))
					    ,@(make-list n '(tag PyObj)))
		      (current-environment)))))
	      (lambda (l)
		(for-each
		 (lambda (o)
		   (unless (and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))
		     (raise-contract-error '->py-list "(and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))" o)))
		 l)
		(let ((len (length l)))
		  (apply (make-builder len) l)))))
	  (define ->py-tuple
	    (let ((make-builder
		   (lambda (n)
		     (eval
		      `(make-object-builder ,(format "(~a)" (apply string-append (make-list n "O")))
					    ,@(make-list n '(tag PyObj)))
		      (current-environment)))))
	      (lambda (l)
		(for-each
		 (lambda (o)
		   (unless (and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))
		     (raise-contract-error '->py-list "(and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))" o)))
		 l)
		(let ((len (length l)))
		  (apply (make-builder len) l)))))
	  (define ->scm-list
	    (lambda (pl)
	      (let ((len (object-length pl)))
		(let loop ((i 0))
		  (if (= i len)
		      '()
		      (cons (object-ref pl (->py-int i)) (loop (+ i 1)))))))))
       env))))

;; This library also serves as an example of writing extensions for chez-python.
(library (chez-python ffi coerce)
  (export enable-coerce-functions)
  (import (chezscheme) (chez-python ffi config) (chez-python exn))

  (define (enable-coerce-functions)
    (let ((env (current-environment)))
      (eval
       '(library (python-c-coerce)
	  (export ->py-int ->scm-int ->py-double ->scm-double
		  ->py-string ->scm-string
		  ->py-list ->py-tuple ->scm-list ->scm-vector
		  make-empty-py-dict
		  ->py-datum ->scm-datum)
	  (import (chezscheme)
		  (chez-python exn) (chez-python ffi config) (chez-python ffi helper)
		  (python-c-api))

	  (define-ftype c-string
	    (* unsigned-8))

	  (define env (current-environment))
	  
	  (define make-empty-py-dict
	    (make-object-builder "{}"))
	  (define ->py-int
	    (let ((builder (make-object-builder "n" ssize_t)))
	      (lambda (n)
		(unless (and (integer? n) (exact? n))
		  (raise-contract-error '->py-int "(and/c integer? exact?)" n))
		(builder n))))
	  (define ->py-double
	    (let ((builder (make-object-builder "d" double)))
	      (lambda (n)
		(unless (flonum? n)
		  (raise-contract-error '->py-double "flonum?" n))
		(builder n))))
	  (define ->scm-int
	    (let ((parser (make-object-parser "n" ssize_t)))
	      (lambda (o)
		(ftype-ref ssize_t () (parser o)))))
	  (define ->scm-double
	    (let ((parser (make-object-parser "d" double)))
	      (lambda (o)
		(ftype-ref double () (parser o)))))
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
		      env))))
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
		      env))))
	      (lambda (l)
		(for-each
		 (lambda (o)
		   (unless (and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))
		     (raise-contract-error
		      '->py-tuple
		      "(and (tagged-pointer? o) (eq? (tagged-pointer-tag o) 'PyObj))"
		      o)))
		 l)
		(let ((len (length l)))
		  (apply (make-builder len) l)))))
	  (define ->scm-list
	    (lambda (pl)
	      (let ((len (object-length pl)))
		(let loop ((i 0))
		  (if (= i len)
		      '()
		      (cons (object-ref pl (->py-int i)) (loop (+ i 1))))))))
	  (define ->scm-vector
	    (lambda (pt)
	      (let* ((len (object-length pt))
		     (vec (make-vector len)))
		(let loop ((i 0))
		  (if (= i len)
		      (void)
		      (begin
			(vector-set! vec i (object-ref pt (->py-int i)))
			(loop (+ i 1)))))
		vec)))

	  (define (PyObj-not-null? o)
	    (and (tagged-pointer? o)
		 (eq? (tagged-pointer-tag o) 'PyObj)
		 (not (= (tagged-pointer-ptr o) 0))))
	  
	  ;; Comprehensive data transformation functions
	  ;; Dicts are not supported
	  (define (->py-datum o)
	    (let loop ((v o))
	      (cond ((PyObj-not-null? v) v)
		    ((and (integer? v) (exact? v))
		     (->py-int v))
		    ((flonum? v) (->py-double v))
		    ((string? v) (->py-string v))
		    ((boolean? v)
		     (if v (get-constant 'True) (get-constant 'False)))
		    ;; Compound data structure
		    ((list? v) (->py-list (map loop v)))
		    ((vector? v) (->py-tuple (vector->list (vector-map loop v))))
		    (else (raise-contract-error '->py-datum "(or/c PyObj-not-null? (and/c exact? integer?) flonum? string? list? vector?)" v)))))
	  (define ->scm-datum
	    (let* ((b (pyimport "builtins"))
		   (str-type (object-get-attr b "str"))
		   (int-type (object-get-attr b "int"))
		   (float-type (object-get-attr b "float"))
		   (list-type (object-get-attr b "list"))
		   (tuple-type (object-get-attr b "tuple"))
		   (bool-type (object-get-attr b "bool")))
	      (lambda (o)
		(define (PyObj-eq? t1 t2)
		  (= (tagged-pointer-ptr t1)
		     (tagged-pointer-ptr t2)))
		(define (PyObj-type-match? o t)
		  (PyObj-eq? (object-type o) t))
		(unless (PyObj-not-null? o)
		  (raise-contract-error '->scm-datum "PyObj-not-null?" o))
		(let loop ((v o))
		  (cond ((PyObj-type-match? v str-type) (->scm-string v))
			((PyObj-type-match? v int-type) (->scm-int v))
			((PyObj-type-match? v float-type) (->scm-double v))
			((PyObj-type-match? v bool-type) (if (true? v) #t #f))
			;; Compound data structures
			((PyObj-type-match? v list-type) (map loop (->scm-list v)))
			((PyObj-type-match? v tuple-type) (vector-map loop (->scm-vector v)))
			;; Fallback
			(else v)))))))
       env))))

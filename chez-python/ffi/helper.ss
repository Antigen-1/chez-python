(library (chez-python ffi helper)
  (export make-foreign-procedure
	  tagged-pointer? make-tagged-pointer tagged-pointer-tag tagged-pointer-ptr
	  t:->)
  (import (for (chezscheme) run expand)
	  (for (chez-python exn) run expand)
	  (chez-python utilities))

  (define-syntax make-foreign-procedure
    (syntax-rules ()
      ((_ (conv ...) entry (param-type ...) res-type)
       (foreign-procedure
	conv ...
	(string-replace! entry #\- #\_)
	(param-type ...) res-type))
      ((_ entry (param-type ...) res-type)
       (foreign-procedure
	#f
	(string-replace! entry #\- #\_)
	(param-type ...) res-type))))  

  (define-record-type tagged-pointer
    (fields tag ptr)
    (protocol
     (lambda (make)
       (lambda (tag ptr)
	 (unless (symbol? tag)
	   (raise-contract-error 'make-tagged-pointer "symbol?" tag))
	 (unless (or (not ptr) (and (integer? ptr) (exact? ptr)))
	   (raise-contract-error 'make-tagged-pointer "(or/c #f void*)" ptr))
	 (make tag ptr)))))
  (define-syntax (t:-> stx)
    (syntax-case stx ()
      ((k proc (tag1 ...) tag2)
       (let* ((arg-tags (syntax->datum #'(tag1 ...)))
	      (arg-names (map (lambda (tag) (datum->syntax #'k (gensym))) arg-tags)))
	 (for-each
	  (lambda (tag)
	    (unless (symbol? tag)
	      (raise-contract-error 't:-> "symbol?" tag)))
	  arg-tags)
	 #`(lambda (#,@arg-names)
	     (#,(let ((ret-tag (syntax->datum #'tag2)))
		  (if (eq? ret-tag '_)
		      #'(lambda (x) x)
		      #`(lambda (x)
			  (make-tagged-pointer '#,(datum->syntax #'k ret-tag)
					       x))))
	      (proc
	       #,@(map
		   (lambda (tag name)
		     (cond ((eq? tag '_) name)
			   (else
			    #`(let ()
				(unless (tagged-pointer? #,name)
				  (raise-contract-error 't:-> "tagged-pointer?" #,name))
				(let ((exp-tag '#,(datum->syntax #'k tag))
				      (act-tag (tagged-pointer-tag #,name)))
				  (unless (eq? exp-tag act-tag)
				    (raise-contract-error
				     't:->
				     (format "~s" exp-tag)
				     act-tag))
				  (tagged-pointer-ptr #,name))))))
		   arg-tags arg-names)))))))))

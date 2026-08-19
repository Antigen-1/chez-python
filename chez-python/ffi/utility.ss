(library (chez-python ffi utility)
  (export c-string call-with-new-c-string call-with-new-c-int-64
	  foreign-alloc/auto-free)
  (import (chez-python ffi config) (chezscheme))

  (define-ftype c-string (* unsigned-8))

  (define foreign-alloc/auto-free
    (lambda (size)
      (let ((p (foreign-alloc size)))
	((current-alloc-guardian) p)
	p)))
  
  (define (call-with-new-c-string proc transcoder)
    (define slot
      (make-ftype-pointer c-string (foreign-alloc/auto-free (ftype-sizeof c-string))))
    (ftype-set! c-string () slot (make-ftype-pointer unsigned-8 0))
    (proc slot)
    (and (not (= (ftype-pointer-address (ftype-ref c-string () slot)) 0))
	 (let ((bl (let loop ((i 0))
		     (let ((cur (ftype-ref c-string (i) slot)))
		       (if (= cur 0)
			   '()
			   (cons cur (loop (+ i 1))))))))
	   (bytevector->string (apply bytevector bl) transcoder))))
   (define (call-with-new-c-int-64 proc)
     (define slot
       (make-ftype-pointer integer-64 (foreign-alloc/auto-free (ftype-sizeof integer-64))))
     (ftype-set! integer-64 () slot 0)
     (proc slot)
     (ftype-ref integer-64 () slot))

   
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
	(collect-guardian (current-alloc-guardian) foreign-free)))))

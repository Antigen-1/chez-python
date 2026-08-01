(library (ffi functions)
  (export increase-refcnt decrease-refcnt)
  (import (chezscheme) (utilities))

  (define-syntax make-foreign-procedure
    (syntax-rules ()
      ((_ prefix entry (param-type ...) res-type)
       (foreign-procedure
	__collect_safe
	(string-replace! (string-append prefix entry) #\- #\_)
	(param-type ...) res-type))
      ((_ entry (param-type ...) res-type)
       (foreign-procedure
	__collect_safe
	(string-replace! entry #\- #\_)
	(param-type ...) res-type))))
  
  ;; Reference Counting
  (define increase-refcnt
    (make-foreign-procedure "Py-IncRef" (void*) void))
  (define decrease-refcnt
    (make-foreign-procedure "Py-DecRef" (void*) void))

  
  )

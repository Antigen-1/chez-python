(library (chez-python ffi helper)
  (export make-foreign-procedure)
  (import (for (chezscheme) run expand) (chez-python utilities))

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
	(param-type ...) res-type)))))

(library (chez-python exn)
  (export raise-contract-error
	  raise-python-runtime-error
	  raise-python-config-error
	  &python make-python-condition python-condition? python-condition-type
	  &python-runtime make-python-runtime-condition python-runtime-condition?
	  &python-config make-python-config-condition python-config-condition?)
  (import (chezscheme) (rnrs conditions))

  (define-condition-type &python &condition
    make-python-condition python-condition?
    (type python-condition-type))
  (define-condition-type &python-runtime &python
    make-python-runtime-condition python-runtime-condition?)
  (define-condition-type &python-config &python
    make-python-config-condition python-config-condition?)
  
  (define (raise-contract-error who exp act)
    (assertion-violation who (format "Expected: ~a" exp) act))
  (define (raise-python-runtime-error who type fmt . irrs)
    (raise (condition (make-python-runtime-condition type)
		      (make-who-condition who)
		      (make-message-condition fmt)
		      (make-irritants-condition irrs)
		      (make-format-condition))))
  (define (raise-python-config-error who type fmt . irrs)
    (raise (condition (make-python-config-condition type)
		      (make-who-condition who)
		      (make-message-condition fmt)
		      (make-irritants-condition irrs)
		      (make-format-condition))))
  )

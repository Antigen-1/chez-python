(library (chez-python exn)
  (export raise-contract-error
	  raise-python-error
	  &python make-python-condition python-condition? python-condition-type)
  (import (chezscheme) (rnrs conditions))

  (define-condition-type &python &condition
    make-python-condition python-condition?
    (type python-condition-type))
  
  (define (raise-contract-error who exp act)
    (assertion-violation who (format "Expected: ~a" exp) act))
  (define (raise-python-error who type fmt . irrs)
    (raise (condition (make-python-condition type)
		      (make-who-condition who)
		      (make-message-condition fmt)
		      (make-irritants-condition irrs)
		      (make-format-condition)))))

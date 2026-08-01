(library (exn)
  (export raise-contract-error)
  (import (chezscheme))

  (define (raise-contract-error who exp act)
    (assertion-violation who (format "Expected: ~a" exp) act)))

(library (chez-python ffi utilities)
  (export load-python)
  (import (chezscheme))

  (define (load-python)
    (define mt (symbol->string (machine-type)))
    (define l (string-length mt))
    (define os (substring mt (- l 2) l))
    (define obj-name
      (case os
	(("nt") "libpython3.dll")
	(("le") "libpython3.so")
	(("sx") "libpython3.dylib")
	(else (error "libpython3" "unknown platform" mt))))
    (load-shared-object obj-name)))

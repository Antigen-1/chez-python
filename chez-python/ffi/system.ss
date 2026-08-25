(library (chez-python ffi system)
  (export load-python python-version)
  (import (chezscheme) (chez-python utilities) (chez-python ffi helper))

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
    (load-shared-object obj-name))
  (define (python-version)
    (let* ((ver-str
	    (car (string-split ((make-foreign-procedure "Py-GetVersion" () string))
			       #\space)))
	   (ver-prefix (string-prefix ver-str '(#\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\0 #\.)))
	   (ver-nums (map string->number (string-split ver-prefix #\.))))
      ver-nums)))

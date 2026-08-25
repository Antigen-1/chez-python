.PHONY=all, clean

all: chez-python.boot

chez-python.wpo: chez-python.sls chez-python/ffi/*.ss chez-python/*.ss
	echo "(compile-imported-libraries #t) (generate-wpo-files #t) (compile-program \"$<\")" | scheme -q

chez-python.so: chez-python.wpo
	echo "(compile-whole-program \"$<\" \"$@\" #t)" | scheme -q

chez-python.boot: chez-python.so chez-python/ffi/env/api.ss chez-python/ffi/env/function.ss chez-python/ffi/env/coerce.ss
	echo "(make-boot-file \"$@\" '(\"scheme\") \"$<\" \
	       \"chez-python/ffi/env/api.ss\" \
	       \"chez-python/ffi/env/coerce.ss\" \
	       \"chez-python/ffi/env/function.ss\")" | scheme -q

clean:
	-rm -rf *.so *.boot *.wpo
	-rm -rf chez-python/*.wpo chez-python/*.so
	-rm -rf chez-python/ffi/*.wpo chez-python/ffi/*.so
	-rm -rf chez-python/ffi/env/*.so

.POSIX:

DEPS      = norayr/lists    \
	    norayr/Internet \
	    norayr/time     \
	    norayr/irc      \
	    norayr/opts

GITHUB    = https://github.com/

ROOTDIR   = $$PWD

all: ${DEPS}
	@if [ ! -d build ]; then \
		mkdir build;     \
	fi
	@for i in $?; do                                 \
		cp -r   ${ROOTDIR}/build                 \
			${ROOTDIR}/deps/$${i#*/}/build;  \
		make -C ${ROOTDIR}/deps/$${i#*/};        \
		cp -r   ${ROOTDIR}/deps/$${i#*/}/build/* \
			${ROOTDIR}/build/;               \
	done
	@cd build; voc ${ROOTDIR}/../src/vocbot.Mod -m

${DEPS}:
	@for i in $@; do                                          \
		if [ -d deps/$${i#*/} ]; then                     \
			printf "Updating %s: " $${i#*/};          \
			git -C deps/$${i#*/} pull --ff-only       \
				${GITHUB}$$i > /dev/null 2>&1     \
				&& echo done                      \
				|| (echo failed && exit 1);       \
		else                                              \
			printf "Fetching %s: " $${i#*/};          \
			git clone ${GITHUB}$$i deps/$${i#*/}      \
				> /dev/null 2>&1                  \
				&& echo done                      \
				|| (echo failed && exit 1);       \
		fi                                                \
	done

clean:
	rm -rf build deps

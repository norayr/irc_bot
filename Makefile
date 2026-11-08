VOC ?= voc
BUILD ?= build
IRC_DIR ?= $(if $(wildcard ../irc/src/IRC.Mod),../irc,deps/irc)
IRC_SRC = $(abspath $(IRC_DIR)/src/IRC.Mod)

.PHONY: all get_deps tests clean libraries
all: $(BUILD)/vocbot

# VOC supplies the utility, options, list and networking modules.
get_deps:
	@test -f "$(IRC_SRC)" || git clone https://github.com/norayr/irc "$(IRC_DIR)"

libraries:
	$(MAKE) -C "$(IRC_DIR)" BUILD="$(abspath $(BUILD))" VOC="$(VOC)" all

$(BUILD)/vocbot: src/vocbot.Mod libraries
	cd "$(BUILD)" && $(VOC) -m "$(abspath src/vocbot.Mod)"

tests: all
	$(MAKE) -C "$(IRC_DIR)" BUILD="$(abspath $(BUILD))" VOC="$(VOC)" tests
	python3 tests/reconnect.py "$(abspath $(BUILD)/vocbot)"

clean:
	rm -f $(addprefix $(BUILD)/,vocbot vocbot.c vocbot.h vocbot.o vocbot.sym IRC.c IRC.h IRC.o IRC.sym)

VOC ?= voc
BUILD ?= build
IRC_DIR ?= $(if $(wildcard ../irc/src/IRC.Mod),../irc,deps/irc)
IRC_SRC = $(abspath $(IRC_DIR)/src/IRC.Mod)

.PHONY: all get_deps tests clean
all: $(BUILD)/vocbot

# VOC supplies the utility, options, list and networking modules.
get_deps:
	@test -f "$(IRC_SRC)" || git clone https://github.com/norayr/irc "$(IRC_DIR)"

$(BUILD)/IRC.o: $(IRC_SRC)
	mkdir -p "$(BUILD)"
	cd "$(BUILD)" && $(VOC) -s "$(IRC_SRC)"

$(BUILD)/vocbot: src/vocbot.Mod $(BUILD)/IRC.o
	cd "$(BUILD)" && $(VOC) -m "$(abspath src/vocbot.Mod)"

tests: all
	python3 tests/reconnect.py "$(abspath $(BUILD)/vocbot)" "$(IRC_SRC)" "$(VOC)"

clean:
	rm -f $(addprefix $(BUILD)/,vocbot vocbot.c vocbot.h vocbot.o vocbot.sym IRC.c IRC.h IRC.o IRC.sym)

VOC = /opt/voc/bin/voc
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir_path := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ifndef BUILD
BUILD="build"
endif
build_dir_path := $(mkfile_dir_path)/$(BUILD)
build_dir_path := $(mkfile_dir_path)/build
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
BLD := $(mkfile_dir_path)/build
DPD = deps
ifndef DPS
DPS := $(mkfile_dir_path)/$(DPD)
endif
all: get_deps build_deps build_vocbot

get_deps:
		mkdir -p $(DPS)
		if [ -d $(DPS)/lists ]; then cd $(DPS)/lists; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/lists; cd -; fi
		if [ -d $(DPS)/Internet ]; then cd $(DPS)/Internet; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/Internet; cd -; fi
		if [ -d $(DPS)/time ]; then cd $(DPS)/time; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/time; cd -; fi
		if [ -d $(DPS)/irc ]; then cd $(DPS)/irc; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/irc; cd -; fi
		if [ -d $(DPS)/opts ]; then cd $(DPS)/opts; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/opts; cd -; fi

build_deps:
	mkdir -p $(BUILD)
	cd $(BUILD)
	make -f $(DPS)/lists/GNUmakefile BUILD=$(BLD)
	make -f $(DPS)/Internet/GNUmakefile BUILD=$(BLD)
	make -f $(DPS)/time/GNUmakefile BUILD=$(BLD)
	make -f $(DPS)/irc/GNUmakefile BUILD=$(BLD)
	make -f $(DPS)/opts/GNUmakefile BUILD=$(BLD)


build_vocbot:
	cd $(BUILD) && $(VOC) $(mkfile_dir_path)/src/vocbot.Mod -m

clean:
			if [ -d "$(BUILD)" ]; then rm -rf $(BLD); fi

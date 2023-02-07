mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir_path := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
build_dir_path := $(mkfile_dir_path)/build
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
BLD := $(mkfile_dir_path)/build
DPS := $(mkfile_dir_path)/dps

all: get_deps build_deps

get_deps:
		mkdir -p $(mkfile_dir_path)/$(DPS)
		if [ -d $(DPS)/lists ]; then cd $(DPS)/lists; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/lists; cd -; fi
		if [ -d $(DPS)/Internet ]; then cd $(DPS)/Internet; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/Internet; cd -; fi
		if [ -d $(DPS)/time ]; then cd $(DPS)/time; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/time; cd -; fi
		if [ -d $(DPS)/irc ]; then cd $(DPS)/irc; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/irc; cd -; fi
		if [ -d $(DPS)/opts]; then cd $(DPS)/opts; git pull; cd -; else cd $(DPS); git clone https://github.com/norayr/opts; cd -; fi

build_deps:
	mkdir -p $(mkfile_dir_path)
	cd $(CURDIR)/$(BUILD)
	make -f $(mkfile_dir_path)/dps/lists/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/Internet/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/time/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/irc/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/opts/makefile BUILD=$(BLD)
	cd $(BLD) && voc $(mkfile_dir_path)/src/vocbot.Mod -m

clean:
			if [ -d "$(BLD)" ]; then rm -rf $(BLD); fi

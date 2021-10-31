mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir_path := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
build_dir_path := $(mkfile_dir_path)/build
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
BLD := $(mkfile_dir_path)/build

all:
	mkdir -p $(mkfile_dir_path)
	cd $(CURDIR)/$(BUILD)
	make -f $(mkfile_dir_path)/dps/lists/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/Internet/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/time/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/irc/makefile BUILD=$(BLD)
	make -f $(mkfile_dir_path)/dps/getopt/makefile BUILD=$(BLD)
	cd $(BLD) && voc $(mkfile_dir_path)/src/vocbot.Mod -m

clean:
			if [ -d "$(BLD)" ]; then rm -rf $(BLD); fi

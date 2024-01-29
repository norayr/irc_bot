DEPEND = github.com/norayr/strutils github.com/norayr/dbg github.com/norayr/Internet github.com/norayr/lists github.com/norayr/irc github.com/norayr/opts

VOC = /opt/voc/bin/voc
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir_path := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
$(info $$mkfile_path is [${mkfile_path}])
$(info $$mkfile_dir_path is [${mkfile_dir_path}])
ifndef BUILD
BUILD="build"
endif
build_dir_path := $(mkfile_dir_path)/$(BUILD)
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
BLD := $(mkfile_dir_path)/build
DPD  =  deps
ifndef DPS
DPS := $(mkfile_dir_path)/$(DPD)
endif
all: get_deps build_deps buildThis

get_deps:
	@for i in $(DEPEND); do \
			if [ -d "$(DPS)/$${i}" ]; then \
				 cd "$(DPS)/$${i}"; \
				 git pull; \
				 cd - ;    \
				 else \
				 mkdir -p "$(DPS)/$${i}"; \
				 cd "$(DPS)/$${i}"; \
				 cd .. ; \
				 git clone "https://$${i}"; \
				 cd - ; \
			fi; \
	done

build_deps:
	mkdir -p $(BLD)
	cd $(BLD); \
	for i in $(DEPEND); do \
		if [ -f "$(DPS)/$${i}/GNUmakefile" ]; then \
			make -f "$(DPS)/$${i}/GNUmakefile" BUILD=$(BLD); \
		else \
			make -f "$(DPS)/$${i}/Makefile" BUILD=$(BLD); \
		fi; \
	done

buildThis:
	cd $(BUILD) && $(VOC) -m $(mkfile_dir_path)/src/vocbot.Mod

tests:
	#cd $(BUILD) && $(VOC) $(mkfile_dir_path)/test/testList.Mod -m
	#build/testList

clean:
	if [ -d "$(BUILD)" ]; then rm -rf $(BLD); fi

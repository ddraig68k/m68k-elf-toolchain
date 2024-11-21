# =================================================
# Makefile for building m68k gcc
# based on the amiga gcc makefile by bebbo
# =================================================
include disable_implicite_rules.mk
# =================================================
# variables
# =================================================
$(eval SHELL = $(shell which bash 2>/dev/null) ) 

PREFIX ?= /opt/m68k-elf
export PATH := $(PREFIX)/bin:$(PATH)

TARGET ?= m68k-elf

UNAME_S := $(shell uname -s)
BUILD := $(shell pwd)/build-$(UNAME_S)-$(TARGET)
PROJECTS := $(shell pwd)/projects
DOWNLOAD := $(shell pwd)/download
__BUILDDIR := $(shell mkdir -p $(BUILD))
__PROJECTDIR := $(shell mkdir -p $(PROJECTS))
__DOWNLOADDIR := $(shell mkdir -p $(DOWNLOAD))

GCC_VERSION ?= $(shell cat 2>/dev/null $(PROJECTS)/gcc/gcc/BASE-VER)

ifeq ($(UNAME_S), Darwin)
	SED := gsed
else ifeq ($(UNAME_S), FreeBSD)
	SED := gsed
else
	SED := sed
endif

# get git urls and branches from .repos file
$(shell  [ ! -f .repos ] && cp default-repos .repos)
modules := $(shell cat .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f1)
get_url = $(shell grep $(1) .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2)
get_branch = $(shell grep $(1) .repos | $(SED) -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3)
$(foreach modu,$(modules),$(eval $(modu)_URL=$(call get_url,$(modu))))
$(foreach modu,$(modules),$(eval $(modu)_BRANCH=$(call get_branch,$(modu))))

CFLAGS ?= -Os
CXXFLAGS ?= $(CFLAGS)
CFLAGS_FOR_TARGET ?= -O2 -fomit-frame-pointer
CXXFLAGS_FOR_TARGET ?= $(CFLAGS_FOR_TARGET) -fno-exceptions -fno-rtti

E:=CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" CFLAGS_FOR_BUILD="$(CFLAGS)" CXXFLAGS_FOR_BUILD="$(CXXFLAGS)"  CFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)" CXXFLAGS_FOR_TARGET="$(CFLAGS_FOR_TARGET)"

THREADS ?= no

# =================================================
# determine exe extension for cygwin
$(eval MYMAKE = $(shell which $(MAKE) 2>/dev/null) )
$(eval MYMAKEEXE = $(shell which "$(MYMAKE:%=%.exe)" 2>/dev/null) )
EXEEXT:=$(MYMAKEEXE:%=.exe)

# Files for GMP, MPC and MPFR

GMP := gmp-6.1.2
GMPFILE := $(GMP).tar.bz2
MPC := mpc-1.0.3
MPCFILE := $(MPC).tar.gz
MPFR := mpfr-3.1.6
MPFRFILE := $(MPFR).tar.bz2

# =================================================
# pretty output ^^
# =================================================
TEEEE := >&

ifeq ($(sdk),)
__LINIT := $(shell rm .state 2>/dev/null)
endif

$(eval has_flock = $(shell which flock 2>/dev/null))
ifeq ($(has_flock),)
FLOCK := echo >/dev/null
else
FLOCK := $(has_flock)
endif

L0 = @__p=
L00 = __p=
ifneq ($(VERBOSE),)
verbose = $(VERBOSE)
endif
ifeq ($(verbose),)
L1 = ; ($(FLOCK) 200; echo -e \\033[33m$$__p...\\033[0m >>.state; echo -ne \\033[33m$$__p...\\033[0m ) 200>.lock; mkdir -p log; __l="log/$$__p.log" ; (
L2 = )$(TEEEE) "$$__l"; __r=$$?; ($(FLOCK) 200; if (( $$__r > 0 )); then \
  echo -e \\n\\033[K\\033[31m$$__p...failed\\033[0m; \
   $(SED) -n '1,/\*\*\*/p' "$$__l" | tail -n 100; \
  echo -e \\033[31m$$__p...failed\\033[0m; \
  echo -e use \\033[1mless \"$$__l\"\\033[0m to view the full log and search for \*\*\*; \
  else echo -e \\n\\033[K\\033[32m$$__p...done\\033[0m; fi \
  ;grep -v "$$__p" .state >.state0 2>/dev/null; mv .state0 .state ;echo -n $$(cat .state | paste -sd " " -); ) 200>.lock; [[ $$__r -gt 0 ]] && exit $$__r; echo -n ""
else
L1 = ;(
L2 = )
endif

# =================================================
# download files
# =================================================
define get-file
$(L0)"downloading $(1)"$(L1) cd $(DOWNLOAD); \
  mv $(3) $(3).bak; \
  wget $(2) -O $(3).neu; \
  if [ -s $(3).neu ]; then \
    if [ "$$(cmp --silent $(3).neu $(3).bak); echo $$?" == 0 ]; then \
      mv $(3).bak $(3); \
      rm $(3).neu; \
    else \
      mv $(3).neu $(3); \
      rm -f $(3).bak; \
    fi \
  else \
    rm $(3).neu; \
  fi; \
  cd .. $(L2)
endef

# =================================================

.PHONY: x init
x:
	@if [ "$(sdk)" == "" ]; then \
		$(MAKE) help; \
	else \
		$(MAKE) sdk; \
	fi

# =================================================
# help
# =================================================
.PHONY: help
help:
	@echo "make help					display this help"
	@echo "make info					print prefix and other flags"
	@echo "make all 					build and install all"
	@echo "make min 					build and install the minimal to use gcc"
	@echo "make <target>					builds a target: binutils, gcc, vasm, vbcc, vlink, libgcc"
	@echo "make clean					remove the build folder"
	@echo "make clean-<target>				remove the target's build folder"
	@echo "make drop-prefix				remove all content from the prefix folder"
	@echo "make update					perform git pull for all targets"
	@echo "make update-<target>				perform git pull for the given target"
	@echo "make l   					print the last log entry for each project"
	@echo "make b   					print the branch for each project"
	@echo "make r   					print the remote for each project"
	@echo "make v [date=<date>]				checkout all projects for a given date, checkout to branch if no date given"
	@echo "make branch branch=<branch> mod=<module>	switch the module to the given branch"
	@echo ""
	@echo "the optional parameter THREADS=posix will build it with thread support"

# =================================================
# all
# =================================================
.PHONY: all gcc binutils vasm libgcc min
all: gcc binutils vasm libgcc newlib

min: binutils gcc libgcc

# =================================================
# clean
# =================================================
ifneq ($(OWNMPC),)
.PHONY: clean-gmp clean-mpc clean-mpfr
clean: clean-gmp clean-mpc clean-mpfr
endif

.PHONY: drop-prefix clean clean-gcc clean-binutils clean-vasm clean-vbcc clean-vlink clean-libgcc clean-newlib
clean: clean-gcc clean-binutils clean-vasm clean-vbcc clean-vlink clean-newlib clean-gmp clean-mpc clean-mpfr
	rm -rf $(BUILD)
	rm -rf *.log
	mkdir -p $(BUILD)

clean-gcc:
	rm -rf $(BUILD)/gcc

clean-gmp:
	rm -rf $(PROJECTS)/gcc/gmp

clean-mpc:
	rm -rf $(PROJECTS)/gcc/mpc

clean-mpfr:
	rm -rf $(PROJECTS)/gcc/mpfr

clean-libgcc:
	rm -rf $(BUILD)/gcc/$(TARGET)
	rm -rf $(BUILD)/gcc/_libgcc_done

clean-binutils:
	rm -rf $(BUILD)/binutils

clean-vasm:
	rm -rf $(BUILD)/vasm

clean-vbcc:
	rm -rf $(BUILD)/vbcc

clean-vlink:
	rm -rf $(BUILD)/vlink

clean-newlib:
	rm -rf $(BUILD)/newlib

# drop-prefix drops the files from prefix folder
drop-prefix:
	rm -rf $(PREFIX)/bin
	rm -rf $(PREFIX)/etc
	rm -rf $(PREFIX)/info
	rm -rf $(PREFIX)/libexec
	rm -rf $(PREFIX)/lib/gcc
	rm -rf $(PREFIX)/$(TARGET)
	rm -rf $(PREFIX)/man
	rm -rf $(PREFIX)/share
	@mkdir -p $(PREFIX)/bin

# =================================================
# update all projects
# =================================================

.PHONY: update update-gcc update-binutils update-vasm update-vbcc update-vlink update-newlib
update: update-gcc update-binutils update-vasm update-vbcc update-vlink update-newlib

update-gcc: $(PROJECTS)/gcc/configure
	@cd $(PROJECTS)/gcc && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-binutils: $(PROJECTS)/binutils/configure
	@cd $(PROJECTS)/binutils && git pull || (export DEPTH=16; while true; do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH && break; export DEPTH=$$(($$DEPTH+$$DEPTH));done)

update-vasm: $(PROJECTS)/vasm/Makefile
	@cd $(PROJECTS)/vasm && git pull

update-vbcc: $(PROJECTS)/vbcc/Makefile
	@cd $(PROJECTS)/vbcc && git pull

update-vlink: $(PROJECTS)/vlink/Makefile
	@cd $(PROJECTS)/vlink && git pull

update-newlib: $(PROJECTS)/newlib-cygwin/newlib/configure
	@cd $(PROJECTS)/newlib-cygwin && git pull

update-gmp:
	if [ -a $(DOWNLOAD)/$(GMPFILE) ]; \
	then rm -rf $(PROJECTS)/$(GMP); rm -rf $(PROJECTS)/gcc/gmp; \
	else cd $(DOWNLOAD) && wget ftp://ftp.gnu.org/gnu/gmp/$(GMPFILE); \
	fi;
	@cd $(PROJECTS) && tar xf $(DOWNLOAD)/$(GMPFILE)

update-mpc:
	if [ -a $(DOWNLOAD)/$(MPCFILE) ]; \
	then rm -rf projcts/$(MPC); rm -rf $(PROJECTS)/gcc/mpc; \
	else cd $(DOWNLOAD) && wget ftp://ftp.gnu.org/gnu/mpc/$(MPCFILE); \
	fi;
	@cd $(PROJECTS) && tar xf $(DOWNLOAD)/$(MPCFILE)

update-mpfr:
	if [ -a $(DOWNLOAD)/$(MPFRFILE) ]; \
	then rm -rf $(PROJECTS)/$(MPFR); rm -rf $(PROJECTS)/gcc/mpfr; \
	else cd $(DOWNLOAD) && wget ftp://ftp.gnu.org/gnu/mpfr/$(MPFRFILE); \
	fi;
	@cd $(PROJECTS) && tar xf $(DOWNLOAD)/$(MPFRFILE)

# =================================================
# B I N
# =================================================

# =================================================
# binutils
# =================================================
CONFIG_BINUTILS =--prefix=$(PREFIX) --target=$(TARGET) --disable-werror --enable-tui --disable-nls

ifneq (m68k-elf,$(TARGET))
CONFIG_BINUTILS += --disable-plugins
endif

# FreeBSD, OSX : libs added by the command brew install gmp
ifeq (Darwin, $(findstring Darwin, $(UNAME_S)))
	BREW_PREFIX := $$(brew --prefix)
	CONFIG_BINUTILS += --with-libgmp-prefix=$(BREW_PREFIX)
endif

ifeq (FreeBSD, $(findstring FreeBSD, $(UNAME_S)))
	PORTS_PREFIX?=/usr/local
	CONFIG_BINUTILS += --with-libgmp-prefix=$(PORTS_PREFIX)
endif

BINUTILS_CMD := $(TARGET)-addr2line $(TARGET)-ar $(TARGET)-as $(TARGET)-c++filt \
	$(TARGET)-ld $(TARGET)-nm $(TARGET)-objcopy $(TARGET)-objdump $(TARGET)-ranlib \
	$(TARGET)-readelf $(TARGET)-size $(TARGET)-strings $(TARGET)-strip
BINUTILS := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(BINUTILS_CMD))

BINUTILS_DIR := . bfd gas ld binutils opcodes
BINUTILSD := $(patsubst %,$(PROJECTS)/binutils/%, $(BINUTILS_DIR))

binutils: $(BUILD)/binutils/_done

$(BUILD)/binutils/_done: $(BUILD)/binutils/Makefile $(shell find 2>/dev/null $(PROJECTS)/binutils -not \( -path $(PROJECTS)/binutils/.git -prune \) -not \( -path $(PROJECTS)/binutils/gprof -prune \) -type f)
	@touch -t 0001010000 $(PROJECTS)/binutils/binutils/arparse.y
	@touch -t 0001010000 $(PROJECTS)/binutils/binutils/arlex.l
	@touch -t 0001010000 $(PROJECTS)/binutils/ld/ldgram.y
	@touch -t 0001010000 $(PROJECTS)/binutils/intl/plural.y
	$(L0)"make binutils bfd"$(L1)$(MAKE) -C $(BUILD)/binutils all-bfd $(L2)
	$(L0)"make binutils gas"$(L1)$(MAKE) -C $(BUILD)/binutils all-gas $(L2)
	$(L0)"make binutils binutils"$(L1)$(MAKE) -C $(BUILD)/binutils all-binutils $(L2)
	$(L0)"make binutils ld"$(L1)$(MAKE) -C $(BUILD)/binutils all-ld $(L2)
	$(L0)"install binutils"$(L1)$(MAKE) -C $(BUILD)/binutils install-gas install-binutils install-ld $(L2)
	@echo "done" >$@

$(BUILD)/binutils/Makefile: $(PROJECTS)/binutils/configure
	@mkdir -p $(BUILD)/binutils
	$(L0)"configure binutils"$(L1) cd $(BUILD)/binutils && $(E) $(PROJECTS)/binutils/configure $(CONFIG_BINUTILS) $(L2)


$(PROJECTS)/binutils/configure:
	@cd $(PROJECTS) &&	git clone -b $(binutils_BRANCH) --depth 16 $(binutils_URL) binutils

# =================================================
# gcc
# =================================================
CONFIG_GCC = --prefix=$(PREFIX) --target=$(TARGET) --enable-languages=c,c++,$(ADDLANG) --enable-version-specific-runtime-libs --disable-libssp --disable-nls \
	--with-headers=$(PROJECTS)/newlib-cygwin/newlib/libc/include/ --disable-shared --enable-threads=$(THREADS)  \
	--with-stage1-ldflags="-dynamic-libgcc -dynamic-libstdc++" --with-boot-ldflags="-dynamic-libgcc -dynamic-libstdc++"	

# FreeBSD, OSX : libs added by the command brew install gmp mpfr libmpc
ifeq (Darwin, $(findstring Darwin, $(UNAME_S)))
	BREW_PREFIX := $$(brew --prefix)
	CONFIG_GCC += --with-gmp=$(BREW_PREFIX) \
		--with-mpfr=$(BREW_PREFIX) \
		--with-mpc=$(BREW_PREFIX)
endif

ifeq (FreeBSD, $(findstring FreeBSD, $(UNAME_S)))
	PORTS_PREFIX?=/usr/local
	CONFIG_GCC += --with-gmp=$(PORTS_PREFIX) \
		--with-mpfr=$(PORTS_PREFIX) \
		--with-mpc=$(PORTS_PREFIX)
endif

GCC_CMD := $(TARGET)-c++ $(TARGET)-g++ $(TARGET)-gcc-$(GCC_VERSION) $(TARGET)-gcc-nm \
	$(TARGET)-gcov $(TARGET)-gcov-tool $(TARGET)-cpp $(TARGET)-gcc $(TARGET)-gcc-ar \
	$(TARGET)-gcc-ranlib $(TARGET)-gcov-dump
GCC := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(GCC_CMD))

GCC_DIR := . gcc gcc/c gcc/c-family gcc/cp gcc/config/m68k libiberty libcpp libdecnumber
GCCD := $(patsubst %,$(PROJECTS)/gcc/%, $(GCC_DIR))

gcc: $(BUILD)/gcc/_done

$(BUILD)/gcc/_done: $(BUILD)/gcc/Makefile $(shell find 2>/dev/null $(GCCD) -maxdepth 1 -type f )
	$(L0)"make gcc"$(L1) $(MAKE) -C $(BUILD)/gcc all-gcc $(L2)
	$(L0)"install gcc"$(L1) $(MAKE) -C $(BUILD)/gcc install-gcc $(L2)
	@echo "done" >$@

$(BUILD)/gcc/Makefile: $(PROJECTS)/gcc/configure $(BUILD)/binutils/_done
	@mkdir -p $(BUILD)/gcc
ifneq ($(OWNGMP),)
	@mkdir -p $(PROJECTS)/gcc/gmp
	@mkdir -p $(PROJECTS)/gcc/mpc
	@mkdir -p $(PROJECTS)/gcc/mpfr
	@rsync -a --no-group $(PROJECTS)/$(GMP)/* $(PROJECTS)/gcc/gmp
	@rsync -a --no-group $(PROJECTS)/$(MPC)/* $(PROJECTS)/gcc/mpc
	@rsync -a --no-group $(PROJECTS)/$(MPFR)/* $(PROJECTS)/gcc/mpfr
endif
	$(L0)"configure gcc"$(L1) cd $(BUILD)/gcc && $(E) $(PROJECTS)/gcc/configure $(CONFIG_GCC) $(L2)

$(PROJECTS)/gcc/configure:
	@cd $(PROJECTS) &&	git clone -b $(gcc_BRANCH) --depth 16 $(gcc_URL)

# =================================================
# vasm
# =================================================
VASM_CMD := vasmm68k_mot
VASM := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VASM_CMD))

vasm: $(BUILD)/vasm/_done

$(BUILD)/vasm/_done: $(BUILD)/vasm/Makefile
	$(L0)"make vasm"$(L1) $(MAKE) -C $(BUILD)/vasm CPU=m68k SYNTAX=mot $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install vasm"$(L1) install $(BUILD)/vasm/vasmm68k_mot $(PREFIX)/bin/ ;\
	install $(BUILD)/vasm/vobjdump $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vasm/Makefile: $(PROJECTS)/vasm/Makefile $(shell find 2>/dev/null $(PROJECTS)/vasm -not \( -path $(PROJECTS)/vasm/.git -prune \) -type f)
	@rsync -a --no-group $(PROJECTS)/vasm $(BUILD)/ --exclude .git
	@touch $(BUILD)/vasm/Makefile

$(PROJECTS)/vasm/Makefile:
	@cd $(PROJECTS) &&	git clone -b $(vasm_BRANCH) --depth 4 $(vasm_URL)

# =================================================
# vbcc
# =================================================
VBCC_CMD := vbccm68k vprof vc
VBCC := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VBCC_CMD))

vbcc: $(BUILD)/vbcc/_done

$(BUILD)/vbcc/_done: $(BUILD)/vbcc/Makefile
	$(L0)"make vbcc dtgen"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc bin/dtgen $(L2)
	@cd $(BUILD)/vbcc && echo -e "y\\ny\\nsigned char\\ny\\nunsigned char\\nn\\ny\\nsigned short\\nn\\ny\\nunsigned short\\nn\\ny\\nsigned int\\nn\\ny\\nunsigned int\\nn\\ny\\nsigned long long\\nn\\ny\\nunsigned long long\\nn\\ny\\nfloat\\nn\\ny\\ndouble\\n" >c.txt
	$(L0)"run vbcc dtgen"$(L1) cd $(BUILD)/vbcc && bin/dtgen machines/m68k/machine.dt machines/m68k/dt.h machines/m68k/dt.c <c.txt $(L2)
	$(L0)"make vbcc"$(L1) TARGET=m68k $(MAKE) -C $(BUILD)/vbcc $(L2)
	@mkdir -p $(PREFIX)/bin/
	@rm -rf $(BUILD)/vbcc/bin/*.dSYM
	$(L0)"install vbcc"$(L1) install $(BUILD)/vbcc/bin/v* $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vbcc/Makefile: $(PROJECTS)/vbcc/Makefile $(shell find 2>/dev/null $(PROJECTS)/vbcc -not \( -path $(PROJECTS)/vbcc/.git -prune \) -type f)
	@rsync -a --no-group $(PROJECTS)/vbcc $(BUILD)/ --exclude .git
	@mkdir -p $(BUILD)/vbcc/bin
	@touch $(BUILD)/vbcc/Makefile

$(PROJECTS)/vbcc/Makefile:
	@cd $(PROJECTS) &&	git clone -b $(vbcc_BRANCH) --depth 4 $(vbcc_URL)

# =================================================
# vlink
# =================================================
VLINK_CMD := vlink
VLINK := $(patsubst %,$(PREFIX)/bin/%$(EXEEXT), $(VLINK_CMD))

vlink: $(BUILD)/vlink/_done vbcc-target

$(BUILD)/vlink/_done: $(BUILD)/vlink/Makefile $(shell find 2>/dev/null $(PROJECTS)/vlink -not \( -path $(PROJECTS)/vlink/.git -prune \) -type f)
	$(L0)"make vlink"$(L1) cd $(BUILD)/vlink && TARGET=m68k $(MAKE) $(L2)
	@mkdir -p $(PREFIX)/bin/
	$(L0)"install vlink"$(L1) install $(BUILD)/vlink/vlink $(PREFIX)/bin/ $(L2)
	@echo "done" >$@

$(BUILD)/vlink/Makefile: $(PROJECTS)/vlink/Makefile
	@rsync -a --no-group $(PROJECTS)/vlink $(BUILD)/ --exclude .git

$(PROJECTS)/vlink/Makefile:
	@cd $(PROJECTS) &&	git clone -b $(vlink_BRANCH) --depth 4 $(vlink_URL)


# =================================================
# L I B R A R I E S
# =================================================
# =================================================
# gcc libs
# =================================================
LIBGCCS_NAMES := libgcov.a libstdc++.a libsupc++.a
LIBGCCS := $(patsubst %,$(PREFIX)/lib/gcc/$(TARGET)/$(GCC_VERSION)/%,$(LIBGCCS_NAMES))

libgcc: $(BUILD)/gcc/_libgcc_done

$(BUILD)/gcc/_libgcc_done: $(shell find 2>/dev/null $(PROJECTS)/gcc/libgcc -type f)
	$(L0)"make libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc all-target $(L2)
	$(L0)"install libgcc"$(L1) $(MAKE) -C $(BUILD)/gcc install-target $(L2)
	@echo "done" >$@

# =================================================
# newlib
# =================================================
NEWLIB_CONFIG := CC=$(TARGET)-gcc CXX=$(TARGET)-g++
NEWLIB_FILES = $(shell find 2>/dev/null $(PROJECTS)/newlib-cygwin/newlib -type f)

.PHONY: newlib
newlib: $(BUILD)/newlib/_done

$(BUILD)/newlib/_done: $(BUILD)/newlib/newlib/libc.a
	@echo "done" >$@

$(BUILD)/newlib/newlib/libc.a: $(BUILD)/newlib/newlib/Makefile $(NEWLIB_FILES)
	@rsync -a --no-group $(PROJECTS)/newlib-cygwin/newlib/libc/include/ $(PREFIX)/$(TARGET)/sys-include
	$(L0)"make newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib $(L2)
	$(L0)"install newlib"$(L1) $(MAKE) -C $(BUILD)/newlib/newlib install $(L2)
	@for x in $$(find $(PREFIX)/$(TARGET)/lib/* -name libm.a); do ln -sf $$x $${x%*m.a}__m__.a; done
	@touch $@

$(BUILD)/newlib/newlib/Makefile: $(PROJECTS)/newlib-cygwin/newlib/configure $(BUILD)/gcc/_done
	@mkdir -p $(BUILD)/newlib/newlib
	@if [ ! -f "$(BUILD)/newlib/newlib/Makefile" ]; then \
	$(L00)"configure newlib"$(L1) cd $(BUILD)/newlib/newlib && $(NEWLIB_CONFIG) CFLAGS="$(CFLAGS_FOR_TARGET)" CC_FOR_BUILD="$(CC)" CXXFLAGS="$(CXXFLAGS_FOR_TARGET)" $(PROJECTS)/newlib-cygwin/newlib/configure --host=$(TARGET) --prefix=$(PREFIX) --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-reent-small --enable-newlib-mb --enable-newlib-long-time_t $(L2) \
	; else touch "$(BUILD)/newlib/newlib/Makefile"; fi

$(PROJECTS)/newlib-cygwin/newlib/configure:
	@cd $(PROJECTS) &&	git clone -b $(newlib-cygwin_BRANCH) --depth 4  $(newlib-cygwin_URL)

# =================================================
# update repos
# =================================================
.PHONY: update-repos
update-repos:
	@for i in $(modules); do \
		url=$$(grep $$i .repos | sed -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2); \
		bra=$$(grep $$i .repos | sed -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3); \
		bra=$${bra/$$'\n'} ;\
		bra=$${bra/$$'\r'} ;\
		if [ -e projects/$$i ]; then \
			pushd projects/$$i; \
			echo setting remote origin from $$(git remote get-url origin) to $$url using branch $$bra.; \
			git remote remove origin; \
			git remote add origin $$url; \
			git remote set-branches origin $$bra; \
			git pull --depth 4; \
			git checkout $$bra; \
			popd; \
		fi; \
	done

# =================================================
# info
# =================================================
.PHONY: info v r b l branch
info:
	@echo $@ $(UNAME_S)
	@echo PREFIX=$(PREFIX)
	@echo GCC_VERSION=$(GCC_VERSION)
	@echo CFLAGS=$(CFLAGS)
	@echo CFLAGS_FOR_TARGET=$(CFLAGS_FOR_TARGET)
	@$(CC) -v -E - </dev/null |& grep " version "
	@$(CXX) -v -E - </dev/null |& grep " version "
	@echo $(BUILD)
	@echo $(PROJECTS)
	@echo MODULES = $(modules)

# print the latest git log entry for all projects
l:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short); popd >/dev/null; done
	@echo "." && git log -n1 --pretty=format:'%C(yellow)%h %Cred%ad %Cblue%an%Cgreen%d %Creset%s' --date=short

# print the git remotes for all projects
r:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && git remote -v); popd >/dev/null; done
	@echo "." && git remote -v

# print the git branches for all projects
b:
	@for i in $(PROJECTS)/* ; do pushd . >/dev/null; cd $$i 2>/dev/null && ([[ -d ".git" ]] && echo $$i && (git branch | grep '*')); popd >/dev/null; done
	@echo "." && git remote -v


# checkout for a given date
v:
	@D="$(date)"; \
	for i in $(modules); do \
		bra=$$(grep $$i .repos | sed -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f3); \
		bra=$${bra/$$'\n'} ;\
		bra=$${bra/$$'\r'} ;\
		if [ -e projects/$$i ]; then \
			pushd projects/$$i >/dev/null; \
			echo $$i;\
			git checkout $$bra; \
			if [ "$$D" != "" ]; then \
				(export DEPTH=16; while [ "" == "$$( git rev-list -n 1 --first-parent --before="$$D" $$bra)" ]; \
					do echo "trying depth=$$DEPTH"; git pull --depth $$DEPTH ; export DEPTH=$$(($$DEPTH+$$DEPTH)); done); \
				git checkout `git rev-list -n 1 --first-parent --before="$$D" $$bra`; \
			fi;\
			popd >/dev/null; \
		fi;\
	done; \
	echo .; \
	B=master; \
	git checkout $$B; \
	if [ "$$D" != "" ]; then \
		git checkout `git rev-list -n 1 --first-parent --before="$$D" $$B`; \
	fi

# change version to the given branch
branch:
	@if [ "" != "$(branch)" ] && [ "1" == "$$(grep -c $(mod) .repos)" ]; then \
		echo $(mod) $(branch) ; \
	    url=$$(grep $(mod) .repos | sed -e 's/[[:blank:]]\+/ /g' | cut -d' ' -f2); \
	    mv .repos .repos.bak; \
	    grep -v $(mod) .repos.bak > .repos; \
	    echo "$(mod) $$url $(branch)" >> .repos; \
	    if [ -d  projects/$(mod) ]; then \
	      pushd projects/$(mod); \
	      git fetch origin $(branch):$(branch); \
	      git checkout $(branch); \
	      git branch --set-upstream-to=origin/$(branch) $(branch); \
	      popd ; \
	   fi \
	else \
		echo "$(mod) $(branch) does NOT exist!"; \
	fi


# =================================================
# multilib support
# =================================================
MULTI = MODNAME/.: \
		MODNAME/libm020:-m68020 \
		MODNAME/libm020/libm881:-m68020_-m68881 \
		MODNAME/libb:-fbaserel \
		MODNAME/libb/libm020:-fbaserel_-m68020 \
		MODNAME/libb/libm020/libm881:-fbaserel_-m68020_-m68881 \
		MODNAME/libb32/libm020:-fbaserel32_-m68020 \
		MODNAME/libb32/libm020/libm881:-fbaserel32_-m68020_-m68881

# 1=module name, 2=from name, 3 = to name
COPY_MULTILIBS = $(foreach T, $(subst MODNAME,$1,$(MULTI)),cp $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(BUILD)/$(word 1,$(subst :, ,${T}))/$3;)

# 1=module name, 2=lib name
INSTALL_MULTILIBS = $(L0)"install $1"$(L1) $(foreach T, $(subst MODNAME,$1,$(MULTI)),rsync -av --no-group $(BUILD)/$(word 1,$(subst :, ,${T}))/$2 $(PREFIX)/lib/$(word 1,$(subst :, ,$(subst $1/,,${T})));) $(L2)

# 1=module name 3,4... = params for make
MULTIMAKE = $(L0)"make $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)), $(MAKE) -C $(BUILD)/$(word 1,$(subst :, ,${T})) $3 $4 $5 $6 $7 $8;) $(L2)

# 1=module name 2=multilib path 3=cflags
MULTICONFIGURE1 = mkdir -p $(BUILD)/$2 && cd $(BUILD)/$2 && \
	PKG_CONFIG=/bin/false CC=$(TARGET)-gcc CXX=$(TARGET)-g++ AR=$(TARGET)-ar LD=$(TARGET)-ld CFLAGS="$(subst _, ,$3) -noixemul $(CFLAGS_FOR_TARGET)" $(PROJECTS)/$1/configure

# 1=module name 3,4...= params for configure
MULTICONFIGURE = $(L0)"configure $1"$(L1) $(foreach T,$(subst MODNAME,$1,$(MULTI)),$(call MULTICONFIGURE1,$1,$(word 1,$(subst :, ,${T})),$(word 2,$(subst :, ,${T}))) $3 $4 $5 $6 $7 $8;)$(L2)


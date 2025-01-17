DEFAULT_DC=dmd
DEFAULT_CC=gcc
DEFAULT_LD=ld.lld

ifdef DC
DC_CMD=$(DC)
else
DC_CMD=$(DEFAULT_DC)
endif

ifdef CC
CC_CMD=$(CC)
else
CC_CMD=$(DEFAULT_CC)
endif

ifeq ($(LD),ld)
LD=$(DEFAULT_LD)
endif

ifeq ($(DC_TYPE),)
ifneq ($(findstring gdc,$(DC_CMD)),)
DC_TYPE_FOUND=gdc
endif
ifneq ($(findstring dmd,$(DC_CMD)),)
DC_TYPE_FOUND=dmd
endif
ifneq ($(findstring ldc,$(DC_CMD)),)
DC_TYPE_FOUND=ldc
endif
DC_TYPE=$(DC_TYPE_FOUND)
endif

DC_TYPE_OK=FALSE
ifeq ($(DC_TYPE),dmd)
DC_TYPE_OK=TRUE
endif
ifeq ($(DC_TYPE),ldc)
DC_TYPE_OK=TRUE
endif
ifeq ($(DC_TYPE),gdc)
DC_TYPE_OK=TRUE
endif
# ifeq ($(DC_TYPE),gdc)
# $(error The $(DC_TYPE) compiler family cannot compile purr yet)
# endif
ifeq ($(DC_TYPE_OK),FALSE)
$(error Unknown D compiler family $(DC_TYPE), must be in the dmd or ldc or gdc family)
endif

ifeq ($(LD),)
LD=$(DC_CMD)
endif

ifeq ($(LD_TYPE),ld)
LD=$(DC_CMD)
LD_TYPE=c
endif

LD_TYPE_FOUND=
ifneq ($(findstring ld,$(LD)),)
LD_TYPE_FOUND=ld
endif
ifneq ($(findstring dc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring cc,$(LD)),)
LD_TYPE_FOUND=c
endif
ifneq ($(findstring ld.,$(LD)),)
LD_TYPE_FOUND=ld
endif
ifneq ($(findstring dmd,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring gdc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring ldc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring gcc,$(LD)),)
LD_TYPE_FOUND=c
endif
ifneq ($(findstring clang,$(LD)),)
LD_TYPE_FOUND=c
endif

ifeq ($(LD_TYPE),)
LD_TYPE=$(LD_TYPE_FOUND)
endif

ifeq ($(LD_TYPE),ld)
LD_CMD=$(CC_CMD) -fuse-ld=$(subst ,,$(LD))
else
LD_CMD=$(LD)
endif

ifeq ($(LD_TYPE),d)
ifeq ($(LD_DC_TYPE),)
ifneq ($(findstring gdc,$(LD_CMD)),)
LD_DC_TYPE=gdc
endif
ifneq ($(findstring dmd,$(LD_CMD)),)
LD_DC_TYPE=dmd
endif
ifneq ($(findstring ldc,$(LD_CMD)),)
LD_DC_TYPE=ldc
endif
endif
endif

ifeq ($(LD_TYPE),c)
LFLAGS_EXTRA=-Wl,--export-dynamic
endif

ifeq ($(LD_TYPE),d)
LD_CMD_PRE=-L
else
LD_CMD_PRE=
endif

ifeq ($(LD_TYPE),d)
ifeq ($(DC_TYPE),dmd)
LFLAGS_DC_SIMPLE=-l:libphobos2.so -l:libdruntime-ldc-shared.so
endif
ifeq ($(DC_TYPE),gdc)
LFLAGS_DC_SIMPLE=-l:libgphobos.so.1 -l:libgdruntime.so.1
endif
ifeq ($(DC_TYPE),ldc)
LFLAGS_DC_SIMPLE=-l:libphobos2-ldc-shared.so -l:libdruntime-ldc-shared.so
endif
LFLAGS_DC=$(LFLAGS_DC_SIMPLE) $(LFLAGS) -ldl 
ifeq ($(LD_DC_TYPE),gdc)
LFLAGS_LD=-nophoboslib $(LFLAGS_DC) -lm
LFLAGS_LD_PURR=-ldl
else
LFLAGS_LD=-defaultlib=$(LFLAGS_DEFAULTLIB) $(patsubst %,-L%,$(LFLAGS_DC))
LFLAGS_LD_PURR=-L-ldl
endif
LD_LINK_IN=$(LFLAGS_LD) -L-export-dynamic $(M32_M64_FLAG)
LD_LINK_IN_LIBS=$(LD_LINK_IN)
LD_LINK_IN_PURR=$(LD_LINK_IN) $(LFLAGS_LD_PURR) 
else
ifeq ($(DC_TYPE),dmd)
LD_LINK_IN_CORRECT_STD=-lphobos2 
endif
ifeq ($(DC_TYPE),gdc)
LD_LINK_IN_CORRECT_STD=-l:libgphobos.so.1 -l:libgdruntime.so.1 
endif
ifeq ($(DC_TYPE),ldc)
LD_LINK_IN_CORRECT_STD=-l:libdruntime-ldc-shared.so -l:libphobos2-ldc-shared.so
endif
LD_LINK_IN=$(LFLAGS) $(LD_LINK_IN_CORRECT_STD) -lpthread -lm -lc -lrt $(LFLAGS_EXTRA) $(M32_M64_FLAG)
LD_LINK_IN_LIBS=$(LD_LINK_IN)
LD_LINK_IN_PURR=$(LD_LINK_IN) -ldl
endif

ifeq ($(BITS),32)
M32_M64_FLAG=-m32
else
M32_M64_FLAG=-m64
endif

ifeq ($(LD_TYPE),d)
ifeq ($(LD_DC_TYPE),gdc)
LD_CMD_OUT_FLAG=-o 
LD_CMD_LINK_FLAG=-l
else
LD_CMD_OUT_FLAG=-of=
LD_CMD_LINK_FLAG=-L-l
endif
else
LD_CMD_OUT_FLAG=-o
LD_CMD_LINK_FLAG=-l
endif

ifeq ($(DC_TYPE),gdc)
DC_CMD_OUT_FLAG=-o
else
DC_CMD_OUT_FLAG=-of=
endif

ifeq ($(shell which $(DC_CMD)),)
ifneq ($(LD_CMD),$(DC_CMD))
# $(error Cannot specify linker when using $(DC_CMD) from local path)
endif
ifeq ($(DC_TYPE),dmd)
DC_CMD_PRE=dmd
endif
ifeq ($(DC_TYPE),ldc)
DC_CMD_PRE=ldc2
endif
DC_CMD:=$(BIN)/$(DC_CMD_PRE).sh
ALL_REQURED+=getcomp
endif

ALL_DO_OPT=UNKNOWN

ifeq ($(OPT),)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif

ifeq ($(OPT),0)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif
ifeq ($(OPT),none)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif
ifeq ($(OPT),false)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif

ifeq ($(OPT),1)
ALL_DO_OPT=TRUE
OPT_LEVEL=1
endif

ifeq ($(OPT),2)
ALL_DO_OPT=TRUE
OPT_LEVEL=2
endif

ifeq ($(OPT),3)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
endif
ifeq ($(OPT),full)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
OPT_FULL_FOR_DMD=TRUE
endif
ifeq ($(OPT),true)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
OPT_FULL_FOR_DMD=TRUE
endif

ifeq ($(OPT),s)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifeq ($(OPT),small)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifeq ($(OPT),size)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifdef OPT
ifeq ($(ALL_DO_OPT),UNKNOWN)
$(error $(DC_TYPE) Cannot optimize for: OPT=$(OPT))
endif
endif

ifeq ($(ALL_DO_OPT),TRUE)
ifeq ($(DC_TYPE),dmd)
ifneq ($(OPT_FULL_FOR_DMD),TRUE)
$(error dmd (unlike ldc2) cannot optimize for: OPT=$(OPT))
else
OPT_FLAGS=-O
endif
else
OPT_FLAGS=-O$(OPT_LEVEL)
endif
else
OPT_FLAGS=
endif

DFLAGS=
FULL_DFLAGS=$(M32_M64_FLAG) $(DFLAGS)

DLIB=libphobos2.so
ifeq ($(DC_TYPE),dmd)
# DEF_FLAG=-defaultlib=$(DLIB)
DFL_FLAG_PURR=$(DEF_FLAG)
DFL_FLAG_LIBS=$(DEF_FLAG)
else
DEF_FLAG=
DEF_FLAG_LIBS=-shared $(DEF_FLAG)
DEF_FLAG_PURR=
endif

RUN=
INFO=echo

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
dlangsrc=$(call rwildcard,$1,*.d)


$(BIN): 
ifeq ($(wildcard $(BIN)),)
	$(RUN) mkdir -p $@
endif

$(LIB): 
ifeq ($(wildcard $(LIB)),)
	$(RUN) mkdir -p $@
endif

$(TMP): 
ifeq ($(wildcard $(TMP)),)
	$(RUN) mkdir -p $@
endif

dummy:

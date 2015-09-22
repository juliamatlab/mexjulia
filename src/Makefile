CC = g++
MEX_EXT = mexw64
JULIA_INC_DIR  = "C:/tw/Julia-0.5.0-dev/include/julia"
JULIA_BIN_DIR  = "C:/tw/Julia-0.5.0-dev/bin"
JULIA_INIT_DIR = "C:/tw/Julia-0.5.0-dev/lib"
MATLAB_INC_DIR = "C:/Program Files/MATLAB/R2015a/extern/include"
MATLAB_BIN_DIR = "C:/Program Files/MATLAB/R2015a/bin/win64"

CCOPTS  = -I$(JULIA_INC_DIR) -I$(MATLAB_INC_DIR)
CCOPTS += -DMATLAB_MEX_FILE -DJULIA_INIT_DIR=$(JULIA_INIT_DIR)
REL_CCOPTS = -O3
DBG_CCOPTS = -g

LOPTS  = -L$(JULIA_BIN_DIR) -L$(MATLAB_BIN_DIR)
LOPTS += -shared -lmex -lmx
REL_LOPTS = -ljulia
DBG_LOPTS = -ljulia-debug

BASE = jl_call
SRC = $(BASE).cpp
OBJ_REL = $(BASE).o
OBJ_DBG = $(BASE)d.o
TGT_REL = $(BASE).$(MEX_EXT)
TGT_DBG = $(BASE)d.$(MEX_EXT)
TGTS = $(TGT_REL) $(TGT_DBG)

.PHONY : copy
copy : $(TGTS)
	-cp $^ $(JULIA_BIN_DIR)

$(TGT_REL) : $(OBJ_REL)
	$(CC) $(LOPTS) $(REL_LOPTS) -o $@ $^

$(OBJ_REL) : $(SRC)
	$(CC) $(CCOPTS) $(REL_CCOPTS) -c -o $@ $<

$(TGT_DBG) : $(OBJ_DBG)
	$(CC) $(LOPTS) $(DBG_LOPTS) -o $@ $^

$(OBJ_DBG) : $(SRC)
	$(CC) $(CCOPTS) $(DBG_CCOPTS) -c -o $@ $<

.PHONY : clean
clean :
	-rm $(TGTS) $(OBJ_REL) $(OBJ_DBG)


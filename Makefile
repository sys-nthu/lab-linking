CC := gcc
CFLAGS := -O2 -Wall
PREFIX := /os
INC := -I$(PREFIX)/include
LIBLZ4 := -L$(PREFIX)/lib -llz4
BIN := b
SRC := lz4cat.c
SAMPLE_IN := Makefile
SAMPLE_LZ4 := $(BIN)/sample.lz4
SAMPLE_OUT := $(BIN)/sample.out

.PHONY: all clean build_static run_static build_dyn run_dyn_fail run_dyn_fix_env \
        build_dyn_rpath run_dyn_rpath sample inspect

all: build_static

$(BIN):
	mkdir -p $(BIN)

# Use /os/bin/lz4 to create a sample compressed file
sample: $(BIN)
	@/os/bin/lz4 -f $(SAMPLE_IN) $(SAMPLE_LZ4) >/dev/null
	@echo "sample created: $(SAMPLE_LZ4)"

# ---------- static ----------
build_static: $(BIN)
	LIBRARY_PATH=$(PREFIX)/lib \
	$(CC) $(CFLAGS) $(INC) -static $(SRC) -o $(BIN)/lz4cat_static $(LIBLZ4)
	@echo "Built $(BIN)/lz4cat_static (fully static)."

run_static: sample
	@echo "Running static (no LD_LIBRARY_PATH needed)…"
	@$(BIN)/lz4cat_static $(SAMPLE_LZ4) > $(SAMPLE_OUT)
	@cmp -s $(SAMPLE_IN) $(SAMPLE_OUT) && echo "static OK" || (echo "static MISMATCH"; exit 1)

# ---------- dynamic ----------
build_dyn: $(BIN)
	LIBRARY_PATH=$(PREFIX)/lib \
	$(CC) $(CFLAGS) $(INC) $(SRC) -o $(BIN)/lz4cat_dyn $(LIBLZ4)
	@echo "Built $(BIN)/lz4cat_dyn (dynamic)."

run_dyn1: sample
	@echo "Expect runtime loader failure (cannot find liblz4.so.*)…"
	$(BIN)/lz4cat_dyn $(SAMPLE_LZ4) > $(SAMPLE_OUT)

run_dyn2: sample
	@echo "Fix via LD_LIBRARY_PATH=/os/lib …"
	LD_LIBRARY_PATH=$(PREFIX)/lib $(BIN)/lz4cat_dyn $(SAMPLE_LZ4) > $(SAMPLE_OUT)
	@cmp -s $(SAMPLE_IN) $(SAMPLE_OUT) && echo "dynamic OK" || (echo "dynamic MISMATCH"; exit 1)

# ---------- optional: RPATH ----------
build_dyn_rpath: $(BIN)
	LIBRARY_PATH=$(PREFIX)/lib \
	$(CC) $(CFLAGS) $(INC) $(SRC) -Wl,-rpath,$(PREFIX)/lib -o $(BIN)/lz4cat_rpath $(LIBLZ4)
	@echo "Built $(BIN)/lz4cat_rpath (dynamic, RPATH=$(PREFIX)/lib)."

run_rpath: sample
	@echo "Running RPATH-enabled (no LD_LIBRARY_PATH needed)…"
	@$(BIN)/lz4cat_rpath $(SAMPLE_LZ4) > $(SAMPLE_OUT)
	@cmp -s $(SAMPLE_IN) $(SAMPLE_OUT) && echo "rpath OK" || (echo "rpath MISMATCH"; exit 1)

inspect:
	@echo "---- sizes ----"; ls -lh $(BIN)/lz4cat_* 2>/dev/null || true
	@echo "---- ldd (dyn) ----"; ldd $(BIN)/lz4cat_dyn 2>/dev/null || true
	@echo "---- readelf -d (dyn) ----"; readelf -d $(BIN)/lz4cat_dyn 2>/dev/null | egrep 'NEEDED|RPATH|RUNPATH' || true
	@echo "---- ldd (rpath) ----"; ldd $(BIN)/lz4cat_rpath 2>/dev/null || true
	@echo "---- readelf -d (rpath) ----"; readelf -d $(BIN)/lz4cat_rpath 2>/dev/null | egrep 'NEEDED|RPATH|RUNPATH' || true
	@echo "---- ldd (static) ----"; ldd $(BIN)/lz4cat_static 2>/dev/null || true

clean:
	rm -rf $(BIN)

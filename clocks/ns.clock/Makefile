
CAFLAGS = --target apple2enh --list-bytes 0
LDFLAGS = --config apple2-asm.cfg

OUTDIR = ../../out
UTILDIR = $(OUTDIR)/nsclock.util

HEADERS = $(wildcard *.inc) $(wildcard ../../inc/*.inc)

TARGETS = \
	$(OUTDIR)/ns.clock.system.SYS \
	$(UTILDIR)/set.datetime.BIN

LOG_SUCCESS=1
LOG_FAILURE=1

# For timestamps
MM = $(shell date "+%-m")
DD = $(shell date "+%-d")
YY = $(shell date "+%-y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY) \
	-D LOG_SUCCESS=$(LOG_SUCCESS) -D LOG_FAILURE=$(LOG_FAILURE)

XATTR := $(shell command -v xattr 2> /dev/null)

.PHONY: clean all
all: $(OUTDIR) $(UTILDIR) $(TARGETS)

$(OUTDIR) $(UTILDIR):
	mkdir -p $@

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(UTILDIR)/*.o
	rm -f $(UTILDIR)/*.list
	rm -f $(TARGETS)

$(OUTDIR)/%.o $(UTILDIR)/%.o: %.s $(HEADERS)
	ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.SYS: $(OUTDIR)/%.o
	ld65 $(LDFLAGS) -o $@ $<

$(UTILDIR)/%.BIN: $(UTILDIR)/%.o
	ld65 $(LDFLAGS) -o $@ $<
ifdef XATTR
	xattr -wx prodos.AuxType '00 20' $@
endif

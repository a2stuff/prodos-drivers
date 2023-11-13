
CAFLAGS = --target apple2enh --list-bytes 0
LDFLAGS = --config apple2-asm.cfg

OUTDIR = ../out

HEADERS = $(wildcard *.inc) $(wildcard ../inc/*.inc)

TARGETS = \
	$(OUTDIR)/a2green.system.SYS \
	$(OUTDIR)/bw.system.SYS \
	$(OUTDIR)/deepblue.system.SYS \
	$(OUTDIR)/gray.system.SYS \
	$(OUTDIR)/gsblue.system.SYS \
	$(OUTDIR)/mint.system.SYS \
	$(OUTDIR)/pink.system.SYS \
	$(OUTDIR)/wb.system.SYS
# For timestamps
MM = $(shell date "+%-m")
DD = $(shell date "+%-d")
YY = $(shell date "+%-y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY)

XATTR := $(shell command -v xattr 2> /dev/null)

.PHONY: clean all
all: $(OUTDIR) $(TARGETS)

$(OUTDIR):
	mkdir -p $(OUTDIR)

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(TARGETS)

$(OUTDIR)/%.o: %.s $(HEADERS)
	ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.BIN $(OUTDIR)/%.SYS: $(OUTDIR)/%.o
	ld65 $(LDFLAGS) -o $@ $<
ifdef XATTR
	xattr -wx prodos.AuxType '00 20' $@
endif


CAFLAGS = --target apple2enh --list-bytes 0
LDFLAGS = --config apple2-asm.cfg

OUTDIR = out

HEADERS = $(wildcard *.inc) $(wildcard ../inc/*.inc)

TARGETS = \
	$(OUTDIR)/bye.system.SYS \
	$(OUTDIR)/buhbye.system.SYS

# For timestamps
MM = $(shell date "+%-m")
DD = $(shell date "+%-d")
YY = $(shell date "+%-y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY)

.PHONY: clean all
all: $(OUTDIR) $(TARGETS)

$(OUTDIR):
	mkdir -p $(OUTDIR)

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(OUTDIR)/$(TARGETS)

$(OUTDIR)/%.o: %.s $(HEADERS)
	ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.SYS: $(OUTDIR)/%.o
	ld65 $(LDFLAGS) -o $@ $<
	xattr -wx prodos.AuxType '00 20' $@

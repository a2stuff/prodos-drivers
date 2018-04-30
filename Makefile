
CC65 = ~/dev/cc65/bin
CAFLAGS = --target apple2enh --list-bytes 0
CCFLAGS = --config apple2-asm.cfg

OUTDIR = out

TARGETS = \
	$(OUTDIR)/prodos.mod.BIN \
	$(OUTDIR)/ns.clock.system.SYS \
	$(OUTDIR)/cricket.system.SYS \
	$(OUTDIR)/test.BIN \
	$(OUTDIR)/date.BIN \
	$(OUTDIR)/set.time.BIN \
	$(OUTDIR)/set.date.BIN

# For timestamps
MM = $(shell date "+%m")
DD = $(shell date "+%d")
YY = $(shell date "+%y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY)

.PHONY: clean all
all: $(TARGETS)

HEADERS = $(wildcard *.inc)

clean:
	rm -f $(OUTDIR)/*.o
	rm -f $(OUTDIR)/*.list
	rm -f $(OUTDIR)/$(TARGETS)

$(OUTDIR)/%.o: %.s $(HEADERS)
	$(CC65)/ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.BIN $(OUTDIR)/%.SYS: $(OUTDIR)/%.o
	$(CC65)/ld65 $(CCFLAGS) -o $@ $<
	xattr -wx prodos.AuxType '00 20' $@

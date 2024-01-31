
CAFLAGS = --target apple2enh --list-bytes 0
LDFLAGS = --config apple2-asm.cfg

OUTDIR = ../out

HEADERS = $(wildcard *.inc) $(wildcard ../inc/*.inc)

TARGETS = \
	$(OUTDIR)/a2green.system.SYS \
	$(OUTDIR)/a2green.setup.SYS \
	$(OUTDIR)/bw.system.SYS \
	$(OUTDIR)/bw.setup.SYS \
	$(OUTDIR)/deepblue.system.SYS \
	$(OUTDIR)/deepblue.setup.SYS \
	$(OUTDIR)/gray.system.SYS \
	$(OUTDIR)/gray.setup.SYS \
	$(OUTDIR)/gsblue.system.SYS \
	$(OUTDIR)/gsblue.setup.SYS \
	$(OUTDIR)/mint.system.SYS \
	$(OUTDIR)/mint.setup.SYS \
	$(OUTDIR)/pink.system.SYS \
	$(OUTDIR)/pink.setup.SYS \
	$(OUTDIR)/wb.system.SYS \
	$(OUTDIR)/wb.setup.SYS

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

$(OUTDIR)/%.setup.o: %.system.s $(HEADERS)
	ca65 $(CAFLAGS) $(DEFINES) -D BUILD_SETUP_FILE --listing $(basename $@).list -o $@ $<

$(OUTDIR)/%.BIN $(OUTDIR)/%.SYS: $(OUTDIR)/%.o
	ld65 $(LDFLAGS) -o $@ $<


CAFLAGS = --target apple2enh --list-bytes 0
LDFLAGS = --config apple2-asm.cfg

TARGETS = quit.system.SYS

# For timestamps
MM = $(shell date "+%-m")
DD = $(shell date "+%-d")
YY = $(shell date "+%-y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY)

.PHONY: clean all
all: $(TARGETS)

HEADERS = $(wildcard *.inc) $(wildcard ../inc/*.inc)

clean:
	rm -f *.o
	rm -f $(TARGETS)

%.o: %.s $(HEADERS)
	ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

%.SYS: %.o
	ld65 $(LDFLAGS) -o $@ $<
	xattr -wx prodos.AuxType '00 20' $@

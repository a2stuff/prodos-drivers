
CC65 = ~/dev/cc65/bin
CAFLAGS = --target apple2enh --list-bytes 0
CCFLAGS = --config apple2-asm.cfg

TARGETS = prodos.mod.BIN ns.clock.system.SYS cricket.system.SYS test.BIN get.time.BIN

# For timestamps
MM = $(shell date "+%m")
DD = $(shell date "+%d")
YY = $(shell date "+%y")
DEFINES = -D DD=$(DD) -D MM=$(MM) -D YY=$(YY)

.PHONY: clean all
all: $(TARGETS)

HEADERS = $(wildcard *.inc)

clean:
	rm -f *.o
	rm -f $(TARGETS)

%.o: %.s $(HEADERS)
	$(CC65)/ca65 $(CAFLAGS) $(DEFINES) --listing $(basename $@).list -o $@ $<

%.BIN %.SYS: %.o
	$(CC65)/ld65 $(CCFLAGS) -o $@ $<

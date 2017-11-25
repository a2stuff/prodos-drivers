
CC65 = ~/dev/cc65/bin
CAFLAGS = --target apple2enh --list-bytes 0
CCFLAGS = --config apple2-asm.cfg

TARGETS = cricket.system.SYS prodos.mod.BIN test.system.SYS ns.clock.system.SYS

.PHONY: clean all
all: $(TARGETS)

HEADERS = $(wildcard *.inc)

clean:
	rm -f *.o
	rm -f $(TARGETS)

%.o: %.s $(HEADERS)
	$(CC65)/ca65 $(CAFLAGS) --listing $(basename $@).list -o $@ $<

%.BIN %.SYS: %.o
	$(CC65)/ld65 $(CCFLAGS) -o $@ $<

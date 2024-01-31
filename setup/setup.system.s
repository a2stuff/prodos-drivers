;;;
;;; SETUP.SYSTEM by Sean Nolan
;;;
;;; A Proposed Startup File Standard
;;;
;;; Published in Call-APPLE, November, 1987
;;; This program is in the public domain.
;;;
;;; This program mimics the ProDOS 16
;;; SYSTEM.SETUP convention. It can be used
;;; to install RAM disk drivers, clock
;;; drivers, and IIGS Classic Desk
;;; Accessories on bootup under ProDOS 8.
;;;
;;; This program loads and calls all BINary
;;; and SYStem files in a subdirectory named
;;; SETUPS. It then looks for the second
;;; system program in the volume directory
;;; whose name ends in ".SYSTEM", and runs
;;; that.
;;;
;;;

;;; Original code clears the screen before/after each driver. Skip it.
NO_HOME = 1

.define ORG .org
.define DFB .byte
.define DA  .addr
.define DS  .res
.define ASC .byte
.define ASCH scrcode
.feature labels_without_colons +
.feature loose_string_term +
.include "apple2.mac"

.if 0
         TYP   $FF        ;save as a system file
.endif
         ORG   $BD00      ;load at $2000, but run at $BD00
;;; ****************** equates
CH       =     $24
IN2      =     $280
FILETYPE =     IN2+16
AUXCODE  =     IN2+31
RESET    =     $3F2
IOBUFFER =     $B900
PRODOS   =     $BF00
QUITVECT =     $BF03
DEVNUM   =     $BF30
BITMAP   =     $BF58
INIT     =     $FB2F
VTABZ    =     $FC24
HOME     =     $FC58
RDKEY    =     $FD0C
SETVID   =     $FE93
SETKBD   =     $FE89
SETNORM  =     $FE84
;;; ****************** boot code
VOLNAME  =     *          ;The first 17 bytes are overwritten with the
                          ;name of the volume from which this was run.
         LDX   #1         ;mark page $BD as free in the system bitmap
         STX   BITMAP+23  ;so we can put Online result in our code.
         DEX              ;relocate this program to $BD00-BEFF
LOOP1    LDA   $2000,X
         STA   $BD00,X
         LDA   $2100,X
         STA   $BE00,X
         INX
         BNE   LOOP1
         DEX
         TXS              ;init stack pointer
         JMP   ENTER      ;jump to relocated code
DIRNAME  DFB   6          ;DirName and VolName must be in the same page
         ASCH "SETUPS"

;;; ****** Get name of boot volume
ENTER    LDA   DEVNUM     ;get name of last volume accessed
         STA   ONLINEN
         JSR   PRODOS
         DFB   $C5        ;ONLINE
         DA    ONLINEP
         LDA   VOLNAME+1  ;insert a slash nefore the name
         AND   #$0F
         TAX
         INX
         STX   VOLNAME
         LDA   #$2F       ;/
         STA   VOLNAME+1
         LDA   QUITVECT+1 ;save original quit vector
         STA   QUITMOD1+1
         LDA   QUITVECT+2
         STA   QUITMOD2+1
;;; ****** Clean up before &amp; after calling files
MAINLOOP LDX   #2         ;point Reset vector and ProDOS
LOOP3    LDA   JUMP+1,X   ;Quit vectors to MainLoop
         STA   RESET,X
         LDA   JUMP,X
         STA   QUITVECT,X
         DEX
         BPL   LOOP3
         TXS              ;fix stack pointer (X=$FF)
         JSR   CLOSE      ;close all open files
         LDX   #23        ;clear system bit map
         LDA   #0
LOOP2    STA   BITMAP,X
         DEX
         BPL   LOOP2
         LDA   #$CF       ;mark pages 0,1,4-7 as used
         STA   BITMAP
         LDA   #%111      ;mark pages $BD-$BF as used
         STA   BITMAP+23
         LDA   $C082      ;Language card off
         STA   $C00C      ;40-column
         STA   $C00E      ;normal character set
         STA   $C000      ;80STORE off
         JSR   SETNORM    ;normal
         JSR   INIT       ;display text page 1
         JSR   SETVID     ;PR#0
         JSR   SETKBD     ;IN#0
;;; Make sure boot volume is around
;;; AND set prefix to the boot volume
.if NO_HOME
VOLMOUNT
.else
VOLMOUNT JSR   HOME
.endif
         JSR   PRODOS     ;set prefix to volume
         DFB   $C6        ;SET PREFIX
         DA    PFX2P
         BCC   VOLOK
         LDX   #13
LOOP6    LDA   VOLTEXT-1,X ;print message "insert volume"
         STA   $5A8+4,X
         DEX
         BNE   LOOP6
LOOP7    LDA   VOLNAME+1,X ;print volume name
         ORA   #$80
         STA   $5A8+19,X
         INX
         CPX   VOLNAME
         BCC   LOOP7
         LDA   #35        ;go to CH=35, CV=11
         STA   CH
         LDA   #11
         JSR   VTABZ
         JSR   RDKEY      ;wait for keypress
         JMP   VOLMOUNT
;;; ****** Get name of next file at IN2
VOLOK    JSR   NEXTFILE   ;get name of next file at IN2
         BCS   EXITLOOP   ;if error, we're done with setup files
;;; ****** Load and call setup file
         JSR   PRODOS     ;set prefix to SETUPS
         DFB   $C6        ;SET PREFIX
         DA    PFX1P
         JSR   READFILE   ;read in file whose name is at IN@
                          ;and call it if there was no error.
JUMP     JMP   MAINLOOP   ;3 bytes here copied into ProDOS quit vector
         DFB   $BD^$A5   ;3 bytes here are copied into reset vector
EXITLOOP INC   RESET+2    ;scramble reset vector
QUITMOD1 LDA   #0         ;restore original quit vector
         STA   QUITVECT+1
QUITMOD2 LDA   #0
         STA   QUITVECT+2
;;; ****** Look for second system program on disk
         LDA   #0         ;modify NextFile routine so that it searches
         STA   NUMBER+1   ;the volume directory for system files only.
         STA   CHEKTYPE+1
         LDA   #<VOLNAME  ;NamePtr+1 does not bneed to be changed
         STA   NAMEPTR    ;since VolName and DirName are in the same page
NEXTSYS  JSR   NEXTFILE
         BCS   QUIT
         LDX   IN2        ;see if file ends with ".SYSTEM"
         LDY   #6
LOOP4    LDA   IN2,X      ;I expect pathname at IN2 in low ASCII
         CMP   SYSTEXT,Y
         BNE   NEXTSYS
         DEX
         DEY
         BPL   LOOP4
         INC   MOD+1
MOD      LDA   #$FF       ;the first .SYSTEM program we find is this
         BEQ   NEXTSYS    ;one, so skip it and look for next one.
         JSR   READFILE   ;if successful, never come back
QUIT     JSR   PRODOS
         DFB   $65        ;QUIT
         DA    QUITP
SYSTEXT  ASC   '.SYSTEM'

;;; Get name of next system file or binary file
;;;
;;; This routine is set up to look for both SYSTEM and
;;; BINary files in the SETUPs subdirectory. It is later
;;; modified to search for SYSTEM files only in the
;;; volume directory. The locations which are changed
;;; are ChekType+1, Number+1, and NamePtr (in the Open
;;; parametr list)
;;;
;;; Returns carry if not found, clear if found.
NEXTFILE JSR   PRODOS
         DFB   $C8        ;OPEN
         DA    OPENP
         BCS   CLOSE
         LDA   OPENN
         STA   MARKN
         STA   READN
         JSR   PRODOS     ;Read in first 39 bytes of directory to
         DFB   $CA        ;IN2. This gets the number of entries per
         DA    READP      ;block and number of bytes per entry.
         BCS   CLOSE
         LDA   IN2+35     ;save number of bytes per directory entry
         STA   ENTSIZE+1
         LDA   IN2+36     ;save number of entries per directory block
         STA   ENTRIES+1
NEXTENT  INC   NUMBER+1
NUMBER   LDA   #0         ;self-modified operand
;;; Retrieve catalog entry #A
         LDX   #$FE       ;build page index in X
LOOP5    INX
         INX
ENTRIES  CMP   #13
         BCC   OK
         SBC   ENTRIES+1
         BCS   LOOP5      ;always
OK       TAY
         LDA   #4         ;1st entry per directory block starts 4 bytes in
LOOP10   DEY
         BMI   OK2
         CLC
ENTSIZE  ADC   #39        ;add size of directory entry
         BCC   LOOP10
         INX
         BNE   LOOP10     ;always
OK2      STA   MARK       ;save mark in file
         STX   MARK+1
         JSR   PRODOS     ;set the mark
         DFB   $CE        ;SET_MARK
         DA    MARKP
         BCS   CLOSE
         JSR   PRODOS     ;read in directory info
         DFB   $CA        ;READ
         DA    READP
         BCS   CLOSE
         LDA   IN2        ;make sure that file is not deleted
         BEQ   NEXTENT
         AND   #$0F
         STA   IN2
         LDA   FILETYPE   ;make sure file type is correct
         EOR   #$FF       ;we look for system programs...
         BEQ   CLOSE
CHEKTYPE EOR   6^$FF      ;...and binary ones.
         BNE   NEXTENT
CLOSE    PHP              ;close all files - do not change carry
         JSR   PRODOS
         DFB   $CC        ;CLOSE
         DA    CLOSEP
         PLP
ANRTS    RTS
;;; Read file and call it.
;;; Name should be found at IN2
;;; Prefix must be set.
READFILE LDX   FILETYPE   ;if a system program, set to read to $2000
         LDA   #$20
         INX
         BEQ   SETDEST
         LDX   AUXCODE    ;else, set to read in file at address
         LDA   AUXCODE+1  ;found in auxcode
SETDEST  STX   READ2D
         STA   READ2D+1
         JSR   PRODOS     ;Open file
         DFB   $C8        ;OPEN
         DA    OPEN2P
         BCS   CLOSE
         LDA   OPEN2N
         STA   READ2N
         JSR   PRODOS     ;Read file into memory
         DFB   $CA        ;READ
         DA    READ2P
         JSR   CLOSE
         BCS   ANRTS
         JMP   (READ2D)   ;call the file just loaded
;;; ****** ProDOS MLI parameter lists
ONLINEP  DFB   2          ;Online parameter list
ONLINEN  DS    1
         DA    VOLNAME+1
;;;
PFX1P    DFB   1          ;to set prefix to SETUP
         DA    DIRNAME
;;;
PFX2P    DFB   1          ;to set prefix to volume directory
         DA    VOLNAME
;;;
QUITP    DFB   4,0,0,0,0,0,0

;;;
CLOSEP   DFB   1,0        ;close all files
;;;
OPENP    DFB   3          ;open directory
NAMEPTR  DA    DIRNAME    ;pathname pointer
         DA    IOBUFFER
OPENN    DS    1          ;reference number
;;;
MARKP    DFB   2          ;set mark in directory
MARKN    DS    1
MARK     DS    3
;;;
READP    DFB   4          ;read directory
READN    DS    1
         DA    IN2        ;target address
         DA    39         ;length
         DS    2
;;;
OPEN2P   DFB   3          ;open setup or system file
         DA    IN2
         DA    IOBUFFER
OPEN2N   DS    1
;;;
READ2P   DFB   4          ;read setup or system file
READ2N   DS    1
READ2D   DS    2          ;destination of file is self-mod here
         DA    $B900-$800 ;ask for largest possible that will fit
         DS    2
;;;
VOLTEXT  ASCH  "INSERT VOLUME"
.if 0
         CHK              ;checksum - eor for all previous bytes
.else
         .byte $E8
.endif

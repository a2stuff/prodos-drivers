;;; ------------------------------------------------------------
;;; Smartport access functions
;;; Derived from: http://mirrors.apple2.org.za/ground.icaen.uiowa.edu/MiscInfo/Programming/smartport.statusexample

;;This function scans the slots to locate a SmartPort.
;;On entry, X=$Cx, where x is the first slot to be checked. 
;;On exit, X=$Cy, where y is the highest numbered slot less than or
;;equal to x which contains SmartPort firmware.  If no SmartPort
;;is found, C=1 and A=$00.
ptr := $A5 ; Generic pointer

.proc find_smartport
        LDA  #$00
        STA  ptr       ; Set up the pointer
try_slot:
        STX  ptr+1
        LDY  #$01
        LDA  (ptr),Y       ; Check the first ID byte
        CMP  #$20
        BNE  not_here
        LDY  #$03
        LDA  (ptr),Y       ; and the second one
        CMP  #$00
        BNE  not_here
        LDY  #$05
        LDA  (ptr),Y       ; and the third one
        CMP  #$03
        BNE  not_here
        LDY  #$07
        LDA  (ptr),Y       ; and the fourth one
        CMP  #$00
        BNE  not_here
        LDX  ptr+1         ; Match!  Get the address back
        CLC
        RTS
not_here:
        LDX  ptr+1         ; Mismatch
        DEX                ; Go down one slot
        CPX  #$C1
        BCS  try_slot      ; Stop once we have gone past slot 1
        LDX  #$00
        SEC                ; Error - no SmartPort found
        RTS
.endproc

;; This function sets up the SP_CALL function for calling the
;; SmartPort driver.  On entry, X=$Cx, where x is the slot number
;; containing a SmartPort driver.  This should be checked via
;; FIND_SMARTPORT if necessary - don't assume there is a SmartPort
;; device in slot 5, for example!
.proc setup_smartport
        LDA  #$00
        STA  ptr           ; Set up the pointer
        STX  ptr+1
        LDY  #$FF
        LDA  (ptr),Y       ; Get the ProDOS driver entry point
        CLC 
        ADC  #$03          ; Get the SmartPort driver entry point
        STA  sp_call_lo    ; Store in the JSR
        STX  sp_call_hi    ; also store the high byte
        RTS
.endproc

;; This function return in X the number of devices available
;; on a SmartPort
.proc device_count
        LDA  #$00
        STA  st_unit
        STA  st_code
        JSR  sp_call
        BCS  device_count_error
        LDX  st_list+0
        RTS
device_count_error:
        LDX  #$00
        RTS
.endproc

;; This function returns in A the device type for a unit in X
.proc unit_type
        STX  st_unit
        LDA  #$03
        STA  st_code
        JSR  sp_call
        BCS  unit_type_error
        LDA  st_list+21
        LDX  st_unit
        RTS
unit_type_error:
        LDA  #$ff
        LDX  st_unit
        RTS
.endproc



;; Status command parameters
sp_call: JSR  $0000
sp_call_hi = *-1
sp_call_lo = *-2
        .byte DRIVER_COMMAND_STATUS ; Command Status
params_address:
        .word st_params
        RTS

st_params: 
        .byte $3           ; Parameter count
st_unit:.byte $0
        .word st_list
st_code:.byte $0
st_list:.byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24

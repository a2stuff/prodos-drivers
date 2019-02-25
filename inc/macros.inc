;;; ============================================================
;;; Generic Macros
;;; ============================================================

.define _is_immediate(arg)       (.match (.mid (0, 1, {arg}), #))
.define _is_register(arg)        (.match ({arg}, x) .or .match ({arg}, y))
.define _is_y_register(arg)      (.match ({arg}, y))
.define _immediate_value(arg)    (.right (.tcount ({arg})-1, {arg}))

.macro _op_lo op, arg
    .if _is_immediate {arg}
        op #<_immediate_value {arg}
    .else
        op arg
    .endif
.endmacro

.macro _op_hi op, arg
    .if _is_immediate {arg}
        op #>_immediate_value {arg}
    .else
        op arg+1
    .endif
.endmacro

;;; ============================================================
;;; Length-prefixed string
;;;
;;; Can include control chars by using:
;;;
;;; PASCAL_STRING {"abc",$0D,"def"}

.macro PASCAL_STRING str,res
        .local  data
        .local  end
        .byte   end - data
data:   .byte   str
end:
.if     .paramcount > 1
        .res    res - (end - data), 0
.endif
.endmacro


;;; ============================================================
;;; Common patterns

.macro copy arg1, arg2, arg3, arg4
    .if _is_register {arg2} && _is_register {arg4}
        ;; indexed load/indexed store
        lda     arg1,arg2
        sta     arg3,arg4
    .elseif _is_register {arg2}
        ;; indexed load variant (arg2 is x or y)
        lda     arg1,arg2
        sta     arg3
    .elseif _is_register {arg3}
        ;; indexed store variant (arg3 is x or y)
        lda     arg1
        sta     arg2,arg3
    .else
        lda     arg1
        sta     arg2
    .endif
.endmacro



;;; Copy 16-bit value
;;;    copy16 #$1111, $2222     ; immediate, absolute
;;;    copy16 $1111, $2222      ; absolute, absolute
;;;    copy16 $1111,x, $2222    ; indirect load, absolute store
;;;    copy16 $1111, $2222,x    ; absolute load, indirect store
;;;    copy16 $1111,x $2222,x   ; indirect load, indirect store
;;;    copy16 #$1111, $2222,x   ; immediate load, indirect store
.macro copy16 arg1, arg2, arg3, arg4
    .if _is_register {arg2} && _is_register {arg4}
        ;; indexed load/indexed store
        lda     arg1,arg2
        sta     arg3,arg4
        lda     arg1+1,arg2
        sta     arg3+1,arg4
    .elseif _is_register {arg2}
        ;; indexed load variant (arg2 is x or y)
        lda     arg1,arg2
        sta     arg3
        lda     arg1+1,arg2
        sta     arg3+1
    .elseif _is_register {arg3}
        ;; indexed store variant (arg3 is x or y)
        _op_lo  lda, {arg1}
        sta     arg2,arg3
        _op_hi  lda, {arg1}
        sta     arg2+1,arg3
    .else
        _op_lo  lda, {arg1}
        sta     arg2
        _op_hi  lda, {arg1}
        sta     arg2+1
    .endif
.endmacro

.MODEL SMALL
.STACK 100h

.DATA
    msg_titulo  db 13, 10, '=== CALCULADORA HEXADECIMAL (00h - FFh) ===', 13, 10, '$'
    msg_num1    db 13, 10, 'Ingrese primer byte hexadecimal (2 digitos, ej. 2A): $'
    msg_num2    db 13, 10, 'Ingrese segundo byte hexadecimal (2 digitos, ej. 15): $'
    msg_op      db 13, 10, 'Ingrese operador (+ o -): $'
    msg_res     db 13, 10, 13, 10, 'Resultado hexadecimal: $'
    msg_err     db 13, 10, '[Error] Entrada invalida. Intente de nuevo.', 13, 10, '$'
    
    num1        db ?
    num2        db ?
    operador    db ?

.CODE
MAIN PROC
    ; Inicializar segmento de datos
    mov ax, @data
    mov ds, ax

    ; Mostrar titulo
    lea dx, msg_titulo
    mov ah, 09h
    int 21h

PEDIR_NUM1:
    lea dx, msg_num1
    mov ah, 09h
    int 21h
    call LEER_BYTE_HEX
    jc ERROR_NUM1           ; Si CF=1, hubo un caracter invalido
    mov num1, al
    jmp PEDIR_NUM2

ERROR_NUM1:
    lea dx, msg_err
    mov ah, 09h
    int 21h
    jmp PEDIR_NUM1

PEDIR_NUM2:
    lea dx, msg_num2
    mov ah, 09h
    int 21h
    call LEER_BYTE_HEX
    jc ERROR_NUM2
    mov num2, al
    jmp PEDIR_OP

ERROR_NUM2:
    lea dx, msg_err
    mov ah, 09h
    int 21h
    jmp PEDIR_NUM2

PEDIR_OP:
    lea dx, msg_op
    mov ah, 09h
    int 21h
    
    mov ah, 01h             ; Leer un caracter con eco
    int 21h
    mov operador, al

    cmp al, '+'
    je EJECUTAR_SUMA
    cmp al, '-'
    je EJECUTAR_RESTA

    lea dx, msg_err
    mov ah, 09h
    int 21h
    jmp PEDIR_OP

EJECUTAR_SUMA:
    lea dx, msg_res
    mov ah, 09h
    int 21h

    mov al, num1            ; Cargar primer operando en AL
    mov bl, num2            ; Cargar segundo operando en BL
    add al, bl              ; Instruccion nativa ADD sobre registros
    mov bl, al              ; Respaldar resultado de 8 bits en BL

    jnc MOSTRAR_BYTE_FINAL  ; Si no hay acarreo (CF=0), imprimir 2 digitos
    
    ; Si hubo acarreo (CF=1), el resultado excede FFh -> imprimir '1' adelante
    mov dl, '1'
    mov ah, 02h
    int 21h
    jmp MOSTRAR_BYTE_FINAL

EJECUTAR_RESTA:
    lea dx, msg_res
    mov ah, 09h
    int 21h

    mov al, num1            ; Cargar primer operando en AL
    mov bl, num2            ; Cargar segundo operando en BL
    sub al, bl              ; Instruccion nativa SUB sobre registros
    mov bl, al              ; Respaldar resultado en BL

    jnc MOSTRAR_BYTE_FINAL  ; Si no hay prestamo/borrow (CF=0), num1 >= num2
    
    ; Si CF=1 (resultado negativo), imprimir '-' y obtener magnitud (Complemento a 2)
    mov dl, '-'
    mov ah, 02h
    int 21h
    neg bl                  ; Convertir complemento a dos a valor absoluto

MOSTRAR_BYTE_FINAL:
    mov al, bl
    call IMPRIMIR_BYTE_HEX
    
    ; Imprimir sufijo 'h'
    mov dl, 'h'
    mov ah, 02h
    int 21h

    ; Finalizar programa y devolver control al SO (INT 21h, funcion 4Ch)
    mov ah, 4Ch
    int 21h
MAIN ENDP

; =========================================================================
; PROCEDIMIENTO: LEER_BYTE_HEX
; Lee 2 caracteres hexadecimales del teclado y los empaqueta en AL (00h-FFh).
; Retorna CF=0 si es valido, CF=1 si se ingreso un caracter no hexadecimal.
; =========================================================================
LEER_BYTE_HEX PROC
    push bx
    push cx

    ; Leer nibble alto (primer digito)
    mov ah, 01h
    int 21h
    call ASCII_A_HEX
    jc FIN_LEER_ERR
    mov cl, 4
    shl al, cl              ; Desplazar 4 bits a la izquierda (nibble alto)
    mov bl, al              ; Guardar nibble alto en BL

    ; Leer nibble bajo (segundo digito)
    mov ah, 01h
    int 21h
    call ASCII_A_HEX
    jc FIN_LEER_ERR
    or bl, al               ; Combinar nibble alto y bajo en BL
    mov al, bl              ; Retornar resultado en AL
    clc                     ; Limpiar bandera de acarreo (sin error)
    jmp FIN_LEER_OK

FIN_LEER_ERR:
    stc                     ; Encender bandera de acarreo (error de formato)

FIN_LEER_OK:
    pop cx
    pop bx
    ret
LEER_BYTE_HEX ENDP

; =========================================================================
; PROCEDIMIENTO: ASCII_A_HEX
; Convierte el caracter ASCII en AL a su valor numerico (0h - Fh).
; =========================================================================
ASCII_A_HEX PROC
    cmp al, '0'
    jb NO_ES_HEX
    cmp al, '9'
    jbe ES_DIGITO

    cmp al, 'A'
    jb NO_ES_HEX
    cmp al, 'F'
    jbe ES_MAYUSCULA

    cmp al, 'a'
    jb NO_ES_HEX
    cmp al, 'f'
    jbe ES_MINUSCULA

NO_ES_HEX:
    stc
    ret

ES_DIGITO:
    sub al, '0'
    clc
    ret

ES_MAYUSCULA:
    sub al, 'A'
    add al, 0Ah
    clc
    ret

ES_MINUSCULA:
    sub al, 'a'
    add al, 0Ah
    clc
    ret
ASCII_A_HEX ENDP

; =========================================================================
; PROCEDIMIENTO: IMPRIMIR_BYTE_HEX
; Imprime en pantalla el contenido de AL como 2 digitos hexadecimales.
; =========================================================================
IMPRIMIR_BYTE_HEX PROC
    push ax
    push bx
    push cx
    push dx

    mov bl, al              ; Guardar valor original

    ; Imprimir nibble alto
    mov cl, 4
    shr al, cl              ; Aislar los 4 bits superiores
    call HEX_A_ASCII
    mov dl, al
    mov ah, 02h
    int 21h

    ; Imprimir nibble bajo
    mov al, bl
    and al, 0Fh             ; Mascara para aislar los 4 bits inferiores
    call HEX_A_ASCII
    mov dl, al
    mov ah, 02h
    int 21h

    pop dx
    pop cx
    pop bx
    pop ax
    ret
IMPRIMIR_BYTE_HEX ENDP

HEX_A_ASCII PROC
    cmp al, 9
    jbe DIGITO_ASCII
    add al, 37h             ; Convertir 10..15 (0Ah..0Fh) a 'A'..'F'
    ret
DIGITO_ASCII:
    add al, 30h             ; Convertir 0..9 a '0'..'9'
    ret
HEX_A_ASCII ENDP

END MAIN

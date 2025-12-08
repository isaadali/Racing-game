[org 0x100]
jmp start

row: dw 0

;-------------------------------------
; Clear screen
;-------------------------------------
clrscr:
    push ax
    push es
    push di
    push cx
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov ax, 0x0720
    mov cx, 2000
    cld
    rep stosw
    pop cx
    pop di
    pop es
    pop ax
    ret

;-------------------------------------
; Main program
;-------------------------------------
start:
    call clrscr
    
    mov ax, 0xb800
    mov es, ax
    
    ; Draw the screen row by row
    mov word [row], 0
    
draw_all_rows:
    mov bx, [row]
    cmp bx, 25
    jge cars_done
    
    ; Calculate starting position for this row
    mov ax, 160
    mul bx
    mov di, ax
    
    ; Left grass border (3 columns)
    mov cx, 3
    mov ah, 0x22           ; green on green
    mov al, 219            ; solid block █
left_border:
    stosw
    loop left_border
    
    ; Road area (74 columns)
    mov cx, 74
road_loop:
    mov ax, 74             ; total road width
    sub ax, cx             ; current column (0–73)
    
    ; Lane dividers at road columns 23 and 51
    cmp ax, 23
    je draw_dash_here
    cmp ax, 51
    je draw_dash_here
    
normal_road:
    mov ah, 0x77           ; gray on gray (road)
    mov al, ' '
    stosw
    loop road_loop
    jmp after_road

draw_dash_here:
    mov ah, 0x7F           ; bright white on gray
    mov al, '|'
    stosw
    loop road_loop

after_road:
    
    ; Right grass border (3 columns)
    mov cx, 3
    mov ah, 0x22           ; green on green
    mov al, 219
right_border:
    stosw
    loop right_border
    
    inc word [row]
    jmp draw_all_rows

cars_done:
    ; Draw RED player car at bottom (column 27)
   ; mov bx, 820             ; row
   ; mov dx, 27             ; column 27 (middle lane)
    ;mov ah, 0xCC           ; bright red on bright red
    ;call draw_car
    
    ; Draw BLUE obstacle car at random row (column 27)
    mov bx, 2420
  ;  mov dx, 27             ; column 27
    mov ah, 0x99           ; bright blue on bright blue
    call draw_car
    
    ; Wait for key press
    mov ah, 0x00
    int 0x16
    
    ; Exit to DOS
    mov ax, 0x4c00
    int 0x21

;-------------------------------------
; Draw car (3x3 solid block)
; Input: BX=row, DX=column, AH=color
;-------------------------------------
draw_car:
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0xb800
    mov es, ax

    ; Calculate top-left offset = row*160 + column*2
    mov di, bx

              ; save color in BL
    mov ah,  bl
   push cx
        
   mov cx, 3      ; 3 rows
     car_row_loop:
    ;push cx   
     mov cx, 3      ; 3 columns
     car_col_loop:
        mov al, 219
        mov ah, bl
        stosw
        loop car_col_loop
    ;add di, (160 - 6) ; move down one row (160 bytes - 6 written)
   ; pop cx
   ; loop car_row_loop

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;-------------------------------------
; Get random row (5–18)
;-------------------------------------
get_random_row:
    push dx
    push bx
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, 13
    div bx
    mov ax, dx
    add ax, 5
    pop bx
    pop dx
    ret

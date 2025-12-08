org 0x100
jmp start

; Data section
fuel_x: dw 0
fuel_y: dw 0
fuel_cooldown: dw 0
temp_color: db 0
temp_x: dw 0
temp_y: dw 0
circle_decision: dw 0
oldkb: dd 0
car1_x: dw 151
car1_y: dw 90
car2_y: dw 90
paused: db 0
game_running: db 1
quit_msg: db 'want to quit? Y/N', 0

; Obstacle car data
obs_car1_x: dw 0
obs_car1_y: dw 0
obs_car2_x: dw 0
obs_car2_y: dw 0

; Buffer for pause screen (160x80 = 12800 bytes)
pause_buffer: times 12800 db 0

kbisr:
    push ax
    push bx
    push cx
    push dx
    push si
    push ds
    push es
    push cs
    pop ds
    
    in al, 0x60
    
    cmp byte [paused], 1
    jne .check_normal
    jmp .handle_pause_input
    
.check_normal:
    cmp al, 0x01
    je .show_pause
    
.check_down:
    cmp al, 0x50
    je .handle_s_jmp
    
.check_up:
    cmp al, 0x48
    je .handle_w_jmp

.check_left:
    cmp al, 0x4B
    je .handle_left_jmp

.check_right:
    cmp al, 0x4D
    je .handle_right_jmp
    jmp .exit_isr

.handle_s_jmp:
    jmp .handle_s
.handle_w_jmp:
    jmp .handle_w
.handle_left_jmp:
    jmp .handle_left
.handle_right_jmp:
    jmp .handle_right

.show_pause:
    mov byte [paused], 1
    call save_pause_area
    call draw_pause_box
    jmp .exit_isr

.handle_pause_input:
    cmp al, 0x01
    je .resume_game
    cmp al, 0x15
    je .quit_game
    cmp al, 0x31
    je .resume_game
    jmp .exit_isr

.resume_game:
    mov byte [paused], 0
    call restore_pause_area
    jmp .exit_isr

.quit_game:
    mov byte [paused], 0
    mov byte [game_running], 0
    jmp .exit_isr
    
.handle_s:
    mov ax, [car1_y]
    cmp ax, 175
    jge .exit_isr_jmp   
    call erase_car
    
    mov ax, [car1_y]
    add ax, 5
    cmp ax, 175
    jge .exit_isr_jmp
    mov [car1_y], ax
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call draw_player_car
    jmp .exit_isr
    
.handle_w:
    mov ax, [car1_y]
    cmp ax, 10
    jl .exit_isr_jmp   
    call erase_car
    
    mov ax, [car1_y]
    sub ax, 5
    cmp ax, 10
    jl .exit_isr_jmp
    mov [car1_y], ax
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call draw_player_car
    jmp .exit_isr

.exit_isr_jmp:
    jmp .exit_isr

.handle_left:
    mov ax, [car1_x]
    cmp ax, 91
    jle .exit_isr_jmp2 
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call erase_car
    
    mov ax, [car1_x]
    sub ax, 60
    cmp ax, 91
    jl .exit_isr_jmp2
    mov [car1_x], ax
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call draw_player_car
    jmp .exit_isr

.exit_isr_jmp2:
    jmp .exit_isr

.handle_right:
    mov ax, [car1_x]
    cmp ax, 211
    jge .exit_isr_jmp3
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call erase_car
    
    mov ax, [car1_x]
    add ax, 60
    cmp ax, 211
    jg .exit_isr_jmp3
    mov [car1_x], ax
    
    mov si, [car1_x]
    mov ax, [car1_y]
    call draw_player_car
    jmp .exit_isr

.exit_isr_jmp3:
    jmp .exit_isr

.exit_isr:
    mov al, 20h
    out 20h, al
    
    pop es
    pop ds
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret

erase_car:
    push ax
    push si
    mov si, [car1_x]
    mov ax, [car1_y]
    call erase_obstacle_car
    pop si
    pop ax
    ret

save_pause_area:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    push ds
    
    mov ax, 0xA000
    mov ds, ax
    mov ax, cs
    mov es, ax
    
    mov si, 60*320 + 80
    mov di, pause_buffer
    mov dx, 80
.save_row:
    mov cx, 160
    push si
.save_col:
    mov al, [ds:si]
    mov [es:di], al
    inc si
    inc di
    loop .save_col
    pop si
    add si, 320
    dec dx
    jnz .save_row
    
    pop ds
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

restore_pause_area:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    push ds
    
    ; Hide cursor (keep it hidden during game)
    mov ah, 01h
    mov cx, 2607h
    int 0x10
    
    mov ax, cs
    mov ds, ax
    mov ax, 0xA000
    mov es, ax
    
    mov si, pause_buffer
    mov di, 60*320 + 80
    mov dx, 80
.restore_row:
    mov cx, 160
    push di
.restore_col:
    mov al, [ds:si]
    mov [es:di], al
    inc si
    inc di
    loop .restore_col
    pop di
    add di, 320
    dec dx
    jnz .restore_row
    
    pop ds
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_pause_box:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    
    ; Hide cursor
    mov ah, 01h
    mov cx, 2607h
    int 0x10
    
    mov ax, 0xA000
    mov es, ax
    
    mov di, 65*320 + 85
    mov dx, 70
.box_outer:
    mov cx, 150
    mov al, 8
    push di
    rep stosb
    pop di
    add di, 320
    dec dx
    jnz .box_outer
    
    mov di, 70*320 + 90
    mov dx, 60
.box_inner:
    mov cx, 140
    mov al, 7
    push di
    rep stosb
    pop di
    add di, 320
    dec dx
    jnz .box_inner
    
    mov di, 65*320 + 85
    mov cx, 150
    mov al, 15
    rep stosb
    mov di, 66*320 + 85
    mov cx, 150
    mov al, 15
    rep stosb
    
    mov di, 133*320 + 85
    mov cx, 150
    mov al, 15
    rep stosb
    mov di, 134*320 + 85
    mov cx, 150
    mov al, 15
    rep stosb
    
    mov di, 65*320 + 85
    mov dx, 70
.border_left:
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    add di, 320
    dec dx
    jnz .border_left
    
    mov di, 65*320 + 233
    mov dx, 70
.border_right:
    mov byte [es:di], 15
    mov byte [es:di+1], 15
    add di, 320
    dec dx
    jnz .border_right
    
    mov ah, 02h
    mov bh, 0
    mov dh, 12
    mov dl, 12
    int 0x10
    
    mov si, quit_msg
.print_loop:
    lodsb
    cmp al, 0
    je .print_done
    mov ah, 0x09
    mov bl, 0x04
    mov bh, 0
    mov cx, 1
    int 0x10
    mov ah, 0x03
    mov bh, 0
    int 0x10
    inc dl
    mov ah, 0x02
    mov bh, 0
    int 0x10
    jmp .print_loop
.print_done:
    
    pop es
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

wait_vsync:
    push ax
    push dx
    mov dx, 0x3DA
.wn:
    in al, dx
    test al, 8
    jnz .wn
.wv:
    in al, dx
    test al, 8
    jz .wv
    pop dx
    pop ax
    ret

random_lane:
    push bx
    push dx
    push cx
    mov ah, 0
    int 0x1A
    mov al, dl
    xor ah, ah
    mov bl, 3
    div bl
    mov al, ah
    pop cx
    pop dx
    pop bx
    ret

draw_coin:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 4
    mov cx, 1
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 3
    mov cx, 3
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 2
    mov cx, 5
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 1
    mov cx, 7
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov cx, 9
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 1
    mov cx, 7
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 2
    mov cx, 5
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 3
    mov cx, 3
    mov al, 14
    rep stosb
    inc dx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    add di, 4
    mov cx, 1
    mov al, 14
    rep stosb
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

erase_coin:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bx, 9
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov cx, 9
    mov al, 8
    rep stosb
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .nr
    mov ax, si
    cmp ax, 122
    jl .cs
    cmp ax, 133
    jg .cs
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 130
    mov cx, 4
    mov al, 15
    rep stosb
.cs:
    mov ax, si
    cmp ax, 182
    jl .nr
    cmp ax, 193
    jg .nr
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 190
    mov cx, 4
    mov al, 15
    rep stosb
.nr:
    inc dx
    dec bx
    jnz .rl
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_fuel:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bx, 16
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    cmp bx, 16
    jl .cb
    mov cx, 12
    mov al, 14
    rep stosb
    jmp .nx
.cb:
    cmp bx, 2
    jl .bt
    mov cx, 12
    mov al, 4
    rep stosb
    jmp .nx
.bt:
    mov cx, 12
    mov al, 8
    rep stosb
.nx:
    inc dx
    dec bx
    jnz .rl
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

erase_fuel:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bx, 16
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov cx, 12
    mov al, 8
    rep stosb
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .nx
    mov ax, si
    cmp ax, 119
    jl .cs
    cmp ax, 133
    jg .cs
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 130
    mov cx, 4
    mov al, 15
    rep stosb
.cs:
    mov ax, si
    cmp ax, 179
    jl .nx
    cmp ax, 193
    jg .nx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 190
    mov cx, 4
    mov al, 15
    rep stosb
.nx:
    inc dx
    dec bx
    jnz .rl
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

choose_lane_x:
    cmp al, 0
    je .l
    cmp al, 1
    je .c
    mov si, 211
    ret
.c:
    mov si, 151
    ret
.l:
    mov si, 91
    ret

clear_screen:
    push ax
    push cx
    push es
    push di
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 64000
    xor al, al
    rep stosb
    pop di
    pop es
    pop cx
    pop ax
    ret

draw_borders:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov ax, 0xA000
    mov es, ax
    mov dx, 0
.bl:
    cmp dx, 200
    jge .dn
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    mov di, ax
    pop dx
    mov cx, 70
    mov al, 2
    rep stosb
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 250
    mov di, ax
    pop dx
    mov cx, 70
    mov al, 2
    rep stosb
    inc dx
    jmp .bl
.dn:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_three_roads_markings:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xA000
    mov es, ax
    xor bx, bx
.rl:
    cmp bx, 200
    jge .dn
    mov ax, bx
    mov si, ax
    shl si, 8
    mov ax, bx
    shl ax, 6
    add si, ax
    mov di, si
    add di, 70
    mov cx, 180
    mov al, 8
    rep stosb
    mov ax, bx
    and ax, 23
    cmp ax, 12
    jae .sk
    mov di, si
    add di, 130
    mov al, 15
    mov cx, 4
    rep stosb
    mov di, si
    add di, 190
    mov al, 15
    mov cx, 4
    rep stosb
.sk:
    inc bx
    jmp .rl
.dn:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

erase_obstacle_car:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bp, 24
    xor bx, bx
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov cx, 18
    mov al, 8
    rep stosb
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .nx
    mov ax, si
    cmp ax, 113
    jl .cs
    cmp ax, 133
    jg .cs
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 130
    mov cx, 4
    mov al, 15
    rep stosb
.cs:
    mov ax, si
    cmp ax, 173
    jl .nx
    cmp ax, 193
    jg .nx
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 190
    mov cx, 4
    mov al, 15
    rep stosb
.nx:
    inc dx
    inc bx
    dec bp
    jnz .rl
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_obstacle_car:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bp, 24
    xor bx, bx
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov ax, bx
    cmp ax, 2
    jl .fb
    cmp ax, 6
    jl .rs
    cmp ax, 20
    jl .bw
    cmp ax, 24
    jl .rb
    jmp .nx
.fb:
    mov cx, 18
    mov al, 7
    rep stosb
    jmp .nx
.rs:
    mov cx, 3
    mov al, 1
    rep stosb
    mov cx, 12
    mov al, 9
    rep stosb
    mov cx, 3
    mov al, 1
    rep stosb
    jmp .nx
.bw:
    mov ax, bx
    cmp ax, 6
    jl .fy
    cmp ax, 10
    jl .dw
    cmp ax, 16
    jl .fy
    cmp ax, 20
    jl .dw
.fy:
    mov cx, 18
    mov al, 1
    rep stosb
    jmp .nx
.dw:
    mov cx, 3
    xor al, al
    rep stosb
    mov cx, 12
    mov al, 1
    rep stosb
    mov cx, 3
    xor al, al
    rep stosb
    jmp .nx
.rb:
    mov cx, 18
    mov al, 7
    rep stosb
.nx:
    inc dx
    inc bx
    dec bp
    jnz .rl
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_player_car:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov dx, ax
    mov ax, 0xA000
    mov es, ax
    mov bp, 24
    xor bx, bx
.rl:
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, si
    mov ax, bx
    cmp ax, 2
    jl .fb
    cmp ax, 6
    jl .rs
    cmp ax, 20
    jl .bw
    cmp ax, 24
    jl .rb
    jmp .nx
.fb:
    mov cx, 18
    mov al, 7
    rep stosb
    jmp .nx
.rs:
    mov cx, 3
    mov al, 4
    rep stosb
    mov cx, 12
    mov al, 12
    rep stosb
    mov cx, 3
    mov al, 4
    rep stosb
    jmp .nx
.bw:
    mov ax, bx
    cmp ax, 6
    jl .fy
    cmp ax, 10
    jl .dw
    cmp ax, 16
    jl .fy
    cmp ax, 20
    jl .dw
.fy:
    mov cx, 18
    mov al, 4
    rep stosb
    jmp .nx
.dw:
    mov cx, 3
    xor al, al
    rep stosb
    mov cx, 12
    mov al, 4
    rep stosb
    mov cx, 3
    xor al, al
    rep stosb
    jmp .nx
.rb:
    mov cx, 18
    mov al, 7
    rep stosb
.nx:
    inc dx
    inc bx
    dec bp
    jnz .rl
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

animate_obstacle:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Initialize first obstacle car
    call random_lane
    call choose_lane_x
    mov [obs_car1_x], si
    mov word [obs_car1_y], 5
    
    ; Initialize second obstacle car (offset vertically)
    call random_lane
    call choose_lane_x
    mov [obs_car2_x], si
    mov word [obs_car2_y], 80
    
    ; Initialize coin
    call random_lane
    push si
    call choose_lane_x
    add si, 9
    mov bx, si
    pop si
    mov cx, 40
    xor di, di
    
    ; Initialize fuel with higher cooldown
    call random_lane
    push si
    call choose_lane_x
    add si, 3
    mov [fuel_x], si
    pop si
    mov word [fuel_y], 20
    mov word [fuel_cooldown], 150  ; Increased from 0 to 150 for less frequent fuel

.af:
    cmp byte [game_running], 0
    jne .cont
    jmp .dn
.cont:
    cmp byte [paused], 1
    jne .run
    jmp .fd
.run:
    call wait_vsync
    
    ; Draw player car
    push si
    mov ax, [car1_y]
    mov si, [car1_x]
    call draw_player_car
    pop si
    
    ; Handle coin animation
    cmp di, 0
    jne .cc
    push si
    mov si, bx
    mov ax, cx
    call erase_coin
    pop si
    inc cx
    push si
    mov si, bx
    mov ax, cx
    call draw_coin
    pop si
    cmp cx, 191
    jb .ac
    push si
    mov si, bx
    mov ax, cx
    call erase_coin
    pop si
    mov di, 30
    mov cx, 40
    call random_lane
    push si
    call choose_lane_x
    add si, 9
    mov bx, si
    pop si
    jmp .ac
.cc:
    dec di
    cmp di, 0
    jne .ac
    mov cx, 40
.ac:
    ; Animate first obstacle car
    mov si, [obs_car1_x]
    mov ax, [obs_car1_y]
    call erase_obstacle_car
    add word [obs_car1_y], 3  ; Increased from 1 to 2 (2x speed)
    cmp word [obs_car1_y], 176
    jb .ao1
    call random_lane
    call choose_lane_x
    mov [obs_car1_x], si
    mov word [obs_car1_y], 5
.ao1:
    mov si, [obs_car1_x]
    mov ax, [obs_car1_y]
    call draw_obstacle_car
    
    ; Animate second obstacle car
    mov si, [obs_car2_x]
    mov ax, [obs_car2_y]
    call erase_obstacle_car
    add word [obs_car2_y], 3 ; Increased from 1 to 2 (2x speed)
    cmp word [obs_car2_y], 176
    jb .ao2
    call random_lane
    call choose_lane_x
    mov [obs_car2_x], si
    mov word [obs_car2_y], 5
.ao2:
    mov si, [obs_car2_x]
    mov ax, [obs_car2_y]
    call draw_obstacle_car
    
    ; Handle fuel with reduced frequency
    mov ax, [fuel_cooldown]
    cmp ax, 0
    jne .fcd
    push si
    mov si, [fuel_x]
    mov ax, [fuel_y]
    call erase_fuel
    pop si
    inc word [fuel_y]
    push si
    mov si, [fuel_x]
    mov ax, [fuel_y]
    call draw_fuel
    pop si
    cmp word [fuel_y], 184
    jb .afl
    push si
    mov si, [fuel_x]
    mov ax, [fuel_y]
    call erase_fuel
    pop si
    mov word [fuel_cooldown], 200  ; Increased from 50 to 200 for less frequent fuel
    mov word [fuel_y], 20
    call random_lane
    push si
    call choose_lane_x
    add si, 3
    mov [fuel_x], si
    pop si
    jmp .afl
.fcd:
    dec word [fuel_cooldown]
    cmp word [fuel_cooldown], 0
    jne .afl
    mov word [fuel_y], 20
.afl:
.fd:
    push ax
    push dx
    push bx
    push cx
    mov ah, 0
    int 0x1A
    mov bx, dx
.wt:
    mov ah, 0
    int 0x1A
    cmp dx, bx
    je .wt
    pop cx
    pop bx
    pop dx
    pop ax
    jmp .af
.dn:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret

start:
    mov ax, 0x0013
    int 0x10
    
    ; Hide cursor
    mov ah, 01h
    mov cx, 2607h
    int 0x10
    
    call clear_screen
    call draw_borders
    call draw_three_roads_markings
    
    xor ax, ax
    mov es, ax
    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax
    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    sti
    
    mov ax, [car1_y]
    mov si, [car1_x]
    call draw_player_car
    call animate_obstacle

exit_game:
    cli
    xor ax, ax
    mov es, ax
    mov ax, [oldkb]
    mov [es:9*4], ax
    mov ax, [oldkb+2]
    mov [es:9*4+2], ax
    sti
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21
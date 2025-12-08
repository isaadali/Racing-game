org 0x100
jmp start
fuel_x: dw 0
fuel_y: dw 0
fuel_cooldown: dw 0



wait_vsync:
    ; Wait for vertical retrace to eliminate flickering
    push ax
    push dx
    mov dx, 0x3DA
.wait_not_vsync:
    in al, dx
    test al, 8          ; bit 3 = vertical retrace active
    jnz .wait_not_vsync ; wait until not in retrace
.wait_vsync:
    in al, dx
    test al, 8          ; bit 3 = vertical retrace active
    jz .wait_vsync      ; wait until in retrace
    pop dx
    pop ax
    ret

random_lane:
    ; returns AL in {0,1,2}, based on BIOS timer ticks
    push bx
    push dx
    push cx              ; preserve caller's CX (e.g., coin Y)
    mov ah, 0x00
    int 0x1A            ; CX:DX = ticks since midnight (clobbers CX)
    mov al, dl          ; low 8 bits
    xor ah, ah
    mov bl, 3
    div bl              ; AX / 3 -> AH=remainder 0..2
    mov al, ah          ; lane index
    pop cx              ; restore CX
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

    ; row 0: offset 4, width 1
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

    ; row 1: offset 3, width 3
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

    ; row 2: offset 2, width 5
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

    ; row 3: offset 1, width 7
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

    ; row 4: offset 0, width 9
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

    ; row 5: offset 1, width 7
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

    ; row 6: offset 2, width 5
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

    ; row 7: offset 3, width 3
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

    ; row 8: offset 4, width 1
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

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
erase_coin:
    ; Erases coin area by restoring background
    ; AX = top Y, SI = X position
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax
    
    mov bx, 9                ; coin height = 9 rows
    
.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start (SI already points to leftmost pixel)
    
    ; Restore road background (gray) - coin max width is 9 pixels
    mov cx, 9                ; coin width
    mov al, 8                ; gray road color
    rep stosb
    
    ; Restore road markings if needed (12 rows ON, 12 rows OFF)
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .next_row
    
    ; Check if coin overlaps first marking (x=123-126)
    ; Coin overlaps if: SI <= 126 AND SI+8 >= 123
    mov ax, si
    cmp ax, 115              ; 123-8
    jl .check_second_marking
    cmp ax, 126
    jg .check_second_marking
    
    ; Restore first marking (x=123-126)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 123
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.check_second_marking:
    ; Check if coin overlaps second marking (x=196-199)
    mov ax, si
    cmp ax, 188              ; 196-8
    jl .next_row
    cmp ax, 199
    jg .next_row
    
    ; Restore second marking (x=196-199)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 196
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.next_row:
    inc dx                   ; next Y
    dec bx
    jnz .row_loop
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_fuel:
    ; Draws a red rectangular fuel canister
    ; AX = top Y, SI = X position
    ; Fuel size: 12 pixels wide, 16 pixels tall
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax

    mov bx, 16               ; height = 16 rows
    
.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start

    ; Top 2 rows: cap (yellow/orange)
    cmp bx, 16
    jl .check_body
    mov cx, 12
    mov al, 14               ; yellow cap
    rep stosb
    jmp .next_row

.check_body:
    ; Rows 3-14: red body
    cmp bx, 2
    jl .bottom_base
    mov cx, 12
    mov al, 4                ; red fuel body
    rep stosb
    jmp .next_row

.bottom_base:
    ; Bottom 2 rows: base (dark gray)
    mov cx, 12
    mov al, 8                ; gray base
    rep stosb

.next_row:
    inc dx                   ; next Y
    dec bx
    jnz .row_loop

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

erase_fuel:
    ; Erases fuel area by restoring background
    ; AX = top Y, SI = X position
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax
    
    mov bx, 16               ; fuel height = 16 rows
    
.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start
    
    ; Restore road background (gray) - fuel width is 12 pixels
    mov cx, 12               ; fuel width
    mov al, 8                ; gray road color
    rep stosb
    
    ; Restore road markings if needed (12 rows ON, 12 rows OFF)
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .next_row
    
    ; Check if fuel overlaps first marking (x=123-126)
    ; Fuel overlaps if: SI <= 126 AND SI+11 >= 123
    mov ax, si
    cmp ax, 112              ; 123-11
    jl .check_second_marking
    cmp ax, 126
    jg .check_second_marking
    
    ; Restore first marking (x=123-126)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 123
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.check_second_marking:
    ; Check if fuel overlaps second marking (x=196-199)
    mov ax, si
    cmp ax, 185              ; 196-11
    jl .next_row
    cmp ax, 199
    jg .next_row
    
    ; Restore second marking (x=196-199)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 196
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.next_row:
    inc dx                   ; next Y
    dec bx
    jnz .row_loop
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
choose_lane_x:
    ; AL: 0=left, 1=center, 2=right
    cmp al, 0
    je .left
    cmp al, 1
    je .center
.right:
    mov si, 225
    ret
.center:
    mov si, 154
    ret
.left:
    mov si, 75
    ret
scroll_screen_up:
    ; Scrolls entire screen up by 1 row using fast memory move
    ; Copy row 1->row 0, row 2->row 1, etc. (scrolls up)
    ; Objects at higher Y appear to move up visually
    ; So we increment obstacle Y to make them appear to move down
    push ax
    push cx
    push si
    push di
    push ds
    push es
    
    mov ax, 0xA000
    mov ds, ax            ; source segment
    mov es, ax            ; destination segment
    
    ; Move row 1 to row 0, row 2 to row 1, etc.
    ; Source starts at offset 320 (row 1)
    ; Destination starts at offset 0 (row 0)
    mov si, 320           ; source: row 1
    mov di, 0             ; destination: row 0
    mov cx, 31840         ; 199 rows * 160 words = 31840 (320 bytes per row)
    cld                   ; direction forward
    rep movsw             ; move words for speed
    
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

draw_top_row:
    ; Draws the top row (row 0) with road pattern
    ; BP = scroll frame counter (must be preserved by caller)
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0xA000
    mov es, ax
    
    ; Top row base address: 0 * 320 = 0
    xor si, si            ; SI = 0 (base for row 0)
    
    ; Draw left border (x = 0..49)
    mov di, si
    mov cx, 50
    mov al, 0x02          ; green border color
    rep stosb
    
    ; Fill middle road (x = 50..269, width = 220) with gray
    mov di, si
    add di, 50
    mov cx, 220
    mov al, 8             ; gray road color
    rep stosb
    
    ; Draw right border (x = 270..319)
    mov di, si
    add di, 270
    mov cx, 50
    mov al, 0x02          ; green border color
    rep stosb
    
    ; Check if we need road markings (white lines)
    ; Pattern: 12 rows ON, 12 rows OFF -> 24-row cycle
    ; Use scroll frame counter from BP (must be set by caller)
    mov ax, bp            ; use scroll frame counter from BP
    and ax, 23            ; 0..23
    cmp ax, 12
    jae .skip_markers     ; skip if not in ON cycle
    
    ; First divider at x = 123 (50 + 220/3)
    mov di, si
    add di, 123
    mov al, 15            ; white
    mov cx, 4             ; thickness = 4 px
    rep stosb
    
    ; Second divider at x = 196 (50 + 2*(220/3))
    mov di, si
    add di, 196
    mov al, 15            ; white
    mov cx, 4
    rep stosb

.skip_markers:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

animate_obstacle:
    ; AX = start Y, SI = obstacle lane X
    push bp               ; Save BP first (we'll use it for stack access)
    mov bp, sp            ; BP = SP (now we can use [bp+offset])
    
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov dx, ax            ; current obstacle Y (logical Y)
    push ax               ; save previous Y for erasing (initially same as current)

    ; Setup coin
    call random_lane
    push si
    call choose_lane_x
    add si, 9
    mov bx, si            ; BX = coin X
    pop si
    mov cx, 40            ; CX = coin start Y
    xor di, di            ; DI = coin cooldown = 0

    ; Setup fuel - we'll use different registers instead of stack
    ; Use a memory variable approach OR recalculate, OR we can save in unused registers
    ; Since BP is now used for stack frame, let's use memory variables
    
    ; Actually, simpler solution: don't use BP for fuel X
    ; Let's store fuel state in memory variables at the end of code
    
    call random_lane
    push si               ; Save obstacle SI
    call choose_lane_x
    add si, 3             ; Center fuel (12px wide)
    mov [fuel_x], si      ; Store fuel X in memory variable
    pop si                ; Restore obstacle SI
    mov word [fuel_y], 20         ; fuel Y = 20
    mov word [fuel_cooldown], 0   ; fuel cooldown = 0

.anim_frame:
    ; Wait for vertical retrace to eliminate flickering
    call wait_vsync

    ; Draw player car (fixed position at bottom)
    push si
    mov ax, 170
    mov si, 154
    call draw_player_car
    pop si

    ; === COIN LOGIC ===
    cmp di, 0
    jne .coin_cooldown

    ; Erase coin from previous position
    push si
    mov si, bx            ; coin X
    mov ax, cx            ; coin Y (current position)
    call erase_coin
    pop si

    ; Move coin down
    inc cx

    ; Draw coin at new position
    push si
    mov si, bx            ; coin X
    mov ax, cx            ; coin Y (new position)
    call draw_coin
    pop si

    cmp cx, 191           ; limit: 200 - 9 coin height
    jae .coin_reset
    jmp .after_coin

.coin_reset:
    ; Erase coin from bottom position before resetting
    push si
    mov si, bx            ; coin X
    mov ax, cx            ; coin Y (at bottom, 191)
    call erase_coin
    pop si
    
    mov di, 30            ; Start cooldown
    mov cx, 40            ; Reset Y
    call random_lane
    push si
    call choose_lane_x
    add si, 9
    mov bx, si
    pop si
    jmp .after_coin

.coin_cooldown:
    dec di
    cmp di, 0
    jne .after_coin
    mov cx, 40            ; Cooldown done, reset Y

.after_coin:
    ; === OBSTACLE CAR LOGIC ===
    ; Erase obstacle car from previous position
    pop ax                ; get previous Y position
    call erase_obstacle_car
    
    ; Draw obstacle car at current position
    mov ax, dx
    call draw_obstacle_car

    ; Save current Y as previous before incrementing
    push dx               ; save current Y as previous for next frame
    
    ; Move car down
    inc dx
    cmp dx, 176           ; limit: 200 - 24 car height
    jae .obstacle_respawn
    jmp .after_obstacle

.obstacle_respawn:
    ; Erase car from bottom position before respawning
    pop ax                ; get previous Y (which should be at or near bottom)
    call erase_obstacle_car
    
    mov dx, 5             ; Reset to top
    call random_lane
    call choose_lane_x
    push dx               ; save new Y as previous for next frame

.after_obstacle:
    ; === FUEL LOGIC ===
    mov ax, [fuel_cooldown]   ; Get fuel cooldown from memory
    cmp ax, 0                 ; Check if visible
    jne .fuel_cooldown_dec

    ; Visible: erase old, move, draw new
    push si
    mov si, [fuel_x]          ; SI = fuel X from memory
    mov ax, [fuel_y]          ; AX = fuel Y from memory
    call erase_fuel
    pop si

    inc word [fuel_y]         ; Move fuel Y down

    push si
    mov si, [fuel_x]          ; SI = fuel X
    mov ax, [fuel_y]          ; AX = fuel Y (new position)
    call draw_fuel
    pop si

    cmp word [fuel_y], 184    ; Check if reached bottom (200-16)
    jae .fuel_reset
    jmp .after_fuel

.fuel_reset:
    ; Erase fuel from bottom position before resetting
    push si
    mov si, [fuel_x]          ; SI = fuel X
    mov ax, [fuel_y]          ; AX = fuel Y (at bottom, 184)
    call erase_fuel
    pop si
    
    mov word [fuel_cooldown], 50  ; Start cooldown (50 frames)
    mov word [fuel_y], 20         ; Reset Y to top
    call random_lane
    push si
    call choose_lane_x
    add si, 3
    mov [fuel_x], si              ; Update fuel X
    pop si
    jmp .after_fuel

.fuel_cooldown_dec:
    dec word [fuel_cooldown]      ; Decrease cooldown
    cmp word [fuel_cooldown], 0
    jne .after_fuel
    mov word [fuel_y], 20         ; Cooldown done, reset Y

.after_fuel:
    ; === FRAME DELAY ===
    jmp .delay_and_next

.delay_and_next:
    ; Simple frame delay via BIOS tick
    push ax
    push dx
    push bx
    push cx
    mov ah, 0x00
    int 0x1A
    mov bx, dx
.wait_tick:
    mov ah, 0x00
    int 0x1A
    cmp dx, bx
    je  .wait_tick
    pop cx
    pop bx
    pop dx
    pop ax

    jmp .anim_frame

.done:
    pop ax                ; pop previous Y from stack (cleanup)
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp                ; Restore BP
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
.border_loop:
    cmp dx, 200
    jge near .done
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    mov di, ax
    pop dx
    mov cx, 50           ; left border width(50 px)
    mov al, 0x02 
    rep stosb
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 270        ;   right border starts at 270
    mov di, ax
    pop dx
    mov cx, 50           
    mov al, 0x02 
    rep stosb
    inc dx
    jmp .border_loop
.done:
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

    xor bx, bx                ; y = 0
.row_loop:
    cmp bx, 200
    jge .done

    ; base = y * 320 = y*256 + y*64
    mov ax, bx
    mov si, ax
    shl si, 8                 ; y*256
    mov ax, bx
    shl ax, 6                 ; y*64
    add si, ax                ; SI = base

    ; Fill middle road (x = 50..269, width = 220) with gray (08h)
    mov di, si
    add di, 50
    mov cx, 220
    mov al, 8
    rep stosb

    ; 12 rows ON, 12 rows OFF -> 24-row cycle (static, no scroll)
    mov ax, bx
    and ax, 23
    cmp ax, 12
    jae .skip_markers

    ; First divider at x = 123 (50 + 220/3)
    mov di, si
    add di, 123
    mov al, 15                ; white
    mov cx, 4                 ; thickness = 4 px
    rep stosb

    ; Second divider at x = 196 (50 + 2*(220/3))
    mov di, si
    add di, 196
    mov al, 15
    mov cx, 4
    rep stosb

.skip_markers:
    inc bx
    jmp .row_loop

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

erase_obstacle_car:
    ; Erases obstacle car area by restoring background
    ; AX = top Y, SI = X position
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    
    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax
    
    mov bp, 24               ; height = 24 rows
    xor bx, bx               ; row index = 0
    
.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start
    
    ; Restore road background (gray)
    mov cx, 18               ; car width
    mov al, 8                ; gray road color
    rep stosb
    
    ; Restore road markings if needed (12 rows ON, 12 rows OFF)
    mov ax, dx
    and ax, 23
    cmp ax, 12
    jae .next_row
    
    ; Check if car overlaps first marking (x=123-126)
    ; Car (width 18) overlaps if: SI <= 126 AND SI+17 >= 123, i.e., SI >= 106 AND SI <= 126
    mov ax, si
    cmp ax, 106
    jl .check_second_marking
    cmp ax, 126
    jg .check_second_marking
    
    ; Restore first marking (x=123-126)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 123
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.check_second_marking:
    ; Check if car overlaps second marking (x=196-199)
    ; Car (width 18) overlaps if: SI <= 199 AND SI+17 >= 196, i.e., SI >= 179 AND SI <= 199
    mov ax, si
    cmp ax, 179
    jl .next_row
    cmp ax, 199
    jg .next_row
    
    ; Restore second marking (x=196-199)
    mov ax, dx
    mov di, ax
    shl di, 8
    mov ax, dx
    shl ax, 6
    add di, ax
    add di, 196
    mov cx, 4
    mov al, 15               ; white
    rep stosb
    
.next_row:
    inc dx                   ; next Y
    inc bx                   ; row index++
    dec bp
    jnz .row_loop
    
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
    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax

    mov bp, 24               ; height = 24 rows (was 30)
    xor bx, bx               ; row index = 0
.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start

    ; Decide row band
    mov ax, bx
    cmp ax, 2
    jl .front_bumper         ; rows 0-1

    cmp ax, 6
    jl .roof_stripe          ; rows 2-5

    cmp ax, 20
    jl .body_or_wheels       ; rows 6-19

    cmp ax, 24
    jl .rear_bumper          ; rows 20-23

    jmp .next_row

.front_bumper:
    mov cx, 18               ; full-width bumper
    mov al, 7                ; light gray
    rep stosb
    jmp .next_row

.roof_stripe:
    mov cx, 3
    mov al, 1                ; blue edges
    rep stosb
    mov cx, 12
    mov al, 9                ; light blue stripe
    rep stosb
    mov cx, 3
    mov al, 1
    rep stosb
    jmp .next_row

.body_or_wheels:
    ; front wheels band: rows 6..9
    mov ax, bx
    cmp ax, 6
    jl .full_body
    cmp ax, 10
    jl .draw_wheels

    ; rear wheels band: rows 16..19
    cmp ax, 16
    jl .full_body
    cmp ax, 20
    jl .draw_wheels

.full_body:
    mov cx, 18
    mov al, 1                ; body blue
    rep stosb
    jmp .next_row

.draw_wheels:
    mov cx, 3
    xor al, al               ; black wheel
    rep stosb
    mov cx, 12
    mov al, 1                ; body center blue
    rep stosb
    mov cx, 3
    xor al, al               ; black wheel
    rep stosb
    jmp .next_row

.rear_bumper:
    mov cx, 18
    mov al, 7
    rep stosb
    jmp .next_row

.next_row:
    inc dx                   ; next Y
    inc bx                   ; row index++
    dec bp
    jnz .row_loop

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

    mov dx, ax               ; top Y
    mov ax, 0xA000
    mov es, ax

    mov bp, 24               ; height = 24 rows (was 30)
    xor bx, bx               ; row index = 0

.row_loop:
    ; base = y * 320 = y*256 + y*64
    mov ax, dx
    mov di, ax
    shl di, 8                ; y*256 -> DI
    mov ax, dx
    shl ax, 6                ; y*64
    add di, ax               ; DI = base
    add di, si               ; X start

    ; Decide row band
    mov ax, bx
    cmp ax, 2
    jl .front_bumper         ; rows 0-1

    cmp ax, 6
    jl .roof_stripe          ; rows 2-5

    cmp ax, 20
    jl .body_or_wheels       ; rows 6-19

    cmp ax, 24
    jl .rear_bumper          ; rows 20-23

    jmp .next_row

.front_bumper:
    mov cx, 18               ; full-width bumper
    mov al, 7                ; light gray
    rep stosb
    jmp .next_row

.roof_stripe:
    mov cx, 3                ; edge (body color)
    mov al, 4                ; red
    rep stosb
    mov cx, 12               ; roof stripe (lighter red)
    mov al, 12
    rep stosb
    mov cx, 3
    mov al, 4                ; red
    rep stosb
    jmp .next_row

.body_or_wheels:
    ; front wheels band: rows 6..9
    mov ax, bx
    cmp ax, 6
    jl .full_body
    cmp ax, 10
    jl .draw_wheels

    ; rear wheels band: rows 16..19
    cmp ax, 16
    jl .full_body
    cmp ax, 20
    jl .draw_wheels

.full_body:
    mov cx, 18               ; full body
    mov al, 4                ; red
    rep stosb
    jmp .next_row

.draw_wheels:
    mov cx, 3                ; left wheel
    xor al, al               ; black
    rep stosb
    mov cx, 12               ; body center
    mov al, 4                ; red
    rep stosb
    mov cx, 3                ; right wheel
    xor al, al               ; black
    rep stosb
    jmp .next_row

.rear_bumper:
    mov cx, 18               ; full-width bumper
    mov al, 7                ; light gray
    rep stosb
    jmp .next_row

.next_row:
    inc dx
    inc bx
    dec bp
    jnz .row_loop

    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

start:
    ; Set video mode 13h (320x200, 256 colors)
    mov ax, 0x0013
    int 0x10

    ; Draw background (black screen)
    call clear_screen
    call draw_borders
    call draw_three_roads_markings

    ; Start animation: obstacle in right lane, from Y=5
    mov si, 225
    mov ax, 5
    call animate_obstacle

    ; Unreachable after animate_obstacle loop unless you add exit logic:
    ; Key pressed - exit (left here if you later add exit inside animate loop)
    xor ah, ah
    int 0x16             ; Clear keyboard buffer

    ; Restore text mode and exit
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4c00
    int 0x21
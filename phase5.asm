org 0x100

start:
    mov ax, cs
    mov ss, ax
    mov sp, 0xFFFE
    mov ax, 0x0013
    int 0x10
    call clear_screen
    call copy_buffer_to_screen
    ;call show_start_screen
    cmp byte [quit_flag], 1
    je near exit_program
    call clear_screen
    call copy_buffer_to_screen
    call input_screen
    cmp byte [quit_flag], 1
    je near exit_program
    call clear_screen
    call copy_buffer_to_screen
    call instruction_screen
    cmp byte [quit_flag], 1
    je near exit_program

    call clear_screen
    call draw_borders
    call draw_road
    call draw_fuel_bar
    call draw_score
    call copy_buffer_to_screen

  xor ax, ax
    mov es, ax
    mov ax, [es:9*4]
    mov [oldisr], ax
    mov ax, [es:9*4+2]
    mov [oldisr+2], ax
    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    sti

    ; Hook timer interrupt for fuel consumption
    mov ax, [es:0x1C*4]
    mov [oldtimer], ax
    mov ax, [es:0x1C*4+2]
    mov [oldtimer+2], ax
    cli
    mov word [es:0x1C*4], timer_isr
    mov [es:0x1C*4+2], cs
    sti
 call init_animation

anim_loop:
    cmp byte [paused], 1
    je .paused_state
    call draw_road
    
    ; Update road scroll for animation
    inc word [road_scroll]
    cmp word [road_scroll], 16
    jl .skip_scroll_reset
    mov word [road_scroll], 0
.skip_scroll_reset:

    call handle_player_input
    call animate_frame
    call draw_fuel_bar
    call draw_score
    call copy_buffer_to_screen
    jmp .check_input
.paused_state:
    call draw_pause_message
    call copy_buffer_to_screen
.check_input:
    cmp byte [flag], 2
    je near game_over_screen
    cmp byte [game_over_collision], 1
    je near game_over_screen
    cmp byte [game_over_fuel], 1
    je near game_over_screen
    call delay_tick
    jmp anim_loop

; ============================================
; TIMER ISR - For Fuel Consumption
; ============================================
timer_isr:
    push ax
    push ds
    push cs
    pop ds
    
    cmp byte [paused], 1
    je .skip_fuel_decrease
    
    inc byte [fuel_tick_counter]
    mov al, [FUEL_DECREASE_RATE]
    cmp [fuel_tick_counter], al
    jb .skip_fuel_decrease
    
    mov byte [fuel_tick_counter], 0
    
    cmp word [current_fuel], 0
    je .fuel_empty
    dec word [current_fuel]
    jmp .skip_fuel_decrease
    
.fuel_empty:
    mov byte [game_over_fuel], 1
    
.skip_fuel_decrease:
    pop ds
    pop ax
    jmp far [cs:oldtimer]

; ============================================
; KEYBOARD ISR
; ============================================
kbisr:
    push ax
    push es
    push ds
    push cs
    pop ds
    in al, 0x60
    cmp byte [cs:flag], 0
    jne .check_esc
    mov byte [cs:flag], 1
    jmp .end_isr
.check_esc:
    cmp al, 0x01
    jne .check_left
    cmp byte [cs:paused], 1
    je .unpause
    mov byte [cs:paused], 1
    jmp .end_isr
.unpause:
    mov byte [cs:paused], 0
    jmp .end_isr
.check_left:
    cmp al, 0x4B
    jne .check_right
    cmp byte [cs:paused], 0
    jne near .end_isr
    cmp byte [cs:move_cooldown], 0
    jne near .end_isr
    mov byte [cs:left_pressed], 1
    mov al, [cs:MOVE_COOLDOWN_TIME]
    mov [cs:move_cooldown], al
    jmp .end_isr
.check_right:
    cmp al, 0x4D
    jne .check_up
    cmp byte [cs:paused], 0
    jne .end_isr
    cmp byte [cs:move_cooldown], 0
    jne .end_isr
    mov byte [cs:right_pressed], 1
    mov al, [cs:MOVE_COOLDOWN_TIME]
    mov [cs:move_cooldown], al
    jmp .end_isr
.check_up:
    cmp al, 0x48
    jne .check_down
    cmp byte [cs:paused], 0
    jne .end_isr
    mov byte [cs:up_pressed], 1
    jmp .end_isr
.check_down:
    cmp al, 0x50
    jne .check_y
    cmp byte [cs:paused], 0
    jne .end_isr
    mov byte [cs:down_pressed], 1
    jmp .end_isr
.check_y:
    cmp byte [cs:paused], 1
    jne .check_n
    cmp al, 0x15
    jne .check_n
    mov byte [cs:flag], 2
    jmp .end_isr
.check_n:
    cmp byte [cs:paused], 1
    jne .end_isr
    cmp al, 0x31
    jne .end_isr
    mov byte [cs:paused], 0
.end_isr:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop es
    pop ax
    iret

; ============================================
; EXIT ROUTINE
; ============================================
exit_program:
    ; Unhook timer interrupt
    cmp word [oldtimer], 0
    je .skip_timer_unhook
    cli
    xor ax, ax
    mov es, ax
    mov ax, [oldtimer]
    mov [es:0x1C*4], ax
    mov ax, [oldtimer+2]
    mov [es:0x1C*4+2], ax
    sti
.skip_timer_unhook:
    ; Unhook keyboard interrupt
    cmp word [oldisr], 0
    je .skip_unhook
    cli
    xor ax, ax
    mov es, ax
    mov ax, [oldisr]
    mov [es:9*4], ax
    mov ax, [oldisr+2]
    mov [es:9*4+2], ax
    sti
.skip_unhook:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21


;xor ax, ax
 ;   int 0x16
  ;  mov ax, 0x0003
   ; int 0x10
    ;mov ax, 0x4C00
    ;int 0x21

draw_fuel_bar:
push ax
push bx
push cx
push dx
push es
push di
mov ax, [buffer_segment]
mov es, ax

; Draw fuel bar border
mov ax, 187
mov bx, 320
mul bx
add ax, 265
mov di, ax

; Top border
mov al, 0x0F
mov cx, 38
rep stosb

; Calculate fuel percentage and bar length
mov ax, [current_fuel]
mov bx, [MAX_FUEL]
cmp bx, 0
je .empty_fuel

mov dx, 0
mov cx, 34
mul cx
div bx
mov cx, ax  ; CX = fuel bar length (0-34)
jmp .draw_bar
.empty_fuel:
mov cx, 0
.draw_bar:
; Determine color based on fuel level
mov ax, [current_fuel]
mov bx, [MAX_FUEL]
mov dx, 0
push cx
mov cx, 100
mul cx
pop cx
div bx
; AX now contains fuel percentage (0-100)
mov bl, 0x02  ; Green (default)
cmp ax, 50
jg .set_color
mov bl, 0x0E  ; Yellow
cmp ax, 25
jg .set_color
mov bl, 0x04  ; Red
.set_color:
mov al, bl
; Draw 6 rows of fuel bar
mov dx, 6
sub di, 38
add di, 320
.fuel_loop:
push cx
push di
; Left border
mov byte [es:di], 0x0F
mov byte [es:di+1], 0x0F
add di, 2

; Filled portion
push cx
mov al, bl  ; Use calculated color
rep stosb
pop cx

; Calculate empty portion
mov ax, 34
sub ax, cx
mov cx, ax

; Empty portion (black)
mov al, 0x00
rep stosb

; Right border
mov byte [es:di], 0x0F
mov byte [es:di+1], 0x0F

pop di
pop cx
add di, 320
dec dx
jnz .fuel_loop

; Bottom border
mov al, 0x0F
mov cx, 38
rep stosb

pop di
pop es
pop dx
pop cx
pop bx
pop ax
ret
; ============================================
; SCREEN FUNCTIONS
; ============================================
show_start_screen:
    call clear_screen
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 5
    mov dl, 10
    int 0x10
    call clear_screen
    mov si, game_title
    call print_string_yellow
    mov ah, 0x02
    mov dh, 8
    mov dl, 2
    int 0x10
    mov si, dev_names
    call print_string_white
    mov ah, 0x02
    mov dh, 10
    mov dl, 2
    int 0x10
    mov si, roll_nos
    call print_string_white
    mov ah, 0x02
    mov dh, 18
    mov dl, 8
    int 0x10
    mov si, press_start
    call print_string_white
.wait_key:
    mov ah, 0x00
    int 0x16
    call clear_screen
    cmp al, 27
    je .confirm_exit
    ret
.confirm_exit:
    call confirm_screen
    cmp byte [quit_flag], 1
    je .ret
    jmp show_start_screen
.ret:
    ret

input_screen:
    call clear_screen
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 8
    mov dl, 5
    int 0x10
    call clear_screen
    mov si, input_prompt_name
    call print_string_white
    mov di, player_name_buf
    call get_input_string
    cmp byte [quit_flag], 1
    je .ret
    mov ah, 0x02
    mov dh, 10
    mov dl, 5
    int 0x10
    mov si, input_prompt_roll
    call print_string_white
    mov di, player_roll_buf
    call get_input_string
.ret:
    ret

instruction_screen:
    call clear_screen
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 4
    mov dl, 10
    int 0x10
    call clear_screen
    mov si, instr_title
    call print_string_yellow
    mov ah, 0x02
    mov dh, 8
    mov dl, 5
    int 0x10
    mov si, instr_1
    call print_string_white
    mov ah, 0x02
    mov dh, 10
    mov dl, 5
    int 0x10
    mov si, instr_2
    call print_string_white
    mov ah, 0x02
    mov dh, 12
    mov dl, 5
    int 0x10
    mov si, instr_3
    call print_string_white
    mov ah, 0x02
    mov dh, 14
    mov dl, 5
    int 0x10
    mov si, instr_4
    call print_string_white
    mov ah, 0x02
    mov dh, 16
    mov dl, 5
    int 0x10
    mov si, instr_5
    call print_string_white
    mov ah, 0x02
    mov dh, 20
    mov dl, 8
    int 0x10
    mov si, instr_press
    call print_string_white
.wait_key:
    mov ah, 0x00
    int 0x16
    call clear_screen
    cmp al, 27
    je .confirm_exit
    ret
.confirm_exit:
    call confirm_screen
    cmp byte [quit_flag], 1
    je .ret
    jmp instruction_screen
.ret:
    ret

game_over_screen:
    ; Unhook interrupts
    cli
    xor ax, ax
    mov es, ax
    
    ; Unhook timer
    cmp word [oldtimer], 0
    je .skip_timer
    mov ax, [oldtimer]
    mov [es:0x1C*4], ax
    mov ax, [oldtimer+2]
    mov [es:0x1C*4+2], ax
.skip_timer:
    
    ; Unhook keyboard
    mov ax, [oldisr]
    mov [es:9*4], ax
    mov ax, [oldisr+2]
    mov [es:9*4+2], ax
    sti
    
    mov word [oldisr], 0
    mov word [oldtimer], 0
    
    mov ax, 0x0003
    int 0x10
    call clear_screen
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 6
    mov dl, 35
    int 0x10
    mov si, game_over_msg
    call print_string_red
    
    ; Show game over reason
    mov ah, 0x02
    mov dh, 8
    mov dl, 30
    int 0x10
    cmp byte [game_over_collision], 1
    je .show_collision
    cmp byte [game_over_fuel], 1
    je .show_fuel
    jmp .show_player
.show_collision:
    mov si, collision_msg
    call print_string_red
    jmp .show_player
.show_fuel:
    mov si, fuel_empty_msg
    call print_string_red
    
.show_player:
    mov ah, 0x02
    mov dh, 11
    mov dl, 30
    int 0x10
    mov si, player_label
    call print_string_white
    mov ah, 0x02
    mov dh, 11
    mov dl, 38
    int 0x10
    mov si, player_name_buf
    call print_string_yellow
    mov ah, 0x02
    mov dh, 13
    mov dl, 30
    int 0x10
    mov si, roll_label
    call print_string_white
    mov ah, 0x02
    mov dh, 13
    mov dl, 39
    int 0x10
    mov si, player_roll_buf
    call print_string_yellow
    
    ; Show final score
    mov ah, 0x02
    mov dh, 15
    mov dl, 30
    int 0x10
    mov si, final_score_label
    call print_string_white
    mov ah, 0x02
    mov dh, 15
    mov dl, 44
    int 0x10
    mov ax, [score]
    call print_number_yellow
    
    mov ah, 0x02
    mov dh, 19
    mov dl, 22
    int 0x10
    mov si, play_again_msg
    call print_string_white
.wait_choice:
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je start
    cmp al, 27
    je exit_program
    jmp .wait_choice

confirm_screen:
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 12
    mov dl, 14
    int 0x10
    mov si, confirm_msg
    call print_string_red
.wait_yn:
    mov ah, 0x00
    int 0x16
    cmp al, 'y'
    je .yes
    cmp al, 'Y'
    je .yes
    cmp al, 'n'
    je .no
    cmp al, 'N'
    je .no
    jmp .wait_yn
.yes:
    mov byte [quit_flag], 1
    ret
.no:
    mov byte [quit_flag], 0
    ret

; ============================================
; PRINT FUNCTIONS
; ============================================
print_string_white:
    mov bl, 0x0F
    jmp print_string_common
print_string_yellow:
    mov bl, 0x0E
    jmp print_string_common
print_string_red:
    mov bl, 0x0C
    jmp print_string_common
print_string_common:
    mov ah, 0x0E
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

print_number_yellow:
    push ax
    push bx
    push cx
    push dx
    
    mov cx, 0
    mov bx, 10
.divide_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    cmp ax, 0
    jne .divide_loop
    
.print_loop:
    pop ax
    add al, '0'
    mov ah, 0x0E
    mov bl, 0x0E
    int 0x10
    loop .print_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

get_input_string:
    xor cx, cx
.input_loop:
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .handle_esc
    cmp al, 13
    je .done_input
    cmp al, 8
    je .handle_backspace
    cmp cx, 19
    jge .input_loop
    stosb
    inc cx
    mov ah, 0x0E
    int 0x10
    jmp .input_loop
.handle_backspace:
    cmp cx, 0
    je .input_loop
    dec di
    dec cx
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .input_loop
.handle_esc:
    call confirm_screen
    cmp byte [quit_flag], 1
    je .esc_quit
    jmp .input_loop
.esc_quit:
    ret
.done_input:
    mov byte [di], 0
    ret

; ============================================
; GAME INIT & INPUT
; ============================================
init_animation:
    mov word [player_x], 160
    mov word [player_y], 175
    mov byte [obstacle_active], 0
    mov byte [obstacle_counter], 0
    mov byte [left_pressed], 0
    mov byte [right_pressed], 0
    mov byte [up_pressed], 0
    mov byte [down_pressed], 0
    mov byte [current_lane], 1
    mov word [road_scroll], 0
    mov byte [paused], 0
    mov byte [coin1_active], 0
    mov byte [coin2_active], 0
    mov byte [coin3_active], 0
    mov byte [coin_counter], 35
    mov byte [fuel1_active], 0
    mov byte [fuel2_active], 0
    mov byte [fuel_counter], 55
    mov word [score], 0
    mov ax, [MAX_FUEL]
    mov [current_fuel], ax
    mov byte [fuel_tick_counter], 0
    mov byte [move_cooldown], 0
    mov byte [game_over_collision], 0
    mov byte [game_over_fuel], 0
    ret

handle_player_input:
    cmp byte [paused], 1
    je near .skip_input
    push ax
    push bx
    
    ; Decrease move cooldown
    cmp byte [move_cooldown], 0
    je .check_moves
    dec byte [move_cooldown]
    
.check_moves:
    cmp byte [left_pressed], 1
    jne .check_right_input
    cmp byte [current_lane], 0
    je near .skip_left
    
    ; Check collision before moving left
    mov al, [current_lane]
    dec al
    call check_collision_in_lane
    cmp al, 1
    je near .collision_detected
    
    dec byte [current_lane]
    mov byte [left_pressed], 0
    jmp .update_x_pos
    
.check_right_input:
    cmp byte [right_pressed], 1
    jne .check_up
    cmp byte [current_lane], 2
    je .skip_right
    
    ; Check collision before moving right
    mov al, [current_lane]
    inc al
    call check_collision_in_lane
    cmp al, 1
    je .collision_detected
    
    inc byte [current_lane]
    mov byte [right_pressed], 0
    jmp .update_x_pos
    
.check_up:
    cmp byte [up_pressed], 1
    jne .check_down
    cmp word [player_y], 15
    jle .skip_up
    sub word [player_y], 4
    mov byte [up_pressed], 0
    jmp .done_input
.check_down:
    cmp byte [down_pressed], 1
    jne .done_input
    cmp word [player_y], 175
    jge .skip_down
    add word [player_y], 4
    mov byte [down_pressed], 0
    jmp .done_input
.update_x_pos:
    movzx ax, byte [current_lane]
    mov bx, 40
    mul bx
    add ax, 120
    mov [player_x], ax
.skip_left:
.skip_up:
.skip_down:
.skip_right:
.done_input:
    pop bx
    pop ax
.skip_input:
    ret

.collision_detected:
    ; Draw collision spark
    mov ax, [player_x]
    mov bx, [player_y]
    call draw_collision_spark
    call copy_buffer_to_screen
    
    ; Delay to show spark
    mov cx, 5
.spark_delay:
    push cx
    call delay_tick
    call delay_tick
    pop cx
    loop .spark_delay
    
    mov byte [game_over_collision], 1
    mov byte [left_pressed], 0
    mov byte [right_pressed], 0
    jmp .done_input

; ============================================
; COLLISION DETECTION
; ============================================
check_collision_in_lane:
    ; Input: AL = lane to check (0, 1, or 2)
    ; Output: AL = 1 if collision, 0 if safe
    push bx
    push cx
    push dx
    
    ; Convert lane to x position
    movzx bx, al
    mov cx, 40
    mov ax, bx
    mul cx
    add ax, 120
    mov bx, ax  ; BX = lane x position
    
    ; Check if obstacle is in this lane
    cmp byte [obstacle_active], 0
    je .no_collision
    
    mov ax, [obstacle_x]
    sub ax, 5
    cmp bx, ax
    jl .no_collision
    mov ax, [obstacle_x]
    add ax, 5
    cmp bx, ax
    jg .no_collision
    
    ; Check Y overlap
    mov ax, [player_y]
    sub ax, 20
    mov cx, ax
    mov ax, [player_y]
    add ax, 20
    mov dx, ax
    
    mov ax, [obstacle_y]
    cmp ax, cx
    jl .no_collision
    cmp ax, dx
    jg .no_collision
    
    ; Collision detected
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.no_collision:
    pop dx
    pop cx
    pop bx
    mov al, 0
    ret

check_collision_with_obstacle:
    ; Check if player collides with obstacle
    push bx
    push cx
    push dx
    
    cmp byte [obstacle_active], 0
    je .no_collision
    
    ; Check if they're in the same lane first
    mov ax, [player_x]
    mov bx, [obstacle_x]
    sub ax, bx
    
    ; Check X overlap (within 15 pixels = same lane approximately)
    cmp ax, -15
    jl .no_collision
    cmp ax, 15
    jg .no_collision
    
    ; They're in same lane, now check Y overlap
    ; Player car is 14 pixels tall, obstacle is 14 pixels tall
    mov ax, [player_y]
    mov bx, [obstacle_y]
    sub ax, bx
    
    ; If distance between centers is less than 14, they're colliding
    cmp ax, -14
    jl .no_collision
    cmp ax, 14
    jg .no_collision
    
    ; Collision detected!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.no_collision:
    pop dx
    pop cx
    pop bx
    mov al, 0
    ret
draw_collision_spark:
    ; Draw yellow spark at collision point
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    
    mov cx, ax
    mov ax, bx
    mov bx, 320
    mul bx
    add ax, cx
    mov di, ax
    
    mov ax, [buffer_segment]
    mov es, ax
    
    ; Draw spark pattern
    mov al, 0x0E  ; Yellow
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di-1], al
    mov byte [es:di+320], al
    mov byte [es:di-320], al
    mov byte [es:di+321], al
    mov byte [es:di-321], al
    mov byte [es:di+319], al
    mov byte [es:di-319], al
    
    add di, 640
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di-1], al
    sub di, 1280
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di-1], al
    
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================
; COLLISION AND PICKUP CHECKS
; ============================================
check_coin_collision:
    push ax
    push bx
    push cx
    push dx
    
    ; Check coin 1
    cmp byte [coin1_active], 0
    je .check_coin2
    
    ; Get absolute difference in X
    mov ax, [player_x]
    mov bx, [coin1_x]
    sub ax, bx
    ; Check if difference is negative
    jns .x1_positive
    neg ax
.x1_positive:
    cmp ax, 15  ; Increased collision range
    jg .check_coin2
    
    ; Get absolute difference in Y
    mov ax, [player_y]
    mov bx, [coin1_y]
    sub ax, bx
    jns .y1_positive
    neg ax
.y1_positive:
    cmp ax, 15  ; Increased collision range
    jg .check_coin2
    
    ; Coin collected!
    mov byte [coin1_active], 0
    add word [score], 10
    
.check_coin2:
    cmp byte [coin2_active], 0
    je .check_coin3
    
    ; Get absolute difference in X
    mov ax, [player_x]
    mov bx, [coin2_x]
    sub ax, bx
    jns .x2_positive
    neg ax
.x2_positive:
    cmp ax, 15
    jg .check_coin3
    
    ; Get absolute difference in Y
    mov ax, [player_y]
    mov bx, [coin2_y]
    sub ax, bx
    jns .y2_positive
    neg ax
.y2_positive:
    cmp ax, 15
    jg .check_coin3
    
    ; Coin collected!
    mov byte [coin2_active], 0
    add word [score], 10
    
.check_coin3:
    cmp byte [coin3_active], 0
    je .done_coins
    
    ; Get absolute difference in X
    mov ax, [player_x]
    mov bx, [coin3_x]
    sub ax, bx
    jns .x3_positive
    neg ax
.x3_positive:
    cmp ax, 15
    jg .done_coins
    
    ; Get absolute difference in Y
    mov ax, [player_y]
    mov bx, [coin3_y]
    sub ax, bx
    jns .y3_positive
    neg ax
.y3_positive:
    cmp ax, 15
    jg .done_coins
    
    ; Coin collected!
    mov byte [coin3_active], 0
    add word [score], 10
    
.done_coins:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
check_fuel_collision:
    push ax
    push bx
    push cx
    push dx
    
    ; Check fuel 1
    cmp byte [fuel1_active], 0
    je .check_fuel2
    
    ; Get absolute difference in X
    mov ax, [player_x]
    mov bx, [fuel1_x]
    sub ax, bx
    jns .x1_positive
    neg ax
.x1_positive:
    cmp ax, 15
    jg .check_fuel2
    
    ; Get absolute difference in Y
    mov ax, [player_y]
    mov bx, [fuel1_y]
    sub ax, bx
    jns .y1_positive
    neg ax
.y1_positive:
    cmp ax, 15
    jg .check_fuel2
    
    ; Fuel collected!
    mov byte [fuel1_active], 0
    mov ax, [current_fuel]
    add ax, [FUEL_REFILL_AMOUNT]
    mov bx, [MAX_FUEL]
    cmp ax, bx
    jle .set_fuel1
    mov ax, bx
.set_fuel1:
    mov [current_fuel], ax
    
.check_fuel2:
    cmp byte [fuel2_active], 0
    je .done_fuel
    
    ; Get absolute difference in X
    mov ax, [player_x]
    mov bx, [fuel2_x]
    sub ax, bx
    jns .x2_positive
    neg ax
.x2_positive:
    cmp ax, 15
    jg .done_fuel
    
    ; Get absolute difference in Y
    mov ax, [player_y]
    mov bx, [fuel2_y]
    sub ax, bx
    jns .y2_positive
    neg ax
.y2_positive:
    cmp ax, 15
    jg .done_fuel
    
    ; Fuel collected!
    mov byte [fuel2_active], 0
    mov ax, [current_fuel]
    add ax, [FUEL_REFILL_AMOUNT]
    mov bx, [MAX_FUEL]
    cmp ax, bx
    jle .set_fuel2
    mov ax, bx
.set_fuel2:
    mov [current_fuel], ax
    
.done_fuel:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

delay_tick:
    push ax
    push cx
    push dx
    mov ah, 0
    int 0x1A
    mov cx, dx
.wait_next:
    mov ah, 0
    int 0x1A
    cmp dx, cx
    je .wait_next
    pop dx
    pop cx
    pop ax
    ret

; ============================================
; ANIMATION FRAME
; ============================================
; Replace the animate_frame function with this corrected version:

animate_frame:
    push ax
    push bx
    push cx
    push dx
    
    ; Check pickups FIRST (before collision, so we can collect items)
    call check_coin_collision
    call check_fuel_collision
    
    ; Coin spawning
    inc byte [coin_counter]
    mov al, [COIN_INTERVAL]
    cmp [coin_counter], al
    jb .skip_coin_spawn
    cmp byte [coin1_active], 0
    jne .try_coin2
    call choose_lane_x
    mov [coin1_x], ax
    mov word [coin1_y], 0
    mov byte [coin1_active], 1
    mov byte [coin_counter], 0
    jmp .skip_coin_spawn
.try_coin2:
    cmp byte [coin2_active], 0
    jne .try_coin3
    call choose_lane_x
    mov [coin2_x], ax
    mov word [coin2_y], 0
    mov byte [coin2_active], 1
    mov byte [coin_counter], 0
    jmp .skip_coin_spawn
.try_coin3:
    cmp byte [coin3_active], 0
    jne .skip_coin_spawn
    call choose_lane_x
    mov [coin3_x], ax
    mov word [coin3_y], 0
    mov byte [coin3_active], 1
    mov byte [coin_counter], 0
.skip_coin_spawn:
    cmp byte [coin1_active], 0
    je .skip_coin1_move
    add word [coin1_y], 2
    cmp word [coin1_y], 190
    jle .skip_coin1_move
    mov byte [coin1_active], 0
.skip_coin1_move:
    cmp byte [coin2_active], 0
    je .skip_coin2_move
    add word [coin2_y], 2
    cmp word [coin2_y], 190
    jle .skip_coin2_move
    mov byte [coin2_active], 0
.skip_coin2_move:
    cmp byte [coin3_active], 0
    je .skip_coin3_move
    add word [coin3_y], 2
    cmp word [coin3_y], 190
    jle .skip_coin3_move
    mov byte [coin3_active], 0
.skip_coin3_move:
    ; Fuel spawning
    inc byte [fuel_counter]
    mov al, [FUEL_INTERVAL]
    cmp [fuel_counter], al
    jb .skip_fuel_spawn
    cmp byte [fuel1_active], 0
    jne .try_fuel2
    call choose_lane_x
    mov [fuel1_x], ax
    mov word [fuel1_y], 0
    mov byte [fuel1_active], 1
    mov byte [fuel_counter], 0
    jmp .skip_fuel_spawn
.try_fuel2:
    cmp byte [fuel2_active], 0
    jne .skip_fuel_spawn
    call choose_lane_x
    mov [fuel2_x], ax
    mov word [fuel2_y], 0
    mov byte [fuel2_active], 1
    mov byte [fuel_counter], 0
.skip_fuel_spawn:
    cmp byte [fuel1_active], 0
    je .skip_fuel1_move
    add word [fuel1_y], 2
    cmp word [fuel1_y], 190
    jle .skip_fuel1_move
    mov byte [fuel1_active], 0
.skip_fuel1_move:
    cmp byte [fuel2_active], 0
    je .skip_fuel2_move
    add word [fuel2_y], 2
    cmp word [fuel2_y], 190
    jle .skip_fuel2_move
    mov byte [fuel2_active], 0
.skip_fuel2_move:
    ; Obstacle spawning
    inc byte [obstacle_counter]
    cmp byte [obstacle_active], 0
    jne .move_obs
    mov al, [OBSTACLE_INTERVAL]
    cmp [obstacle_counter], al
    jb .draw_all
    call choose_lane_x
    mov [obstacle_x], ax
    mov word [obstacle_y], 0
    mov byte [obstacle_active], 1
    mov byte [obstacle_counter], 0
    jmp .draw_all
.move_obs:
    add word [obstacle_y], 2
    cmp word [obstacle_y], 190
    jle .check_collision_now  ; Check collision after moving obstacle
    mov byte [obstacle_active], 0
    jmp .draw_all
    
.check_collision_now:
    ; Check collision with obstacle AFTER it has moved
    call check_collision_with_obstacle
    cmp al, 1
    je .collision_end
    
.draw_all:
    mov ax, [player_x]
    mov bx, [player_y]
    mov cl, 0x09
    call near draw_player_car
    cmp byte [obstacle_active], 0
    je .skip_obstacle
    mov ax, [obstacle_x]
    mov bx, [obstacle_y]
    mov cl, 0x09
    call draw_opponent_car
.skip_obstacle:
    cmp byte [coin1_active], 0
    je .skip_draw_coin1
    mov ax, [coin1_x]
    mov bx, [coin1_y]
    call draw_road_coin
.skip_draw_coin1:
    cmp byte [coin2_active], 0
    je .skip_draw_coin2
    mov ax, [coin2_x]
    mov bx, [coin2_y]
    call draw_road_coin
.skip_draw_coin2:
    cmp byte [coin3_active], 0
    je .skip_draw_coin3
    mov ax, [coin3_x]
    mov bx, [coin3_y]
    call draw_road_coin
.skip_draw_coin3:
    cmp byte [fuel1_active], 0
    je .skip_draw_fuel1
    mov ax, [fuel1_x]
    mov bx, [fuel1_y]
    call draw_road_fuel
.skip_draw_fuel1:
    cmp byte [fuel2_active], 0
    je .skip_draw_fuel2
    mov ax, [fuel2_x]
    mov bx, [fuel2_y]
    call draw_road_fuel
.skip_draw_fuel2:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.collision_end:
    ; Draw collision spark
    mov ax, [player_x]
    mov bx, [player_y]
    call draw_collision_spark
    mov byte [game_over_collision], 1
    pop dx
    pop cx
    pop bx
    pop ax
    ret

choose_lane_x:
    push dx
    push bx
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    mov ax, 130    ; Left lane (was 120)
cmp dx, 0
je .lane_ready
mov ax, 160    ; Middle lane (unchanged)
cmp dx, 1
je .lane_ready
mov ax, 190    ; Right lane (was 200)
.lane_ready:
    pop bx
    pop dx
    ret


copy_buffer_to_screen:
    push ax
    push cx
    push ds
    push es
    push si
    push di
    mov ax, [buffer_segment]
    mov ds, ax
    xor si, si
    mov ax, 0xA000
    mov es, ax
    xor di, di
    mov cx, 32000
    rep movsw
    pop di
    pop si
    pop es
    pop ds
    pop cx
    pop ax
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
    mov ax, [buffer_segment]
    mov es, ax
    mov dx, 0  
.border_loop:
    cmp dx, 200
    jge .done
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    mov di, ax
    pop dx
    
    mov cx, 100
    mov al, 0x02
    rep stosb
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 220
    mov di, ax
    pop dx
    
    mov cx, 100
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

draw_player_car:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    
    mov dx, bx              ; DX = Y coordinate
    mov si, ax              ; SI = X coordinate
    mov ax, [buffer_segment]
    mov es, ax
    mov bp, 24              ; 24 rows
    xor bx, bx              ; BX = current row counter
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

draw_opponent_car:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    
    mov dx, bx              ; DX = Y coordinate
    mov si, ax              ; SI = X coordinate
    mov ax, [buffer_segment]
    mov es, ax
    mov bp, 24              ; 24 rows
    xor bx, bx              ; BX = current row counter
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

draw_road:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov ax, [buffer_segment]
    mov es, ax
    mov dx, 0
.road_loop:
    cmp dx, 200
    jge near .done
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 100        
    mov di, ax
    pop dx
    
    mov cx, 120          
    mov al, 0x08    
    test dx, 0x04
    jz .draw_gray
    mov al, 0x08
.draw_gray:
    rep stosb
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 100
    mov di, ax
    pop dx
    mov byte [es:di], 0x0F
    mov byte [es:di+1], 0x0F
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 218
    mov di, ax
    pop dx
    mov byte [es:di], 0x0F
    mov byte [es:di+1], 0x0F
    
    test dx, 0x08
    jnz .no_left_line
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 140
    mov di, ax
    pop dx
    mov byte [es:di], 0x0F
    mov byte [es:di+1], 0x0F
.no_left_line:
    
    test dx, 0x08
    jnz .no_right_line
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 180
    mov di, ax
    pop dx
    mov byte [es:di], 0x0F
    mov byte [es:di+1], 0x0F
.no_right_line:
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 96
    mov di, ax
    pop dx
    mov al, 0x0C        
    test dx, 0x10
    jz .left_barr
    mov al, 0x0F        
.left_barr:
    mov cx, 3
    rep stosb
    
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 221
    mov di, ax
    pop dx
    mov al, 0x0C
    test dx, 0x10
    jz .right_barr
    mov al, 0x0F
.right_barr:
    mov cx, 3
    rep stosb
    
    inc dx
    jmp .road_loop
.done:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_oponent_car:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    push si
    
    mov si, bx          
    mov bx, ax          
    mov ax, si
    mov dx, 320
    mul dx
    add ax, bx
    sub ax, 5            
    mov di, ax
    mov ax, [buffer_segment]
    mov es, ax
    mov si, 0
.down_loop:
    cmp si, 14
    jge near .down_done
    
    push di
    mov dx, 13
    sub dx, si
    cmp dx, 2
    jge .check_window_d
    
    add di, 2
    mov al, cl
    mov cx, 6
    rep stosb
    mov byte [es:di-6], 0x0F
    mov byte [es:di-1], 0x0F
    mov byte [es:di-4], 0x0F
    mov byte [es:di-3], 0x0F
    jmp .next_row_d
.check_window_d:
    cmp dx, 5
    jge .check_body_d
    mov al, 0x0B      
    mov cx, 10
    rep stosb
    jmp .next_row_d
.check_body_d:
    mov al, cl
    mov cx, 10
    rep stosb
    cmp dx, 10
    jne .no_roof_light_d
    mov byte [es:di-6], 0x0F
    mov byte [es:di-5], 0x0F
.no_roof_light_d:
    mov byte [es:di-10], 0x00
    mov byte [es:di-1],  0x00
    cmp dx, 6
    je .add_wheels_d
    cmp dx, 11
    je .add_wheels_d
    cmp dx, 12
    jl .next_row_d
    mov byte [es:di-9],  0x0C
    mov byte [es:di-2],  0x0C
    jmp .next_row_d
.add_wheels_d:
    mov byte [es:di-10], 0x00
    mov byte [es:di-9],  0x00
    mov byte [es:di-2],  0x00
    mov byte [es:di-1],  0x00
.next_row_d:
    pop di
    add di, 320
    inc si
    jmp .down_loop
.down_done:
    pop si
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_score:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    push si
    
    mov ax, [buffer_segment]
    mov es, ax
    
    ; Draw "SCORE" label using pixel art at position (50, 185)
    mov bx, 25
    mov dx, 185
    
    ; Draw S
    call draw_letter_S
    add bx, 8
    
    ; Draw C
    call draw_letter_C
    add bx, 8
    
    ; Draw O
    call draw_letter_O
    add bx, 8
    
    ; Draw R
    call draw_letter_R
    add bx, 8
    
    ; Draw E
    call draw_letter_E
    add bx, 8
    
    ; Draw colon
    call draw_colon
    add bx, 5
    
    ; Draw the score number
    mov ax, [score]
    call draw_score_digits
    
    pop si
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_pause_message:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov ax, [buffer_segment]
    mov es, ax
    mov dx, 85
.box_loop:
    cmp dx, 115
    jge .box_done
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 110
    mov di, ax
    pop dx
    mov cx, 100
    mov al, 0x00
    rep stosb
    inc dx
    jmp .box_loop
.box_done:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 12
    mov dl, 15
    int 0x10
    mov si, pause_msg
    call print_string_white
    ret

draw_road_coin:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov cx, ax
    mov ax, bx
    mov bx, 320
    mul bx
    add ax, cx
    sub ax, 6
    mov di, ax
    mov ax, [buffer_segment]
    mov es, ax
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    add di, 320
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x0E
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    mov byte [es:di+8], 0x0E
    mov byte [es:di+9], 0x0E
    add di, 320
    mov byte [es:di+1], 0x0E
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x0E
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    mov byte [es:di+8], 0x0E
    mov byte [es:di+9], 0x0E
    mov byte [es:di+10], 0x0E
    add di, 320
    mov byte [es:di], 0x0E
    mov byte [es:di+1], 0x0E
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x06
    mov byte [es:di+4], 0x06
    mov byte [es:di+5], 0x06
    mov byte [es:di+6], 0x06
    mov byte [es:di+7], 0x06
    mov byte [es:di+8], 0x06
    mov byte [es:di+9], 0x0E
    mov byte [es:di+10], 0x0E
    mov byte [es:di+11], 0x0E
    add di, 320
    mov cx, 4
.coin_mid:
    mov byte [es:di], 0x0E
    mov byte [es:di+1], 0x0E
    mov byte [es:di+2], 0x06
    mov byte [es:di+3], 0x06
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    mov byte [es:di+8], 0x06
    mov byte [es:di+9], 0x06
    mov byte [es:di+10], 0x0E
    mov byte [es:di+11], 0x0E
    add di, 320
    loop .coin_mid
    mov byte [es:di], 0x0E
    mov byte [es:di+1], 0x0E
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x06
    mov byte [es:di+4], 0x06
    mov byte [es:di+5], 0x06
    mov byte [es:di+6], 0x06
    mov byte [es:di+7], 0x06
    mov byte [es:di+8], 0x06
    mov byte [es:di+9], 0x0E
    mov byte [es:di+10], 0x0E
    mov byte [es:di+11], 0x0E
    add di, 320
    mov byte [es:di+1], 0x0E
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x0E
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    mov byte [es:di+8], 0x0E
    mov byte [es:di+9], 0x0E
    mov byte [es:di+10], 0x0E
    add di, 320
    mov byte [es:di+2], 0x0E
    mov byte [es:di+3], 0x0E
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    mov byte [es:di+8], 0x0E
    mov byte [es:di+9], 0x0E
    add di, 320
    mov byte [es:di+4], 0x0E
    mov byte [es:di+5], 0x0E
    mov byte [es:di+6], 0x0E
    mov byte [es:di+7], 0x0E
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_road_fuel:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    mov cx, ax
    mov ax, bx
    mov bx, 320
    mul bx
    add ax, cx
    sub ax, 5
    mov di, ax
    mov ax, [buffer_segment]
    mov es, ax
    mov byte [es:di+2], 0x04
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    mov byte [es:di+7], 0x04
    add di, 320
    mov byte [es:di+1], 0x04
    mov byte [es:di+2], 0x04
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    mov byte [es:di+7], 0x04
    mov byte [es:di+8], 0x04
    add di, 320
    mov byte [es:di], 0x04
    mov byte [es:di+1], 0x04
    mov byte [es:di+2], 0x04
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    mov byte [es:di+7], 0x04
    mov byte [es:di+8], 0x04
    mov byte [es:di+9], 0x04
    add di, 320
    mov cx, 2
.fuel_upper:
    mov byte [es:di], 0x04
    mov byte [es:di+1], 0x0C
    mov byte [es:di+2], 0x0C
    mov byte [es:di+3], 0x0C
    mov byte [es:di+4], 0x0C
    mov byte [es:di+5], 0x0C
    mov byte [es:di+6], 0x0C
    mov byte [es:di+7], 0x0C
    mov byte [es:di+8], 0x0C
    mov byte [es:di+9], 0x04
    add di, 320
    loop .fuel_upper
    mov cx, 4
.fuel_mid:
    mov byte [es:di], 0x04
    mov byte [es:di+1], 0x0C
    mov byte [es:di+2], 0x0F
    mov byte [es:di+3], 0x0F
    mov byte [es:di+4], 0x0F
    mov byte [es:di+5], 0x0F
    mov byte [es:di+6], 0x0F
    mov byte [es:di+7], 0x0F
    mov byte [es:di+8], 0x0C
    mov byte [es:di+9], 0x04
    add di, 320
    loop .fuel_mid
    mov cx, 2
.fuel_lower:
    mov byte [es:di], 0x04
    mov byte [es:di+1], 0x0C
    mov byte [es:di+2], 0x0C
    mov byte [es:di+3], 0x0C
    mov byte [es:di+4], 0x0C
    mov byte [es:di+5], 0x0C
    mov byte [es:di+6], 0x0C
    mov byte [es:di+7], 0x0C
    mov byte [es:di+8], 0x0C
    mov byte [es:di+9], 0x04
    add di, 320
    loop .fuel_lower
    mov byte [es:di], 0x04
    mov byte [es:di+1], 0x04
    mov byte [es:di+2], 0x04
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    mov byte [es:di+7], 0x04
    mov byte [es:di+8], 0x04
    mov byte [es:di+9], 0x04
    add di, 320
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    add di, 320
    mov byte [es:di+3], 0x04
    mov byte [es:di+4], 0x04
    mov byte [es:di+5], 0x04
    mov byte [es:di+6], 0x04
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_letter_S:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    ; Top line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Left side
    mov byte [es:di], al
    add di, 320
    
    ; Middle line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Right side
    add di, 4
    mov byte [es:di], al
    add di, 320-4
    
    ; Bottom line
    mov cx, 5
    rep stosb
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_letter_C:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    ; Top line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Left sides
    mov byte [es:di], al
    add di, 320
    mov byte [es:di], al
    add di, 320
    mov byte [es:di], al
    add di, 320
    
    ; Bottom line
    mov cx, 5
    rep stosb
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_letter_O:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    ; Top line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Sides
    mov byte [es:di], al
    mov byte [es:di+4], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+4], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+4], al
    add di, 320
    
    ; Bottom line
    mov cx, 5
    rep stosb
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_letter_R:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    ; Top line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Sides top
    mov byte [es:di], al
    mov byte [es:di+4], al
    add di, 320
    
    ; Middle line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Left and diagonal
    mov byte [es:di], al
    mov byte [es:di+2], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+4], al
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_letter_E:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    ; Top line
    mov cx, 5
    rep stosb
    add di, 320-5
    
    ; Left side
    mov byte [es:di], al
    add di, 320
    
    ; Middle line
    mov cx, 4
    rep stosb
    add di, 320-4
    
    ; Left side
    mov byte [es:di], al
    add di, 320
    
    ; Bottom line
    mov cx, 5
    rep stosb
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_colon:
    push ax
    push bx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E
    add di, 320 ; Skip first row
    mov byte [es:di], al
    mov byte [es:di+1], al
    add di, 320
    add di, 320 ; Skip middle
    mov byte [es:di], al
    mov byte [es:di+1], al
    
    pop di
    pop dx
    pop bx
    pop ax
    ret
draw_score_digit:
    ; Input: SI = digit (0-9), BX = x, DX = y
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, dx
    push bx
    mov bx, 320
    mul bx
    pop bx
    add ax, bx
    mov di, ax
    
    mov al, 0x0E  ; Yellow color
    
    cmp si, 0
    je near .digit_0
    cmp si, 1
    je near .digit_1
    cmp si, 2
    je near .digit_2
    cmp si, 3
    je near .digit_3
    cmp si, 4
    je near .digit_4
    cmp si, 5
    je near .digit_5
    cmp si, 6
    je near .digit_6
    cmp si, 7
    je near .digit_7
    cmp si, 8
    je near .digit_8
    cmp si, 9
    je near .digit_9
    jmp .done
    
.digit_0:
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_1:
    add di, 1
    mov byte [es:di], al
    mov byte [es:di+1], al
    add di, 320
    add di, 1
    mov byte [es:di], al
    add di, 320-1
    add di, 1
    mov byte [es:di], al
    add di, 320-1
    add di, 1
    mov byte [es:di], al
    add di, 320-1
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_2:
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    add di, 320
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_3:
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_4:
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    add di, 3
    mov byte [es:di], al
    jmp .done
    
.digit_5:
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    add di, 320
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_6:
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    add di, 320
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_7:
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    add di, 3
    mov byte [es:di], al
    add di, 320
    mov byte [es:di], al
    add di, 320
    mov byte [es:di], al
    jmp .done
    
.digit_8:
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    jmp .done
    
.digit_9:
    mov cx, 4
    rep stosb
    add di, 320-4
    mov byte [es:di], al
    mov byte [es:di+3], al
    add di, 320
    mov cx, 4
    rep stosb
    add di, 320-1
    mov byte [es:di], al
    add di, 320-3
    mov cx, 4
    rep stosb
    jmp .done
    
.done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_score_digits:
    ; Input: AX = score number, BX = x position, DX = y position
    ; The digits will be drawn starting from position (BX, DX)
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Store positions
    mov [temp_x], bx
    mov [temp_y], dx
    
    ; Handle zero
    cmp ax, 0
    jne .not_zero
    mov si, 0
    mov bx, [temp_x]
    mov dx, [temp_y]
    call draw_score_digit
    jmp .done
    
.not_zero:
    ; Extract digits (will be in reverse order in buffer)
    mov di, score_buffer
    mov cx, 0
    
.extract:
    xor dx, dx
    mov bx, 10
    div bx              ; AX = quotient, DX = remainder
    add dl, '0'
    mov [di], dl
    inc di
    inc cx
    cmp ax, 0
    jne .extract
    
    ; Now draw digits in correct order (reverse of buffer)
    mov bx, [temp_x]
    mov dx, [temp_y]
    
.draw_digits:
    dec di
    dec cx
    
    movzx si, byte [di]
    sub si, '0'
    
    push cx
    push bx
    push dx
    push di
    call draw_score_digit
    pop di
    pop dx
    pop bx
    add bx, 6           ; Move 6 pixels right for next digit
    pop cx
    
    cmp cx, 0
    jne .draw_digits
    
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Data section
player_x: dw 153
player_y: dw 165
quit_flag            db 0

oldisr               dd 0
oldtimer             dd 0
obstacle_x           dw 0
obstacle_y           dw 0
obstacle_active      db 0
obstacle_counter     db 0
coin1_x              dw 0
coin1_y              dw 0
coin1_active         db 0
coin2_x              dw 0
coin2_y              dw 0
coin2_active         db 0
coin3_x              dw 0
coin3_y              dw 0
coin3_active         db 0
coin_counter         db 0
fuel1_x              dw 0
fuel1_y              dw 0
fuel1_active         db 0
fuel2_x              dw 0
fuel2_y              dw 0
fuel2_active         db 0
fuel_counter         db 0
flag                 db 0
left_pressed         db 0
right_pressed        db 0
down_pressed         db 0
up_pressed           db 0
current_lane         db 1
road_scroll          dw 0
paused               db 0
score                dw 0
current_fuel         dw 200
fuel_tick_counter    db 0
move_cooldown        db 0
game_over_collision  db 0
game_over_fuel       db 0
; Configuration
OBSTACLE_INTERVAL    db 30
COIN_INTERVAL        db 45
FUEL_INTERVAL        db 80
MAX_FUEL             dw 200
FUEL_DECREASE_RATE   db 18        ; Ticks before fuel decreases
FUEL_REFILL_AMOUNT   dw 50        ; Fuel restored per pickup
MOVE_COOLDOWN_TIME   db 10        ; Frames before next move allowed
buffer_segment       dw 0x7000
; Strings
game_title           db '=== HIGHWAY RACER ===', 0
dev_names            db 'Devs: Ikram Ul Haq & Rohaan Ahmed', 0
roll_nos             db 'Rolls: 24L-0767 & 24L-0548', 0
press_start          db 'Press ANY Key to Start', 0
input_prompt_name    db 'Enter Name: ', 0
input_prompt_roll    db 'Enter Roll: ', 0
instr_title          db '--- INSTRUCTIONS ---', 0
instr_1              db 'Left/Right: Change Lanes', 0
instr_2              db 'Up/Down: Move Car', 0
instr_3              db 'Collect Coins for Points', 0
instr_4              db 'Collect Fuel to Keep Moving', 0
instr_5              db 'ESC: Pause/Quit', 0
instr_press          db 'Press ANY Key to Play', 0
game_over_msg        db '=== GAME OVER ===', 0
collision_msg        db 'Collision!', 0
fuel_empty_msg       db 'Out of Fuel!', 0
player_label         db 'Player: ', 0
roll_label           db 'Roll No: ', 0
final_score_label    db 'Final Score: ', 0
play_again_msg       db 'Enter: Restart | ESC: Exit', 0
confirm_msg          db 'Quit Game? (Y/N)', 0
pause_msg            db 'PAUSED - Quit? (Y/N)', 0
player_name_buf      times 20 db 0
player_roll_buf      times 20 db 0
score_buffer times 6 db 0
temp_x  dw 0
temp_y  dw 0
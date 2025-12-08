org 0x100
start:

    call clear_screen
    mov ah, 0x00
    mov al, 0x13
    int 0x10
call draw_pic 
    ; Wait for keypress
    xor ah, ah
    int 0x16

restart_game:
    ; Reset all game variables
    mov byte [quit_flag], 0
    mov word [player_x], 160
    mov word [player_y], 175
    mov word [obstacle_x], 0
    mov word [obstacle_y], 0
    mov byte [obstacle_active], 0
    mov byte [obstacle_counter], 50
    mov word [obstacle2_x], 0
    mov word [obstacle2_y], 0
    mov byte [obstacle2_active], 0
    mov byte [obstacle2_counter], 0
    mov byte [coin1_active], 0
    mov byte [coin2_active], 0
    mov byte [coin3_active], 0
    mov byte [coin_counter], 0
    mov byte [fuel1_active], 0
    mov byte [fuel2_active], 0
    mov byte [fuel_counter], 0
    mov byte [flag], 0
    mov byte [left_pressed], 0
    mov byte [right_pressed], 0
    mov byte [down_pressed], 0
    mov byte [up_pressed], 0
    mov byte [current_lane], 1
    mov word [road_scroll], 0
    mov byte [paused], 0
    mov word [score], 0
    mov word [current_fuel], 200
    mov byte [fuel_tick_counter], 0
    mov byte [move_cooldown], 0
    mov byte [game_over_collision], 0
    mov byte [game_over_fuel], 0
    mov word [oldisr], 0
    mov word [oldisr+2], 0
    mov word [oldtimer], 0
    mov word [oldtimer+2], 0

    mov ax, cs
    mov ss, ax
    mov sp, 0xFFFE
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ax, 0x0013
    int 0x10
    

    call clear_screen
    call copy_buffer_to_screen
    call show_start_screen
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
    call draw_music_indicator
    call copy_buffer_to_screen

    ; Hook keyboard interrupt
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

    ; Hook timer interrupt for fuel and music
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
    call handle_player_input
    call animate_frame
    call draw_fuel_bar
    call draw_score
    call draw_music_indicator
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
; TIMER ISR - For Fuel Consumption & Music
; ============================================
timer_isr:
    push ax
    push bx
    push cx
    push dx
    push ds
    push cs
    pop ds
    
    ; Fuel consumption logic
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
    ; ===== MUSIC PLAYBACK =====
    cmp byte [music_enabled], 1
    jne .skip_music
    
    ; Update music tick counter
    inc word [music_tick_counter]
    mov ax, [music_tick_counter]
    cmp ax, [note_duration]
    jb .skip_music
    
    ; Reset counter
    mov word [music_tick_counter], 0
    
    ; Play next note
    call play_next_note
    
.skip_music:
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [cs:oldtimer]

; ============================================
; MUSIC FUNCTIONS
; ============================================
play_next_note:
    push ax
    push bx
    push si
    
    ; Get current note index
    mov si, [current_note_index]
    shl si, 1           ; Multiply by 2 (word size)
    mov bx, melody
    add bx, si
    mov ax, [bx]        ; Get frequency from melody table
    
    ; Check if end of melody (0 = end marker)
    cmp ax, 0
    jne .play_note
    
    ; Loop back to beginning
    mov word [current_note_index], 0
    mov ax, [melody]
    
.play_note:
    ; If frequency is 1, it's a rest
    cmp ax, 1
    je .play_rest
    
    ; Play the note
    call sound_on
    jmp .next_note
    
.play_rest:
    call sound_off
    
.next_note:
    ; Move to next note
    inc word [current_note_index]
    
    pop si
    pop bx
    pop ax
    ret

sound_on:
    push ax
    push bx
    push dx
    
    ; Calculate timer divisor: Divisor = 1193180 / frequency
    mov bx, ax          ; BX = frequency
    mov dx, 0x0012      ; DX:AX = 1193180
    mov ax, 0x34DC
    div bx              ; AX = divisor
    
    mov bx, ax          ; Save divisor in BX
    
    ; Program PIT channel 2 for square wave
    mov al, 0xB6        ; Channel 2, square wave
    out 0x43, al
    
    mov al, bl          ; Low byte of divisor
    out 0x42, al
    mov al, bh          ; High byte of divisor
    out 0x42, al
    
    ; Turn on speaker (set bits 0 and 1 of port 0x61)
    in al, 0x61
    or al, 0x03
    out 0x61, al
    
    pop dx
    pop bx
    pop ax
    ret

sound_off:
    push ax
    
    ; Turn off speaker (clear bits 0 and 1)
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    
    pop ax
    ret

toggle_music:
    push ax
    
    cmp byte [music_enabled], 0
    je .enable_music
    
    ; Disable music
    mov byte [music_enabled], 0
    call sound_off
    mov word [current_note_index], 0
    mov word [music_tick_counter], 0
    jmp .done
    
.enable_music:
    ; Enable music
    mov byte [music_enabled], 1
    mov word [current_note_index], 0
    mov word [music_tick_counter], 0
    
.done:
    pop ax
    ret

draw_music_indicator:
    push ax
    push bx
    push cx
    push dx
    push es
    push di
    
    mov ax, [buffer_segment]
    mov es, ax
    
    ; Draw music indicator at (280, 185)
    mov ax, 185
    mov bx, 320
    mul bx
    add ax, 280
    mov di, ax
    
    ; Draw "M" for music
    mov al, 0x0E        ; Yellow color
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di+2], al
    mov byte [es:di+6], al
    mov byte [es:di+7], al
    mov byte [es:di+8], al
    
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di+2], al
    mov byte [es:di+3], al
    mov byte [es:di+4], al
    mov byte [es:di+5], al
    mov byte [es:di+6], al
    mov byte [es:di+7], al
    mov byte [es:di+8], al
    
    ; Add ON/OFF indicator
    cmp byte [music_enabled], 1
    jne .music_off
    
    ; Draw green dot for ON
    add di, 320
    mov al, 0x02        ; Green
    mov byte [es:di+4], al
    jmp .done_indicator
    
.music_off:
    ; Draw red dot for OFF
    add di, 320
    mov al, 0x04        ; Red
    mov byte [es:di+4], al
    
.done_indicator:
    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

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
    
    ; Check if it's a key press (bit 7 clear) or release (bit 7 set)
    test al, 0x80
    jnz near .key_release
    
    ; Key press handling
    cmp byte [cs:flag], 0
    jne .check_esc
    mov byte [cs:flag], 1
    jmp .end_isr
    
.check_esc:
    cmp al, 0x01        ; ESC key
    jne .check_space
    cmp byte [cs:paused], 1
    je .unpause
    mov byte [cs:paused], 1
    jmp .end_isr
.unpause:
    mov byte [cs:paused], 0
    jmp .end_isr
    
.check_space:
    cmp al, 0x39        ; Space bar - Music toggle
    jne .check_left
    call toggle_music
    jmp .end_isr
    
.check_left:
    cmp al, 0x4B        ; Left arrow
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
    cmp al, 0x4D        ; Right arrow
    jne .check_up
    cmp byte [cs:paused], 0
    jne near .end_isr
    cmp byte [cs:move_cooldown], 0
    jne near .end_isr
    mov byte [cs:right_pressed], 1
    mov al, [cs:MOVE_COOLDOWN_TIME]
    mov [cs:move_cooldown], al
    jmp .end_isr
    
.check_up:
    cmp al, 0x48        ; Up arrow
    jne .check_down
    cmp byte [cs:paused], 0
    jne .end_isr
    mov byte [cs:up_pressed], 1
    jmp .end_isr
    
.check_down:
    cmp al, 0x50        ; Down arrow
    jne .check_y
    cmp byte [cs:paused], 0
    jne .end_isr
    mov byte [cs:down_pressed], 1
    jmp .end_isr
    
.check_y:
    cmp byte [cs:paused], 1
    jne .check_n
    cmp al, 0x15        ; Y key
    jne .check_n
    mov byte [cs:flag], 2
    jmp .end_isr
    
.check_n:
    cmp byte [cs:paused], 1
    jne .key_release
    cmp al, 0x31        ; N key
    jne .key_release
    mov byte [cs:paused], 0
    
.key_release:
    ; Clear key flags on release
    cmp al, 0xCB        ; Left arrow release
    je .clear_left
    cmp al, 0xCD        ; Right arrow release
    je .clear_right
    cmp al, 0xC8        ; Up arrow release
    je .clear_up
    cmp al, 0xD0        ; Down arrow release
    je .clear_down
    jmp .end_isr
    
.clear_left:
    mov byte [cs:left_pressed], 0
    jmp .end_isr
.clear_right:
    mov byte [cs:right_pressed], 0
    jmp .end_isr
.clear_up:
    mov byte [cs:up_pressed], 0
    jmp .end_isr
.clear_down:
    mov byte [cs:down_pressed], 0
    
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
    ; Turn off speaker
    call sound_off
    
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
    mov dh, 12
    mov dl, 2
    int 0x10
    mov si, music_instruction
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
    call print_string_yellow
    mov di, player_name_buf
    call get_input_string
    cmp byte [quit_flag], 1
    je .ret
    mov ah, 0x02
    mov dh, 10
    mov dl, 5
    int 0x10
    mov si, input_prompt_roll
    call print_string_yellow
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
    mov dh, 18
    mov dl, 5
    int 0x10
    mov si, instr_music
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
    ; Turn off music
    call sound_off
    
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
    
    ; Show music status
    mov ah, 0x02
    mov dh, 17
    mov dl, 30
    int 0x10
    mov si, music_status
    call print_string_white
    mov ah, 0x02
    mov dh, 17
    mov dl, 45
    int 0x10
    cmp byte [music_enabled], 1
    je .music_on
    mov si, off_msg
    call print_string_red
    jmp .show_choice
.music_on:
    mov si, on_msg
    call print_string_green
    
.show_choice:
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
    je restart_game
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
print_string_green:
    mov bl, 0x0A
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
    mov byte [obstacle_counter], 50
    mov byte [obstacle2_active], 0
    mov byte [obstacle2_counter], 0
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
    
    ; Initialize music
    mov byte [music_enabled], 1
    mov word [current_note_index], 0
    mov word [music_tick_counter], 0
    
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
    je .collision_detected
    
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

check_collision_with_obstacle2:
    ; Check if player collides with obstacle2
    push bx
    push cx
    push dx
    
    cmp byte [obstacle2_active], 0
    je .no_collision2
    
    ; Check if they're in the same lane first
    mov ax, [player_x]
    mov bx, [obstacle2_x]
    sub ax, bx
    
    ; Check X overlap (within 15 pixels = same lane approximately)
    cmp ax, -15
    jl .no_collision2
    cmp ax, 15
    jg .no_collision2
    
    ; They're in same lane, now check Y overlap
    ; Player car is 14 pixels tall, obstacle is 14 pixels tall
    mov ax, [player_y]
    mov bx, [obstacle2_y]
    sub ax, bx
    
    ; If distance between centers is less than 14, they're colliding
    cmp ax, -14
    jl .no_collision2
    cmp ax, 14
    jg .no_collision2
    
    ; Collision detected!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.no_collision2:
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
    
    ; Center spark
    mov byte [es:di], al
    mov byte [es:di+1], al
    mov byte [es:di-1], al
    mov byte [es:di+320], al
    mov byte [es:di-320], al
    
    ; Left spark (offset -12)
    mov si, di
    sub si, 12
    mov byte [es:si], al
    mov byte [es:si+320], al
    mov byte [es:si-320], al
    mov byte [es:si+1], al
    mov byte [es:si-1], al
    
    ; Right spark (offset +12)
    mov si, di
    add si, 12
    mov byte [es:si], al
    mov byte [es:si+320], al
    mov byte [es:si-320], al
    mov byte [es:si+1], al
    mov byte [es:si-1], al
    
    ; Top spark (offset -12 lines = -3840)
    mov si, di
    sub si, 3840
    mov byte [es:si], al
    mov byte [es:si+320], al
    mov byte [es:si-320], al
    mov byte [es:si+1], al
    mov byte [es:si-1], al
    
    ; Bottom spark (offset +12 lines = +3840)
    mov si, di
    add si, 3840
    mov byte [es:si], al
    mov byte [es:si+320], al
    mov byte [es:si-320], al
    mov byte [es:si+1], al
    mov byte [es:si-1], al
    
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
; ANIMATION FRAME - With Smart Spawning
; ============================================
animate_frame:
    push ax
    push bx
    push cx
    push dx
    
    ; Check pickups FIRST (before collision, so we can collect items)
    call check_coin_collision
    call check_fuel_collision
    
    ; ===== COIN SPAWNING (with collision avoidance) =====
    inc byte [coin_counter]
    mov al, [COIN_INTERVAL]
    cmp [coin_counter], al
    jb .skip_coin_spawn
    
    ; Try to spawn coin in a free lane
    call choose_free_lane
    cmp ax, 0
    je .skip_coin_spawn  ; No free lane available
    
    ; Find inactive coin slot
    cmp byte [coin1_active], 0
    jne .try_coin2
    mov [coin1_x], ax
    mov word [coin1_y], 0
    mov byte [coin1_active], 1
    mov byte [coin_counter], 0
    jmp .skip_coin_spawn
.try_coin2:
    cmp byte [coin2_active], 0
    jne .try_coin3
    mov [coin2_x], ax
    mov word [coin2_y], 0
    mov byte [coin2_active], 1
    mov byte [coin_counter], 0
    jmp .skip_coin_spawn
.try_coin3:
    cmp byte [coin3_active], 0
    jne .skip_coin_spawn
    mov [coin3_x], ax
    mov word [coin3_y], 0
    mov byte [coin3_active], 1
    mov byte [coin_counter], 0
    
.skip_coin_spawn:
    ; Move coins
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
    
    ; ===== FUEL SPAWNING (with collision avoidance) =====
    inc byte [fuel_counter]
    mov al, [FUEL_INTERVAL]
    cmp [fuel_counter], al
    jb .skip_fuel_spawn
    
    ; Try to spawn fuel in a free lane
    call choose_free_lane
    cmp ax, 0
    je .skip_fuel_spawn  ; No free lane available
    
    ; Find inactive fuel slot
    cmp byte [fuel1_active], 0
    jne .try_fuel2
    mov [fuel1_x], ax
    mov word [fuel1_y], 0
    mov byte [fuel1_active], 1
    mov byte [fuel_counter], 0
    jmp .skip_fuel_spawn
.try_fuel2:
    cmp byte [fuel2_active], 0
    jne .skip_fuel_spawn
    mov [fuel2_x], ax
    mov word [fuel2_y], 0
    mov byte [fuel2_active], 1
    mov byte [fuel_counter], 0
    
.skip_fuel_spawn:
    ; Move fuel
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
    
    ; ===== OBSTACLE SPAWNING (with collision avoidance) =====
    inc byte [obstacle_counter]
    cmp byte [obstacle_active], 0
    jne .move_obs
    mov al, [OBSTACLE_INTERVAL]
    cmp [obstacle_counter], al
    jb .check_obs2
    
    ; Try to spawn obstacle in a free lane
    call choose_free_lane
    cmp ax, 0
    je .check_obs2  ; No free lane available, try obstacle2
    
    mov [obstacle_x], ax
    mov word [obstacle_y], 0
    mov byte [obstacle_active], 1
    mov byte [obstacle_counter], 0
    jmp .check_obs2
    
.move_obs:
    add word [obstacle_y], 2
    cmp word [obstacle_y], 190
    jle .check_collision_obs1
    add word [score], 10    ; Score +10 for passing obstacle
    mov byte [obstacle_active], 0
    jmp .check_obs2
    
.check_collision_obs1:
    ; Check collision with obstacle AFTER it has moved
    call check_collision_with_obstacle
    cmp al, 1
    je near .collision_end
    
.check_obs2:
    ; ===== OBSTACLE 2 SPAWNING =====
    inc byte [obstacle2_counter]
    cmp byte [obstacle2_active], 0
    jne .move_obs2
    mov al, [OBSTACLE_INTERVAL]
    cmp [obstacle2_counter], al
    jb .draw_all
    
    ; Try to spawn obstacle2 in a free lane
    call choose_free_lane
    cmp ax, 0
    je .draw_all  ; No free lane available
    
    mov [obstacle2_x], ax
    mov word [obstacle2_y], 0
    mov byte [obstacle2_active], 1
    mov byte [obstacle2_counter], 0
    jmp .draw_all
    
.move_obs2:
    add word [obstacle2_y], 2
    cmp word [obstacle2_y], 190
    jle .check_collision_obs2
    add word [score], 10    ; Score +10 for passing obstacle2
    mov byte [obstacle2_active], 0
    jmp .draw_all
    
.check_collision_obs2:
    ; Check collision with obstacle2
    call check_collision_with_obstacle2
    cmp al, 1
    je near .collision_end
    
.draw_all:
    ; Draw player car
    mov ax, [player_x]
    mov bx, [player_y]
    mov cl, 0x0C
    call draw_player_car
    
    ; Draw obstacle
    cmp byte [obstacle_active], 0
    je .skip_obstacle
    mov ax, [obstacle_x]
    mov bx, [obstacle_y]
    mov cl, 0x01
    call draw_opponent_car
.skip_obstacle:
    
    ; Draw obstacle2
    cmp byte [obstacle2_active], 0
    je .skip_obstacle2
    mov ax, [obstacle2_x]
    mov bx, [obstacle2_y]
    mov cl, 0x09        ; Blue color for second car
    call draw_opponent_car
.skip_obstacle2:
    
    ; Draw coins
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
    
    ; Draw fuel
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
    
    ; Show spark immediately
    call copy_buffer_to_screen
    
    ; Wait for 1 second (approx 18 ticks)
    mov cx, 18
.delay_spark:
    hlt
    loop .delay_spark
    
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
    mov ax, 120
    cmp dx, 0
    je .lane_ready
    mov ax, 160
    cmp dx, 1
    je .lane_ready
    mov ax, 200
.lane_ready:
    pop bx
    pop dx
    ret
; ============================================
; SMART LANE SELECTION - Prevents Overlapping
; ============================================

; Check if a lane is occupied at spawn point (Y < 40)
check_lane_occupied:
    ; Input: AL = lane to check (0=120, 1=160, 2=200)
    ; Output: AL = 1 if occupied, 0 if free
    push bx
    push cx
    push dx
    
    ; Convert lane number to X position
    cmp al, 0
    je .lane_0
    cmp al, 1
    je .lane_1
    mov bx, 200  ; Lane 2
    jmp .check_items
.lane_0:
    mov bx, 120
    jmp .check_items
.lane_1:
    mov bx, 160
    
.check_items:
    ; Check obstacle
    cmp byte [obstacle_active], 1
    jne .check_obstacle2
    cmp word [obstacle_y], 40
    jg .check_obstacle2
    mov ax, [obstacle_x]
    sub ax, bx
    cmp ax, -10
    jl .check_obstacle2
    cmp ax, 10
    jg .check_obstacle2
    ; Obstacle in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_obstacle2:
    ; Check obstacle2
    cmp byte [obstacle2_active], 1
    jne .check_coins
    cmp word [obstacle2_y], 40
    jg .check_coins
    mov ax, [obstacle2_x]
    sub ax, bx
    cmp ax, -10
    jl .check_coins
    cmp ax, 10
    jg .check_coins
    ; Obstacle2 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_coins:
    ; Check coin 1
    cmp byte [coin1_active], 1
    jne .check_coin2
    cmp word [coin1_y], 40
    jg .check_coin2
    mov ax, [coin1_x]
    sub ax, bx
    cmp ax, -10
    jl .check_coin2
    cmp ax, 10
    jg .check_coin2
    ; Coin 1 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_coin2:
    ; Check coin 2
    cmp byte [coin2_active], 1
    jne .check_coin3
    cmp word [coin2_y], 40
    jg .check_coin3
    mov ax, [coin2_x]
    sub ax, bx
    cmp ax, -10
    jl .check_coin3
    cmp ax, 10
    jg .check_coin3
    ; Coin 2 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_coin3:
    ; Check coin 3
    cmp byte [coin3_active], 1
    jne .check_fuel1
    cmp word [coin3_y], 40
    jg .check_fuel1
    mov ax, [coin3_x]
    sub ax, bx
    cmp ax, -10
    jl .check_fuel1
    cmp ax, 10
    jg .check_fuel1
    ; Coin 3 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_fuel1:
    ; Check fuel 1
    cmp byte [fuel1_active], 1
    jne .check_fuel2
    cmp word [fuel1_y], 40
    jg .check_fuel2
    mov ax, [fuel1_x]
    sub ax, bx
    cmp ax, -10
    jl .check_fuel2
    cmp ax, 10
    jg .check_fuel2
    ; Fuel 1 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.check_fuel2:
    ; Check fuel 2
    cmp byte [fuel2_active], 1
    jne .lane_free
    cmp word [fuel2_y], 40
    jg .lane_free
    mov ax, [fuel2_x]
    sub ax, bx
    cmp ax, -10
    jl .lane_free
    cmp ax, 10
    jg .lane_free
    ; Fuel 2 in this lane!
    pop dx
    pop cx
    pop bx
    mov al, 1
    ret
    
.lane_free:
    pop dx
    pop cx
    pop bx
    mov al, 0
    ret

; ============================================
; CHOOSE FREE LANE - Returns available lane X position
; ============================================
choose_free_lane:
    ; Output: AX = lane X position (120, 160, 200) or 0 if all occupied
    push bx
    push cx
    push dx
    
    ; Get random starting lane
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    ; DX now contains 0, 1, or 2 (starting lane)
    
    mov cl, dl  ; Save starting lane
    mov ch, 0   ; Attempt counter
    
.try_lane:
    ; Try current lane (in CL)
    mov al, cl
    call check_lane_occupied
    cmp al, 0
    je .lane_found
    
    ; Lane occupied, try next
    inc cl
    cmp cl, 3
    jl .no_wrap
    mov cl, 0   ; Wrap to lane 0
.no_wrap:
    
    inc ch
    cmp ch, 3
    jl .try_lane
    
    ; All lanes occupied!
    pop dx
    pop cx
    pop bx
    xor ax, ax  ; Return 0 (no lane available)
    ret
    
.lane_found:
    ; Convert lane number to X position
    cmp cl, 0
    je .return_lane_0
    cmp cl, 1
    je .return_lane_1
    mov ax, 200  ; Lane 2
    jmp .done
.return_lane_0:
    mov ax, 120
    jmp .done
.return_lane_1:
    mov ax, 160
    
.done:
    pop dx
    pop cx
    pop bx
    ret

; ============================================
; BUFFER FUNCTIONS
; ============================================
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
    mov ax, [buffer_segment]
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

; ============================================
; DRAWING FUNCTIONS
; ============================================
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
    jge near .done
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    mov di, ax
    pop dx
    mov cx, 100
    mov al, 0x02 ; Green
    rep stosb
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 220
    mov di, ax
    pop dx
    mov cx, 100
    mov al, 0x02 ; Green
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
    call draw_scrolling_trees
    ret

draw_scrolling_trees:
    ; Draw trees on left and right borders
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov bx, [road_scroll] ; Get scroll offset
    and bx, 63            ; Modulo 64 (spacing)
    
    ; Loop to draw trees
    mov dx, bx            ; Start Y
    sub dx, 64            ; Start above screen
    
.tree_loop:
    cmp dx, 200
    jg .done_trees
    
    ; Draw Left Tree (X=20)
    push dx
    mov ax, 20      ; X
    mov bx, dx      ; Y
    call draw_tree_sprite
    pop dx
    
    ; Draw Right Tree (X=280)
    push dx
    mov ax, 280     ; X
    mov bx, dx      ; Y
    call draw_tree_sprite
    pop dx
    
    add dx, 64      ; Next tree
    jmp .tree_loop
    
.done_trees:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_tree_sprite:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push es
    
    mov si, ax          ; SI = X position
    mov dx, bx          ; DX = Y position
    
    mov ax, [buffer_segment]
    mov es, ax
    
    ; ========== ROW 0-1 (Top) ==========
    mov bx, si
    add bx, 12
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height (2 rows)
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 2-3 ==========
    mov bx, si
    add bx, 10
    push dx
    mov cx, 10          ; Width (2x5)
    mov di, 2           ; Height
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 4-5 ==========
    mov bx, si
    add bx, 8
    push dx
    mov cx, 14          ; Width (2x7)
    mov di, 2           ; Height
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 6-7 ==========
    mov bx, si
    add bx, 6
    push dx
    mov cx, 18          ; Width (2x9)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 8-9 (Trunk starts) ==========
    ; Left green part
    mov bx, si
    add bx, 6
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    ; Trunk
    mov bx, si
    add bx, 12
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x06        ; Brown
    call draw_rect
    pop dx
    
    ; Right green part
    mov bx, si
    add bx, 18
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 10-11 ==========
    ; Left green part
    mov bx, si
    add bx, 6
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    ; Trunk
    mov bx, si
    add bx, 12
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x06        ; Brown
    call draw_rect
    pop dx
    
    ; Right green part
    mov bx, si
    add bx, 18
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 12-13 ==========
    mov bx, si
    add bx, 10
    push dx
    mov cx, 10          ; Width (2x5)
    mov di, 2           ; Height
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 14-15 ==========
    mov bx, si
    add bx, 8
    push dx
    mov cx, 14          ; Width (2x7)
    mov di, 2           ; Height
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 16-17 ==========
    mov bx, si
    add bx, 6
    push dx
    mov cx, 18          ; Width (2x9)
    mov di, 2           ; Height
    mov al, 0x0A        ; Bright green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 18-19 ==========
    mov bx, si
    add bx, 4
    push dx
    mov cx, 22          ; Width (2x11)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 20-21 ==========
    ; Left green part
    mov bx, si
    add bx, 4
    push dx
    mov cx, 8           ; Width (2x4)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    ; Trunk
    mov bx, si
    add bx, 12
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x06        ; Brown
    call draw_rect
    pop dx
    
    ; Right green part
    mov bx, si
    add bx, 18
    push dx
    mov cx, 8           ; Width (2x4)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; ========== ROW 22-23 ==========
    ; Left green part
    mov bx, si
    add bx, 4
    push dx
    mov cx, 8           ; Width (2x4)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    ; Trunk
    mov bx, si
    add bx, 12
    push dx
    mov cx, 6           ; Width (2x3)
    mov di, 2           ; Height
    mov al, 0x06        ; Brown
    call draw_rect
    pop dx
    
    ; Right green part
    mov bx, si
    add bx, 18
    push dx
    mov cx, 8           ; Width (2x4)
    mov di, 2           ; Height
    mov al, 0x02        ; Dark green
    call draw_rect
    pop dx
    
    pop es
    pop si
    pop di
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
    inc word [road_scroll]
    and word [road_scroll], 0x0F
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
    mov ax, dx
    add ax, [road_scroll]
    test ax, 0x08
    jnz .no_left_line
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 140
    mov di, ax
    pop dx
    mov byte [es:di], 0x0E
    mov byte [es:di+1], 0x0E
.no_left_line:
    mov ax, dx
    add ax, [road_scroll]
    test ax, 0x08
    jnz .no_right_line
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 180
    mov di, ax
    pop dx
    mov byte [es:di], 0x0E
    mov byte [es:di+1], 0x0E
.no_right_line:
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 96
    mov di, ax
    pop dx
    mov al, 0x0C
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

put_pixel:
    push ax
    push bx
    push dx
    push di
    push es
    
    ; Check X bounds (BX must be 0-319)
    cmp bx, 320
    jae .out_of_bounds
    
    ; Check Y bounds (DX must be 0-199)
    cmp dx, 200
    jae .out_of_bounds
    
    push ax
    mov ax, [buffer_segment]
    mov es, ax
    
    mov ax, dx
    mov di, 320
    mul di
    add ax, bx
    mov di, ax
    
    pop ax
    mov [es:di], al
    
.out_of_bounds:
    pop es
    pop di
    pop dx
    pop bx
    pop ax
    ret
; Helper: Draw filled rectangle
draw_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, di
.row_loop:
    push cx
    push bx
.col_loop:
    call put_pixel
    inc bx
    loop .col_loop
    pop bx
    pop cx
    inc dx
    dec si
    jnz .row_loop
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
; Draw Nokia-style racing car (top-down view)
; AX = X position (column), BX = Y position (row), CL = car body color
draw_player_car:
    push ax
    push bx
    push cx
    push dx
    push di
    push si

    ; Save starting position and color
    mov si, ax          ; SI = starting X (was: mov si, ax)
    mov dx, bx          ; DX = starting Y (CHANGED from: push bx)
    mov [car_color], cl ; Save car body color

    ; Draw main car body (vertical rectangle)
    mov bx, si
    add bx, 4
    mov cx, 8           ; Width
    mov di, 20          ; Height (long vertical car)
    mov al, [car_color] ; Use given color
    call draw_rect

    ; Draw car front (nose)
    mov bx, si
    add bx, 5
    sub dx, 3
    mov cx, 6           ; Width
    mov di, 3           ; Height
    mov al, [car_color] ; Use given color
    call draw_rect

    ; Restore DX
    add dx, 3

    ; Draw spoiler/rear wing
    mov bx, si
    add bx, 3
    push dx
    add dx, 20
    mov cx, 10          ; Width
    mov di, 2           ; Height
    mov al, 12          ; Red spoiler
    call draw_rect
    pop dx

    ; Draw left wheel (front)
    mov bx, si
    add bx, 0           ; Move left wheel further out
    push dx
    add dx, 3
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0          ; Dark gray
    call draw_rect
    pop dx

    ; Draw right wheel (front)
    mov bx, si
    add bx, 13          ; Move right wheel further out
    push dx
    add dx, 3
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Dark gray
    call draw_rect
    pop dx

    ; Draw left wheel (rear)
    mov bx, si
    add bx, 0           ; Move left wheel further out
    push dx
    add dx, 13
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0         ; Dark gray
    call draw_rect
    pop dx

    ; Draw right wheel (rear)
    mov bx, si
    add bx, 13          ; Move right wheel further out
    push dx
    add dx, 13
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Dark gray
    call draw_rect
    pop dx

    ; Draw windshield/cockpit
    mov bx, si
    add bx, 5
    push dx
    add dx, 5
    mov cx, 6           ; Width
    mov di, 4           ; Height
    mov al, 3           ; Cyan/blue windshield
    call draw_rect
    pop dx

    ; Draw racing stripes (center line)
    mov bx, si
    add bx, 7
    add dx, 10
    mov cx, 2           ; Width
    mov di, 8           ; Height
    mov al, 15          ; White stripe
    call draw_rect

    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
; Draw opponent car (facing downward) - Same style as player car
; AX = X position (column), BX = Y position (row), CL = car body color
draw_opponent_car:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    ; Save starting position and color
    mov si, ax          ; SI = starting X
    mov dx, bx          ; DX = starting Y
    mov [car_color], cl ; Save car body color
    
    ; Draw spoiler/rear wing at the TOP (opponent car faces down)
    mov bx, si
    add bx, 3
    push dx
    mov cx, 10          ; Width
    mov di, 2           ; Height
    mov al, 12          ; Red spoiler
    call draw_rect
    pop dx
    
    ; Adjust DX for rest of car
    add dx, 2
    
    ; Draw main car body (vertical rectangle)
    mov bx, si
    add bx, 4
    mov cx, 8           ; Width
    mov di, 20          ; Height (long vertical car)
    mov al, [car_color] ; Use given color
    call draw_rect
    
    ; Draw windshield/cockpit
    mov bx, si
    add bx, 5
    push dx
    add dx, 11
    mov cx, 6           ; Width
    mov di, 4           ; Height
    mov al, 3           ; Cyan/blue windshield
    call draw_rect
    pop dx
    
    ; Draw racing stripes (center line)
    mov bx, si
    add bx, 7
    push dx
    add dx, 2
    mov cx, 2           ; Width
    mov di, 8           ; Height
    mov al, 15          ; White stripe
    call draw_rect
    pop dx
    
    ; Draw left wheel (front)
    mov bx, si
    add bx, 0           ; Left wheel position
    push dx
    add dx, 8
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Black tire
    call draw_rect
    pop dx
    
    ; Draw right wheel (front)
    mov bx, si
    add bx, 13          ; Right wheel position
    push dx
    add dx, 8
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Black tire
    call draw_rect
    pop dx
    
    ; Draw left wheel (rear)
    mov bx, si
    add bx, 0           ; Left wheel position
    push dx
    add dx, 18
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Black tire
    call draw_rect
    pop dx
    
    ; Draw right wheel (rear)
    mov bx, si
    add bx, 13          ; Right wheel position
    push dx
    add dx, 18
    mov cx, 3           ; Width
    mov di, 5           ; Height
    mov al, 0           ; Black tire
    call draw_rect
    pop dx
    
    ; Draw car front (nose) at the BOTTOM (opponent faces down)
    mov bx, si
    add bx, 5
    push dx
    add dx, 20
    mov cx, 6           ; Width
    mov di, 3           ; Height
    mov al, [car_color] ; Use given color
    call draw_rect
    pop dx
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================
; COIN SPRITE (12x12 centered)
; ============================================
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

; ============================================
; FUEL SPRITE (10x14 centered)
; ============================================
draw_road_fuel:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov si, ax          ; SI = X position
    mov dx, bx          ; DX = Y position
    
    ; Draw outer glow (light blue aura)
    mov bx, si
    sub bx, 1
    push dx
    sub dx, 1
    mov cx, 14          ; Width
    mov di, 18          ; Height
    mov al, 0x01        ; Dark blue glow
    call draw_rect
    pop dx
    
    ; Draw cap/handle (metallic silver)
    mov bx, si
    add bx, 4
    push dx
    mov cx, 4           ; Width
    mov di, 2           ; Height
    mov al, 0x07        ; Light gray
    call draw_rect
    pop dx
    
    ; Cap highlight
    mov bx, si
    add bx, 5
    push dx
    mov cx, 2           ; Width
    mov di, 1           ; Height
    mov al, 0x0F        ; White highlight
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; Top rim (gold/orange)
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x06        ; Brown/orange
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Upper body - Gradient effect (red to orange)
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x04        ; Red
    call draw_rect
    pop dx
    
    add dx, 1
    
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x0C        ; Light red
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Glass window showing fuel (with gradient)
    ; Top of fuel (bright yellow)
    mov bx, si
    add bx, 3
    push dx
    mov cx, 6           ; Width
    mov di, 1           ; Height
    mov al, 0x0E        ; Yellow
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Middle fuel (white - full brightness)
    mov bx, si
    add bx, 3
    push dx
    mov cx, 6           ; Width
    mov di, 2           ; Height
    mov al, 0x0F        ; White
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; Bottom fuel (light yellow)
    mov bx, si
    add bx, 3
    push dx
    mov cx, 6           ; Width
    mov di, 1           ; Height
    mov al, 0x0E        ; Yellow
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Window frame (dark gray border)
    ; Left border
    mov bx, si
    add bx, 2
    push dx
    sub dx, 4
    mov cx, 1           ; Width
    mov di, 4           ; Height
    mov al, 0x08        ; Dark gray
    call draw_rect
    pop dx
    
    ; Right border
    mov bx, si
    add bx, 9
    push dx
    sub dx, 4
    mov cx, 1           ; Width
    mov di, 4           ; Height
    mov al, 0x08        ; Dark gray
    call draw_rect
    pop dx
    
    ; Lower body - Gradient (light red to red)
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x0C        ; Light red
    call draw_rect
    pop dx
    
    add dx, 1
    
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x04        ; Red
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Bottom rim (gold/orange)
    mov bx, si
    add bx, 2
    push dx
    mov cx, 8           ; Width
    mov di, 1           ; Height
    mov al, 0x06        ; Brown/orange
    call draw_rect
    pop dx
    
    add dx, 1
    
    ; Spout (metallic silver with highlight)
    mov bx, si
    add bx, 4
    push dx
    mov cx, 4           ; Width
    mov di, 2           ; Height
    mov al, 0x07        ; Light gray
    call draw_rect
    pop dx
    
    ; Spout highlight
    mov bx, si
    add bx, 5
    push dx
    add dx, 1
    mov cx, 2           ; Width
    mov di, 1           ; Height
    mov al, 0x0F        ; White highlight
    call draw_rect
    pop dx
    
    ; Add shine/reflection on left side of body
    mov bx, si
    add bx, 2
    push dx
    sub dx, 8
    mov cx, 1           ; Width
    mov di, 2           ; Height
    mov al, 0x0F        ; White shine
    call draw_rect
    pop dx
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
;Even simpler version (true minimalist Nokia style):
; Draw ultra-simple Nokia-style fuel (like early mobile games)
; Input: AX = X position, BX = Y position
draw_fuel:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov si, ax          ; SI = X position
    mov dx, bx          ; DX = Y position
    
    ; Top cap
    mov bx, si
    add bx, 1
    push dx
    mov cx, 6           ; Width
    mov di, 2           ; Height
    mov al, 0x08        ; Dark gray
    call draw_rect
    pop dx
    
    add dx, 2
    
    ; Body with fuel window
    mov bx, si
    push dx
    mov cx, 8           ; Width
    mov di, 8           ; Height
    mov al, 0x04        ; Red body
    call draw_rect
    pop dx
    
    ; Fuel level indicator (simple rectangle)
    mov bx, si
    add bx, 2
    push dx
    add dx, 2
    mov cx, 4           ; Width
    mov di, 4           ; Height
    mov al, 0x0E        ; Yellow fuel
    call draw_rect
    pop dx
    
    add dx, 8
    
    ; Bottom base
    mov bx, si
    add bx, 1
    mov cx, 6           ; Width
    mov di, 2           ; Height
    mov al, 0x08        ; Dark gray
    call draw_rect
    
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
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
; SCORE DISPLAY
; ============================================
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
    
    ; First, clear the entire score area (25, 185) to (95, 194)
    mov dx, 185
.clear_loop:
    cmp dx, 194
    jge .clear_done
    push dx
    mov ax, dx
    mov bx, 320
    mul bx
    add ax, 25
    mov di, ax
    pop dx
    mov cx, 70
    mov al, 0x06
    rep stosb
    inc dx
    jmp .clear_loop
.clear_done:
    
    ; Draw "SCORE" label using pixel art at position (25, 185)
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
    add di, 320
    mov byte [es:di], al
    mov byte [es:di+1], al
    add di, 320
    add di, 320
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
    div bx
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
    add bx, 6
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

draw_pic:
    ; Open BMP file
    mov dx, filename
    mov ax, 0x3D00      ; Open file for reading
    int 0x21
    jc near file_error
    mov [handle], ax
    
    ; Read BMP header (54 bytes)
    mov bx, [handle]
    mov dx, bmp_header
    mov cx, 54
    mov ah, 0x3F        ; Read from file
    int 0x21
    jc near read_error
    
    ; Verify BMP signature ('BM')
    cmp word [bmp_header], 0x4D42
    jne near format_error
    
    ; Read palette (256 colors × 4 bytes = 1024 bytes)
    ; Palette comes right after header in 8-bit BMPs
    mov bx, [handle]
    mov dx, palette_buffer
    mov cx, 1024
    mov ah, 0x3F
    int 0x21
    jc near read_error
    
    ; Load palette into VGA DAC registers
    mov si, palette_buffer
    mov cx, 256         ; 256 colors
    xor al, al          ; Start at color 0
    mov dx, 0x3C8       ; DAC write index register
    out dx, al
    
    inc dx              ; 0x3C9 - DAC data register
load_palette:
    mov al, [si+2]      ; Blue (BMP stores as BGRA)
    shr al, 2           ; VGA uses 6-bit values (0-63)
    out dx, al
    
    mov al, [si+1]      ; Green
    shr al, 2
    out dx, al
    
    mov al, [si]        ; Red
    shr al, 2
    out dx, al
    
    add si, 4           ; Move to next palette entry
    loop load_palette
    
    ; Get pixel data offset from header (offset 10, 4 bytes)
    mov eax, [bmp_header + 10]
    mov [pixel_offset], eax
    
    ; Seek to pixel data offset
    ; We need to calculate how many more bytes to skip
    ; Current position = 54 (header) + 1024 (palette) = 1078
    mov eax, [pixel_offset]
    sub eax, 1078       ; Bytes to skip
    jbe .skip_seek       ; If offset <= current position, don't seek
    
    ; Skip remaining bytes to reach pixel data
    mov ecx, eax
.skip_loop:
    cmp ecx, 0
    je .skip_seek
    
    push ecx
    mov bx, [handle]
    mov dx, pixel_buffer
    mov cx, 320
    cmp ecx, [esp]      ; Compare with remaining bytes
    jbe .skip_read
    mov cx, [esp]       ; Read only remaining bytes
.skip_read:
    mov ah, 0x3F
    int 0x21
    pop ecx
    sub ecx, eax        ; Subtract bytes read
    jmp .skip_loop
    
.skip_seek:
    
    ; Set up video memory pointer
    ; BMP stores bottom-to-top, so start at last row
    mov ax, 0xA000
    mov es, ax
    mov di, 320 * 199   ; Start at row 199 (last row)
    mov bp, 200         ; Row counter - read 200 rows
    
read_rows:
    ; Read one row (320 pixels)
    mov bx, [handle]
    mov dx, pixel_buffer
    mov cx, 320
    mov ah, 0x3F
    int 0x21
    jc read_complete
    cmp ax, 0           ; Check if any bytes read
    je read_complete
    
    ; Copy row to video memory
    push di
    mov si, pixel_buffer
    mov cx, 320
    cld
    rep movsb
    pop di
    
    ; Move to previous row (BMP is bottom-to-top)
    sub di, 320
    dec bp              ; Decrement row counter
    jnz read_rows       ; Continue if more rows to read
    
read_complete:
    ; Close file
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

; Error handlers
file_error:
    ret

read_error:
    ; Close file if it was opened
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

format_error:
    ; Close file
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    ret

   

; ============================================
; DATA SECTION
; ============================================
quit_flag            db 0
player_x             dw 160
player_y             dw 175
oldisr               dd 0
oldtimer             dd 0
obstacle_x           dw 0
obstacle_y           dw 0
obstacle_active      db 0
obstacle_counter     db 0
obstacle2_x          dw 0
obstacle2_y          dw 0
obstacle2_active     db 0
obstacle2_counter    db 0
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

; Music variables
music_enabled        db 1
music_tick_counter   dw 0
current_note_index   dw 0
note_duration        dw 10      ; Adjust for tempo (higher = slower)

; Melody data (frequencies in Hz)
; 0 = rest, 1 = end of melody
melody:
 ; AGGRESSIVE RACING MELODY - Fast, intense, chromatic
; Simulates engine revving, gear shifts, and high-speed intensity

; Opening: Engine rev-up (rapid ascending chromatic)
dw 262, 277, 294, 311, 330, 349, 370, 392    ; C4->G4 chromatic climb
dw 415, 440, 466, 494, 523, 554, 587, 622    ; G#4->D#5 higher rev

; Main aggressive riff (dissonant, driving)
dw 659, 622, 659, 698      ; E5 D#5 E5 F5 (tension)
dw 740, 698, 740, 784      ; F#5 F5 F#5 G5 (more tension)
dw 831, 784, 831, 880      ; G#5 G5 G#5 A5 (peak intensity)
dw 932, 988, 1047, 0       ; A#5 B5 C6 REST (climax + brake)

; Power chord style (low octaves for bass impact)
dw 196, 196, 233, 233      ; G3 G3 A#3 A#3 (heavy)
dw 262, 262, 311, 311      ; C4 C4 D#4 D#4 (power)
dw 196, 233, 262, 294      ; G3 A#3 C4 D4 (ascending punch)

; Speed run (16th note simulation - very fast)
dw 523, 554, 587, 622, 659, 698, 740, 784    ; C5->G5 rapid
dw 831, 880, 932, 988, 1047, 988, 932, 880   ; Up to C6 and back down

; Syncopated rhythm (engine misfire/backfire effect)
dw 392, 0, 392, 0          ; G4 REST G4 REST
dw 466, 0, 466, 0          ; A#4 REST A#4 REST
dw 587, 0, 587, 0          ; D5 REST D5 REST
dw 698, 740, 784, 0        ; F5 F#5 G5 REST (sudden cut)

; Descending chromatic dive (downshift/drift)
dw 1047, 988, 932, 880     ; C6->A5
dw 831, 784, 740, 698      ; G#5->F5
dw 659, 622, 587, 554      ; E5->C#5
dw 523, 494, 466, 440      ; C5->A4 (finish dive)

; Final aggressive burst
dw 196, 262, 330, 392      ; G3 C4 E4 G4 (power chord spread)
dw 494, 587, 659, 784      ; B4 D5 E5 G5 (higher octave)
dw 880, 880, 880, 0        ; A5 A5 A5 REST (final rev)

dw 0                       ; Loop back
; Configuration
OBSTACLE_INTERVAL    db 50
COIN_INTERVAL        db 60
FUEL_INTERVAL        db 90
MAX_FUEL             dw 200
FUEL_DECREASE_RATE   db 1
FUEL_REFILL_AMOUNT   dw 50
MOVE_COOLDOWN_TIME   db 10
buffer_segment       dw 0x7000

; Strings
game_title           db '=== ASPHALT LEGENDS ===', 0
dev_names            db 'Dev1: Saad Ali 24L-0652', 0
roll_nos             db 'Dev2: Saad Sohail 24L-0745', 0
music_instruction    db 'Music: SPACE to toggle', 0
press_start          db 'Press ANY Key to Start', 0
input_prompt_name    db 'Enter Name: ', 0
input_prompt_roll    db 'Enter Roll: ', 0
instr_title          db '--- INSTRUCTIONS ---', 0
instr_1              db 'Left/Right: Change Lanes', 0
instr_2              db 'Up/Down: Move Car', 0
instr_3              db 'Collect Coins for Points', 0
instr_4              db 'Collect Fuel to Keep Moving', 0
instr_5              db 'ESC: Pause/Quit', 0
instr_music          db 'SPACE: Toggle Music', 0
instr_press          db 'Press ANY Key to Play', 0
game_over_msg        db '=== GAME OVER ===', 0
collision_msg        db 'Collision!', 0
fuel_empty_msg       db 'Out of Fuel!', 0
player_label         db 'Player: ', 0
roll_label           db 'Roll No: ', 0
final_score_label    db 'Final Score: ', 0
music_status         db 'Music: ', 0
on_msg               db 'ON', 0
off_msg              db 'OFF', 0
play_again_msg       db 'Enter: Restart | ESC: Exit', 0
confirm_msg          db 'Quit Game? (Y/N)', 0
pause_msg            db 'Quit? (Y/N)', 0

player_name_buf      times 20 db 0
player_roll_buf      times 20 db 0
score_buffer         times 6 db 0
temp_x               dw 0
temp_y               dw 0
car_color db 0
filename db "PICTURE.bmp", 0
handle dw 0
bmp_header times 54 db 0
palette_buffer times 1024 db 0
pixel_buffer times 320 db 0
pixel_offset dd 0

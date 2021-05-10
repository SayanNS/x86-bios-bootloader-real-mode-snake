VIDEO_MEMORY equ 0xB800

VIDEO_SCREEN_WIDTH equ 80
VIDEO_SCREEN_HEIGHT equ 25

TIMER_INTERRUPT_OFFSET equ 0x20
TIMER_INTERRUPT_SEGMENT equ 0x22
KEYBOARD_INTERRUPT_OFFSET equ 0x24
KEYBOARD_INTERRUPT_SEGMENT equ 0x26
LOOP_STEP_VALUE equ 0x10

SNAKE_INITIAL_POS_Y equ 12
SNAKE_INITIAL_POS_X equ 20
SNAKE_INITIAL_WIDTH equ 5
SNAKE_SYMBOL equ '#'
FOOD_SYMBOL equ '*'
EMPTY_SYMBOL equ ' '

VERTICAL equ 0x80
HORIZONTAL equ 0x0
INCREMENT equ 0x1
DECREMENT equ 0x0

DIRECTION_LEFT	equ HORIZONTAL | DECREMENT
DIRECTION_RIGHT	equ HORIZONTAL | INCREMENT
DIRECTION_UP	equ VERTICAL | DECREMENT
DIRECTION_DOWN	equ VERTICAL | INCREMENT

BUTTON_LEFT_SCANCODE	equ 0x4B
BUTTON_UP_SCANCODE	equ 0x48
BUTTON_RIGHT_SCANCODE	equ 0x4D
BUTTON_DOWN_SCANCODE	equ 0x50

section .text
	global start
	use16
start:
	mov ax, 0x0
	mov ds, ax
	mov ax, VIDEO_MEMORY
	mov es, ax

	; disable cursor
	mov ah, 0x01
	mov ch, 0x3F
	int 0x10

	; save default interrupt handler address
	mov ax, [TIMER_INTERRUPT_OFFSET]
	mov [saved_timer_interrupt_handler.offset_address], ax
	mov ax, [TIMER_INTERRUPT_SEGMENT]
	mov [saved_timer_interrupt_handler.segment_address], ax
	
	; override default interrupt handlers
	cli
	mov ax, my_timer_interrupt_handler
	mov [TIMER_INTERRUPT_OFFSET], ax
	mov ax, my_keyboard_interrupt_handler
	mov [KEYBOARD_INTERRUPT_OFFSET], ax
	mov ax, 0x0
	mov [TIMER_INTERRUPT_SEGMENT], ax
	mov [KEYBOARD_INTERRUPT_SEGMENT], ax
	sti

restart:
	; initialize snake head and tail data
	mov word [snake.tail], (SNAKE_INITIAL_POS_Y << 8) + SNAKE_INITIAL_POS_X
	mov word [snake.head], (SNAKE_INITIAL_POS_Y << 8) + SNAKE_INITIAL_POS_X + SNAKE_INITIAL_WIDTH - 1
	mov byte [snake.direction], DIRECTION_RIGHT

	; initialize timer interrupt counter to zero
	mov word [timer_interrupt_counter], 0x0

	; show our initial snake on the screen
	mov cx, SNAKE_INITIAL_WIDTH
	mov ax, SNAKE_INITIAL_POS_Y * VIDEO_SCREEN_WIDTH + SNAKE_INITIAL_POS_X
show_snake:
	mov bx, ax
	add bx, snake.directions
	mov byte [bx], DIRECTION_RIGHT
	mov bx, ax
	shl bx, 1
	mov byte [es:bx], SNAKE_SYMBOL
	inc ax
	dec cx
	jnz show_snake

	; initialize timer interrupt counter
	mov word [timer_interrupt_counter], 0x0

wait_loop:
	hlt
	mov ax, [timer_interrupt_counter]
	cmp ax, LOOP_STEP_VALUE
	jne wait_loop

	mov word [timer_interrupt_counter], 0x0

	mov cx, [snake.head]
	call fun_get_direction_pointer
	mov al, [snake.direction]
	mov [bx], al
	call fun_get_next
	call fun_get_symbol_pointer
	mov al, [es:bx]
	cmp al, SNAKE_SYMBOL
	je game_over
	cmp al, FOOD_SYMBOL
	je eat_food
	mov byte [es:bx], SNAKE_SYMBOL
	mov [snake.head], cx

	mov cx, [snake.tail]
	call fun_get_symbol_pointer
	mov byte [es:bx], EMPTY_SYMBOL
	call fun_get_next
	mov [snake.tail], cx

	jmp wait_loop

eat_food:

game_over:
	hlt
	jmp game_over

my_timer_interrupt_handler:
	push ax
	mov ax, [timer_interrupt_counter]
	inc ax
	mov [timer_interrupt_counter], ax
	pop ax
	jmp far [saved_timer_interrupt_handler]

my_keyboard_interrupt_handler:
	push ax

	in al, 0x60
	test al, al
	js return_from_keyboard_interrupt
	
	cmp al, BUTTON_LEFT_SCANCODE
	je button_left_pressed
	cmp al, BUTTON_UP_SCANCODE
	je button_up_pressed
	cmp al, BUTTON_RIGHT_SCANCODE
	je button_right_pressed
	cmp al, BUTTON_DOWN_SCANCODE
	je button_down_pressed
	jmp return_from_keyboard_interrupt
button_left_pressed:
	mov al, DIRECTION_LEFT
	jmp change_direction
button_up_pressed:
	mov al, DIRECTION_UP
	jmp change_direction
button_right_pressed:
	mov al, DIRECTION_RIGHT
	jmp change_direction
button_down_pressed:
	mov al, DIRECTION_DOWN
change_direction:
	mov [snake.direction], al
return_from_keyboard_interrupt:
	mov al, 0x20
	out 0x20, al
	pop ax
	iret

fun_get_direction_pointer:
	mov al, ch
	mov bl, VIDEO_SCREEN_WIDTH
	mul bl
	xor bh, bh
	mov bl, cl
	add bx, ax
	add bx, snake.directions
	ret

	; in: ch=y, cl=x, ds=0x0, es=0x8B00
	; out: ch=y, cl=x
	; modified: ax, bx
fun_get_next:
	call fun_get_direction_pointer
	mov al, [bx]

	test al, VERTICAL
	jnz vertical
	mov ah, cl
	mov bl, cl

	test al, INCREMENT
	jnz right

	mov al, 0x0
	mov bh, VIDEO_SCREEN_WIDTH - 1
	dec bl
	call fun_compare
	mov cl, ah
	ret
right:
	mov al, VIDEO_SCREEN_WIDTH - 1
	mov bh, 0x0
	inc bl
	call fun_compare
	mov cl, ah
	ret
vertical:
	mov ah, ch
	mov bl, ch

	test al, INCREMENT
	jnz down
	
	mov al, 0x0
	mov bh, VIDEO_SCREEN_HEIGHT - 1
	dec bl
	call fun_compare
	mov ch, ah
	ret
down:
	mov al, VIDEO_SCREEN_HEIGHT - 1
	mov bh, 0x0
	inc bl
	call fun_compare
	mov ch, ah
	ret

fun_compare:
	cmp ah, al
	je equal
	mov ah, bl
	ret
equal:
	mov ah, bh
	ret

fun_get_symbol_pointer:
	mov al, ch
	mov bl, VIDEO_SCREEN_WIDTH
	mul bl
	xor bh, bh
	mov bl, cl
	add bx, ax
	shl bx, 1
	ret

; section .data
; hex db '0123456789ABCDEF'

section .bss
saved_timer_interrupt_handler:
.offset_address resw 1
.segment_address resw 1

timer_interrupt_counter resw 1

snake:
.direction resb 1
.directions resb VIDEO_SCREEN_WIDTH * VIDEO_SCREEN_HEIGHT
.head resb 2
.tail resb 2

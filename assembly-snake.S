#pragma qtmips show terminal
#pragma qtmips show peripherals
#pragma qtmips show lcd_display

//assembly-snake
//https://github.com/mariomarton/assembly-snake

.data

//for unpredicable food spawning, replace the 0 in OPTIONAL_NUMBER with a number from 0 to 10
.equ OPTIONAL_NUMBER,	0

//two array of tuples (address_where_direction_changed, new_direction)
//used for correct deletion of the tails
s1_directionChanges: 	.space 800
s2_directionChanges: 	.space 800

//couldn't make the random syscall work
//so instead these arrays with pre-generated random values are used
x_values: 		.space 48 //12 values
y_values:		.space 32 //8 values

lastX:		.word 0
lastY:		.word 0

lastInput:		.word 0

foodLocation:		.word 0
randomNumber:		.word 0
backUp1:		.word 0
backUp2:		.word 0
colorVar:		.word 0
thisSnake:		.word 0

//s1 means snake 1; s2 means snake 2
s1_head:		.word 0
s1_tail:		.word 0
s2_head:		.word 0
s2_tail:		.word 0

s1_dir_old:		.word 0
s1_dir_new:		.word 0
s2_dir_old:		.word 0
s2_dir_new:		.word 0

s2_keyboardInput:	.word 0

s1_lastTailDir:	.word 0
s2_lastTailDir:	.word 0

//current directionChanges array positions
s1_arrOffset:		.word 0 
s2_arrOffset:		.word 0

s1_lastKnobsVal:	.word 0
s2_lastKnobsVal:	.word 0

.equ SNAKE1_OFFSET,    0x5a40
.equ SNAKE2_OFFSET,    0x5bd0
.equ SNAKE_LEN_START,       3

//1/2/3/4 -> up/down/left/right
.equ INIT_DIRECTION_SNAKE1,        2
.equ INIT_DIRECTION_SNAKE2,        1

.set SERIAL_PORT_BASE,     0xffffc000
.set SERP_RX_ST_REG_o,           0x00
.set SERP_RX_ST_REG_READY_m,      0x1
.set SERP_RX_ST_REG_IE_m,         0x2
.set SERP_RX_DATA_REG_o,         0x04
.set SERP_TX_ST_REG_o,           0x08
.set SERP_TX_ST_REG_READY_m,      0x1
.set SERP_TX_ST_REG_IE_m,         0x2
.set SERP_TX_DATA_REG_o,         0x0c
.equ SERIAL_PORT_BASE,      0xffffc000
.equ SERP_RX_ST_REG,        0xffffc000
.equ SERP_RX_ST_REG_o,          0x0000
.equ SERP_RX_ST_REG_READY_m,       0x1
.equ SERP_RX_ST_REG_IE_m,          0x2
.equ SERP_RX_DATA_REG,      0xffffc004
.equ SERP_RX_DATA_REG_o,        0x0004
.equ SERP_TX_ST_REG,        0xffffc008
.equ SERP_TX_ST_REG_o,          0x0008
.equ SERP_TX_ST_REG_READY_m,       0x1
.equ SERP_TX_ST_REG_IE_m,          0x2
.equ SERP_TX_DATA_REG,      0xffffc00c
.equ SERP_TX_DATA_REG_o,        0x000c
.equ SPILED_REG_BASE,       0xffffc100 
.equ SPILED_REG_LED_RGB1,   0xffffc110
.equ SPILED_REG_LED_RGB2,   0xffffc114
.equ KNOBS_BASE,            0xffffc124
.equ LCD_FB_START,          0xffe00000
.equ LCD_FB_END,            0xffe4afff

//colors for the display:
.equ WHITE,		0xffffffff
.equ GRAY,		0xdedbdedb
.equ BLACK,		0x00000000
.equ YELLOW,		0xffe0ffe0
.equ DARK_YELLOW,	0xff00ff00
.equ LIGHT_BLUE,	0x03ff03ff
.equ RED,		0xd800

//colors for the LEDs:
.equ LED_BLUE,	0x000096d0
.equ LED_GREEN,	0x00d009
.equ LED_RED,		0xd00000

.text

//the foundation of the methods for using the serial port input
//was borrowed from the cop0-test-ia.S featured in qtmips

_start:
	synci	0($zero)
	la	$20, input_init
	mtc0	$20, $14, 0
	eret

input_init:
	addi	$a0, $zero, SNAKE_LEN_START
	la	$a1, LCD_FB_START
	addi	$a1, $a1, SNAKE1_OFFSET
	addi	$a1, $a1, SNAKE1_OFFSET
	addi	$a1, $a1, SNAKE1_OFFSET
	addi	$a1, $a1, 80
	la	$20, irq_entry - 0x180
	mtc0	$20, $15, 1

	li	$21, SERIAL_PORT_BASE
	li	$20, SERP_RX_ST_REG_IE_m
	sw	$20, SERP_RX_ST_REG_o($21)
	li	$20, 0x00000801
	mtc0	$20, $12, 0

game_init:
	mfc0	$10, $14, 0
	
	//variables init

	//lastTailDir = INIT_DIRECTION
	la	$t0, s1_lastTailDir
	addi	$t1, $zero, INIT_DIRECTION_SNAKE1
	sw	$t1, 0($t0)
	nop
	la	$t0, s2_lastTailDir
	addi	$t1, $zero, INIT_DIRECTION_SNAKE2
	sw	$t1, 0($t0)
	nop

	la	$t1, lastX
	la	$t3, OPTIONAL_NUMBER
	sw	$t3, 0($t1)
	
	//last_red_knob_value = current_red_value
	la	$t2, KNOBS_BASE
	lh	$t1, 0($t2)
	nop
	la	$t2, s1_lastKnobsVal 
	sw	$t1, 0($t2)
	nop

	//last_blue_knob_value = current_blue_value
	la	$t2, KNOBS_BASE
	li	$t4, 0
	add	$t2, $t2, $t4
	add	$t2, $t2, $t4
	lw	$t1, 0($t2)
	nop
	andi	$t2, $t1, 0x0000ff
	nop
	add	$t1, $zero, $t2
	la	$t2, s2_lastKnobsVal
	sw	$t1, 0($t2)
	nop

	//set x_values and y_values for food spawning:
	la	$t2, x_values
	li	$t1, 29
	sw	$t1, 0($t2)
	li	$t1, 27
	sw	$t1, 4($t2)
	li	$t1, 25
	sw	$t1, 8($t2)
	li	$t1, 19
	sw	$t1, 12($t2)
	li	$t1, 26
	sw	$t1, 16($t2)
	li	$t1, 22
	sw	$t1, 20($t2)
	li	$t1, 30
	sw	$t1, 24($t2)
	li	$t1, 25
	sw	$t1, 28($t2)
	li	$t1, 33
	sw	$t1, 32($t2)
	li	$t1, 25
	sw	$t1, 36($t2)
	li	$t1, 19
	sw	$t1, 40($t2)
	li	$t1, 15
	sw	$t1, 44($t2)

	la	$t2, y_values
	li	$t1, 19
	sw	$t1, 0($t2)
	li	$t1, 11
	sw	$t1, 4($t2)
	li	$t1, 10
	sw	$t1, 8($t2)
	li	$t1, 16
	sw	$t1, 12($t2)
	li	$t1, 13
	sw	$t1, 16($t2)
	li	$t1, 19
	sw	$t1, 20($t2)
	li	$t1, 12
	sw	$t1, 24($t2)
	li	$t1, 5
	sw	$t1, 28($t2)

	//the programme generally uses
		//$a1 for snake_head address on LCD
		//$a2 for snake_tail address on LCD
		//$a3 for color on LCD
		//$t0 for new snake direction
		//$s0 for old snake direction

	addi	$t0, $zero, INIT_DIRECTION_SNAKE1 //thisMove
	addi	$s0, $zero, INIT_DIRECTION_SNAKE1 //prevMove
	addi	$a0, $zero, SNAKE_LEN_START
	
	//draw the food first
	la	$ra, initDrawSnake1
	j	drawFood
	nop

	//then use drawSnake() to draw both snakes

	//drawSnake() - only used in the init
		//agrs:
		//$a0 - length
		//$a1 - address
		//$t0 - direction (1/2/3/4 -> up/down/left/right
		//colorVar - color of the snake
		//$ra

	initDrawSnake1:
	la	$ra, postDrawSnake1
	la	$t1, colorVar
	li	$t2, RED
	sw	$t2, 0($t1)

	j	drawSnake
	nop

	postDrawSnake1:	
	//set the first LED to green
	li	$ra, initDrawSnake2
	li	$t1, LED_GREEN
	j	lightOn_One
	nop

	initDrawSnake2:
	//set drawSnake() args for drawing the second snake
	la	$t1, backUp1
	sw	$a1, 0($t1)
	la	$t2, backUp2
	sw	$a2, 0($t2)

	la	$a1, LCD_FB_START
	addi	$a1, $a1, SNAKE2_OFFSET
	addi	$a1, $a1, SNAKE1_OFFSET
	addi	$a1, $a1, SNAKE1_OFFSET
	addi	$a1, $a1, 80

	li	$t1, 7680
	li	$t2, 20
	mul	$t3, $t1, $t2
	add	$a1, $a1, $t3

	la	$t1, colorVar
	li	$t2, LIGHT_BLUE
	sw	$t2, 0($t1)

	addi	$t0, $zero, INIT_DIRECTION_SNAKE2 //thisMove
	la	$ra, postDrawSnake2
	j	drawSnake
	nop
	
	postDrawSnake2:
	//set s2_head, s2_tail and s2_dir_new variables
	la	$t1, s2_head
	sw	$a1, 0($t1)
	la	$t2, s2_tail
	sw	$a2, 0($t2)
	la	$t1, s2_dir_new
	sw	$t0, 0($t1)

	la	$t1, backUp1
	lw	$a1, 0($t1)
	la	$t2, backUp2
	lw	$a2, 0($t2)
	addi	$t0, $zero, INIT_DIRECTION_SNAKE1 //thisMove

	//set the second LED to green
	li	$ra, main_loop
	li	$t1, LED_GREEN
	j	lightOn_Two
	nop

irq_entry:
	mfc0	$26, $13, 0  // read Cause
	andi	$27, $26, 0x00000800 // see if b11 - RX is set
	bne	$27, $0, rx_irq // if so jump to rx_irq
	nop
	mfc0	$27, $12, 0  // Status, just in case
	nor	$26, $26, $0 //prepare mask
	andi	$26, $26, 0x0000ff00 //leave only interr pending bits
	and	$27, $27, $26 //mask unhandled source
	mtc0	$27, $12, 0  //disable them in source (unhandled..)
	eret

rx_irq:
	li	$26, SERIAL_PORT_BASE
	lw	$27, SERP_RX_DATA_REG_o($26) // STORING THE CHAR FROM INPUT
	sw	$27, SERP_TX_DATA_REG_o($26) // echo to terminal
	eret	//ret from interr

//the main game loop
main_loop:	
	//snake1_direction_old = snake1_direction_new
	add	$s0, $zero, $t0
	
	//snake2_direction_old = snake2_direction_new
	la	$t3, s2_dir_old
	la	$t4, s2_dir_new
	lw	$t1, 0($t4)
	sw	$t1, 0($t3)

	la	$t2, thisSnake
	li	$t3, 1
	sw	$t3, 0($t2)
	la	$a3, RED

	//updateSnake() is a key method that adds new head
	//and removes the snake tail

	//it also includes collision detection,
	//extention when eating food & more
	
	//updateSnake()
	//	args:
	//	$a1 - head addr
	//	$a2 - tail addr
	//	$a3 - snake color
	//	$t0 - direction (1/2/3/4)
	//	thisSnake (1 or 2)
	//
	//   	returns 	$a1 - new head addr
	//  		$a2 - new tail addr

	//call it for snake 1
	la	$ra, continue
	j 	updateSnake
	nop

	continue:
	//prepare updateSnake() args for snake 2
	la	$t1, s1_head
	sw	$a1, 0($t1)
	la	$t2, s1_tail
	sw	$a2, 0($t2)
	la	$t1, s1_dir_new
	sw	$t0, 0($t1)		

	la	$t1, s2_head
	lw	$a1, 0($t1)
	la	$t2, s2_tail
	lw	$a2, 0($t2)
	la	$t1, s2_dir_new
	lw	$t0, 0($t1)

	la	$t2, thisSnake
	li	$t3, 2
	sw	$t3, 0($t2)	

	//call the method for snake 2
	la	$a3, LIGHT_BLUE
	la	$ra, afterUpdateSnake2
	j 	updateSnake
	nop

	afterUpdateSnake2:
	//update s2_head/tail and set a1,a2,t0 registers back to previous snake 1 state
	la	$t1, s2_head
	sw	$a1, 0($t1)
	la	$t2, s2_tail
	sw	$a2, 0($t2)

	la	$t1, s1_head
	lw	$a1, 0($t1)
	la	$t2, s1_tail
	lw	$a2, 0($t2)

	add	$t0, $zero, $s0 //this_direction = prev_direction
	
	//if input from keyboard same as in the last cycle: branch to checking the knobs
	la	$t2, lastInput
	lw	$t1, 0($t2)
	beq	$t1, $k1, postSet
	
	la	$t2, s2_keyboardInput
	sw	$zero, 0($t2)	

	//check for WSAD (snake 1) keyboard input
	addi	$t1, $zero, 0x77
	beq 	$k1, $t1, inputDirU
	addi	$t1, $zero, 0x73
	beq 	$k1, $t1, inputDirD
	addi	$t1, $zero, 0x61
	beq 	$k1, $t1, inputDirL
	addi	$t1, $zero, 0x64
	beq 	$k1, $t1, inputDirR

	//check for IKJL (snake 2)keyboard input
	addi	$t1, $zero, 0x69
	beq 	$k1, $t1, inputDirU_s2
	addi	$t1, $zero, 0x6b
	beq 	$k1, $t1, inputDirD_s2
	addi	$t1, $zero, 0x6a
	beq 	$k1, $t1, inputDirL_s2
	addi	$t1, $zero, 0x6c
	beq 	$k1, $t1, inputDirR_s2
	nop

	postSet:
	la	$t2, s2_keyboardInput
	lw	$t1, 0($t2)
	la	$t4, s2_dir_old
	lw	$t2, 0($t4)
	beq	$t1, $t2, set_s2_key_to_zero
	
	postSet2:
	nop
	la	$t2, lastInput
	sw	$k1, 0($t2)

	//check for red knob input
	//$t1 = current_red_knob_val; $t2 = prev_red_knob_val
	la	$t5, KNOBS_BASE
	lh	$t1, 0($t5)
	nop
	la	$t5, s1_lastKnobsVal
	lw	$t2, 0($t5)
	nop
	beq	$t1, $t2, postKnobs

	//if current_red_knob_val != prev_red_knob_val:
		//prev_red_knob_val = current_red_knob_val
		//this_direction = direction_in_knob
	nop
	sw	$t1, 0($t5)
	//if knob val is in (97,160): dir = 1
	//elif knob val is in (0,32) or (223,255): dir = 2
	//elif knob val is in (33,96): dir = 3
	//elif knob val is in (161,222): dir = 4
	la	$ra, postKnobs
	li	$t2, 97
	slt	$t5, $t1, $t2
	nop
	bne	$t5, $zero, its_96_or_less
	//knob val is in (97,255)
		//if it's <161, dir = 1
	li	$t2, 161
	slt	$t5, $t1, $t2
	bne	$t5, $zero, its_97_to_160
	//knob val is in (161,255)
		//if it's <223, dir = 4
	li	$t2, 223
	slt	$t5, $t1, $t2
	bne	$t5, $zero, its_161_to_222
	//knob val is in (223,255), so dir = 2
	addi	$t0, $zero, 2

	postKnobs:
	//direction validity check:
		//if prev==up && this==down: this==prev
		//elif prev==down && this==up: this==prev
		//elif prev==left && this==right: this==prev
		//elif prev==right && this==left: this==prev
	add	$t2, $zero, $s0
	la	$ra, update
	addi	$t1, $zero, 1
	beq	$s0, $t1, upValidity
	addi	$t1, $t1, 1
	beq	$s0, $t1, downValidity
	addi	$t1, $t1, 1
	beq	$s0, $t1, leftValidity
	addi	$t1, $t1, 1
	beq	$s0, $t1, rightValidity
	nop

	//if direction changed: store address and the new direction into directionChanges array
	update:
	la	$ra, retHere
	la	$t1, s1_directionChanges
	la	$t2, s1_arrOffset
	nop
	bne	$s0, $t0, updateArr

	retHere:
	nop
	la	$t1, s1_dir_new
	sw	$t0, 0($t1)

	//snake 1 done, now to snake 2

	//if received keyboard input for snake 2, save it and don't check the blue knob
	la	$t2, s2_keyboardInput
	lw	$t1, 0($t2)
	bne	$t1, $zero, s2_gotKeyInput
	nop
	
	//check for input from blue knob
	la	$t1, s2_dir_old
	lw	$t0, 0($t1)	
	
	la	$t2, KNOBS_BASE
	lw	$t1, 0($t2)
	nop
	andi	$t2, $t1, 0x0000ff
	nop
	add	$t1, $zero, $t2 //current blue knob val now in $t1
	
	la	$t5, s2_lastKnobsVal
	lw	$t2, 0($t5)
	nop
	beq	$t1, $t2, s2_validity

	//if current_blue_knob_val != prev_blue_knob_val:
		//prev_blue_knob_val = current_blue_knob_val
		//this_direction = direction_in_knob
	nop
	sw	$t1, 0($t5)
	la	$ra, s2_validity
	li	$t2, 97
	slt	$t5, $t1, $t2
	nop
	bne	$t5, $zero, its_96_or_less
	li	$t2, 161
	slt	$t5, $t1, $t2
	bne	$t5, $zero, its_97_to_160
	li	$t2, 223
	slt	$t5, $t1, $t2
	bne	$t5, $zero, its_161_to_222
	addi	$t0, $zero, 2
	//end of blueKnobChecking
	
	s2_validity:
	//check snake 2 direction validity

	la	$t9, s2_dir_old
	lw	$t2, 0($t9)

	la	$ra, s2_validity_1

	addi	$t1, $zero, 1
	beq	$t2, $t1, upValidity
	addi	$t1, $t1, 1
	beq	$t2, $t1, downValidity
	addi	$t1, $t1, 1
	beq	$t2, $t1, leftValidity
	addi	$t1, $t1, 1
	beq	$t2, $t1, rightValidity
	nop
	
	s2_validity_1:
	la	$t2, s2_dir_old
	lw	$t5, 0($t2)
	
	la	$t1, s2_head
	lw	$a1, 0($t1)

	//if dir changed: store address and the new dir into s2_directionChanges array
	la	$ra, s2_validity_2
	la	$t1, s2_directionChanges
	la	$t2, s2_arrOffset
	bne	$t5, $t0, updateArr
	nop

	//update registers and variables to get ready for next cycle
	s2_validity_2:
	la	$t1, s1_head
	lw	$a1, 0($t1)
	la	$t1, s2_dir_new
	sw	$t0, 0($t1)
	nop
	la	$t1, s1_dir_new
	lw	$t0, 0($t1)
	j main_loop
	nop

//a few insignificant helper methods
set_s2_key_to_zero:
	la	$t2, s2_keyboardInput
	sw	$zero, 0($t2)	
	j	postSet2
	nop

s2_gotKeyInput:
	add	$t0, $zero, $t1
	nop
	j s2_validity
	nop

its_96_or_less:
	li	$t2, 33
	slt	$t5, $t1, $t2
	bne	$t5, $zero, its_32_or_less
	//this case = (33,96)
	nop
	addi	$t0, $zero, 3
	jr	$ra
	nop
	//this case = (0,32)
	its_32_or_less:
	addi	$t0, $zero, 2
	jr	$ra
	nop

its_97_to_160:
	addi	$t0, $zero, 1
	jr	$ra
	nop

its_161_to_222:
	addi	$t0, $zero, 4
	jr	$ra
	nop

upValidity:	//prevMove=up
	//if this==down: this==prev & jump to update
	//else jump to update
	addi $t1, $zero, 2
	bne $t0, $t1, GoBack
	nop
	add $t0, $zero, $t2
	
	j GoBack
	nop

downValidity:	//prevMove=down
	//if this==up: this==prev & jump to update
	//else jump to update
	addi $t1, $zero, 1
	bne $t0, $t1, GoBack
	nop
	add $t0, $zero, $t2
	
	j GoBack
	nop

leftValidity:	//prevMove=left
	//if this==right: this==prev & jump to update
	//else jump to update
	addi $t1, $zero, 4
	bne $t0, $t1, GoBack
	nop
	add $t0, $zero, $t2
	
	j GoBack
	nop

rightValidity://prevMove=right
	//if this==left: this==prev & jump to update
	//else jump to update
	addi $t1, $zero, 3
	bne $t0, $t1, GoBack
	nop
	add $t0, $zero, $t2
	
	j GoBack
	nop

GoBack:	jr $ra
	nop

inputDirU: 	addi	$t0, $zero, 1
	j postSet
	nop

inputDirD: 	addi	$t0, $zero, 2
	j postSet
	nop

inputDirL: 	addi	$t0, $zero, 3
	j postSet
	nop

inputDirR: 	addi	$t0, $zero, 4
	j postSet
	nop

inputDirU_s2: 
	addi	$t1, $zero, 1
	sw	$t1, 0($t2)
	j postSet
	nop

inputDirD_s2: 
	addi	$t1, $zero, 2
	sw	$t1, 0($t2)
	j postSet
	nop

inputDirL_s2: 
	addi	$t1, $zero, 3
	sw	$t1, 0($t2)
	j postSet
	nop

inputDirR_s2: 
	addi	$t1, $zero, 4
	sw	$t1, 0($t2)
	j postSet
	nop

//updateArr() updates the s1 or s2 directionChanges array
//with a new address where the direction changes and the direction itself
	//args:
	//$a1 - address
	//$t0 - new_direction
	//$t1 - directionChanges array
	//$t2 - array offset
updateArr:	

	//directionChanges[arrOffset] = address
	//directionChanges[arrOffset+4_or_sth] = new_direction
	//arrOffset+=2 (8)

	//store &directionChanges+arrOffset to $t1
	lw	$t5, 0($t2)
	nop
	add	$t1, $t1, $t5

	sw	$a1, 0($t1) ////directionChanges[arrOffset] = address
	addi	$t1, $t1, 4 //store &directionChanges+arrOffset+1 to $t1
	sw	$t0, 0($t1) //directionChanges[arrOffset+1] = newDirection
	
	//arrOffset += 2
	addi	$t5, $t5, 8
	sw	$t5, 0($t2)
	jr 	$ra
	nop

//updateSnake(), as stated previously, is a key method that adds new head
//and removes the snake tail
//it also includes collision detection,
//extention when eating food & more
//	args:
//	$a1 - head addr
//	$a2 - tail addr
//	$a3 - snake color
//	$t0 - direction (1/2/3/4)
//	thisSnake (1 or 2)
//
//   	returns 	$a1 - new head addr
//  		$a2 - new tail addr
updateSnake:
	//depending on direction ($t0): set offset_between_two_squares ($t8)
	la	$t1, backUp1
	sw	$ra, 0($t1)

	la	$ra, pro1
	li	$t1, 1
	beq	$t0, $t1, U_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, D_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, L_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, R_set

	//add head
	pro1:
	nop
	
	add	$t3, $zero, $a1 //old_head to $t3
	add	$a1, $a1, $t8 //new_head = head + offset
	add	$t5, $a1, $zero //backup new_head
	
	//if new_head == foodLocation: call drawFood() and don't remove tail
	la	$t2, foodLocation
	lw	$t1, 0($t2)
	beq	$a1, $t1, elongating
	nop

	//buffer edges collision detection: up and down
	li	$t2, LCD_FB_START
	slt	$t1, $a1, $t2
	bne	$t1, $zero, gameOver

	li	$t2, LCD_FB_END
	slt	$t1, $a1, $t2
	beq	$t1, $zero, gameOver

	//buffer edges collision detection: left and right
	li	$t1, 3
	beq	$t0, $t1, horizontalColDetection

	li	$t1, 4
	beq	$t0, $t1, horizontalColDetection
	
	collisionCont:

	//other snake or other part of this snake collision detection
	addi 	$t2, $a1, 3848
	lw	$t1, 0($t2)
	nop
	bne	$t1, $zero, gameOver
	la	$ra, pro2
	j	drawPoint

	//remove tail
	pro2:
	nop
	nop
	add	$a1, $a2, $zero //address = tail (drawPoint draws square at $a1)
	la	$a3, BLACK
	la	$ra, pro3
	j	drawPoint
	nop

	//update data
	pro3:
	nop
	add	$a1, $t5, $zero //restore head after drawPoint() call

	//set $t5 to lastTailDir
	la	$t2, thisSnake
	lw	$t1, 0($t2)
	li	$t3, 1
	bne	$t1, $t3, get_lastTailDir_s2
	nop
	j get_lastTailDir_s1

	chckChange:
	nop
	//if tail ($a2) is in directionChanges: $t5 = that direction
	j	checkChange
	nop

	updtTail:
	//set offset for new tail address
	la	$ra, theAdd
	li	$t1, 1
	beq	$t5, $t1, U_set
	addi	$t1, $t1, 1
	beq	$t5, $t1, D_set
	addi	$t1, $t1, 1
	beq	$t5, $t1, L_set
	addi	$t1, $t1, 1
	beq	$t5, $t1, R_set

	theAdd:
	nop
	add	$a2, $a2, $t8 //update tail

	//update lastTailDir
	la	$t2, thisSnake
	lw	$t1, 0($t2)
	li	$t3, 1
	bne	$t1, $t3, set_lastTailDir_s2_and_LED
	nop
	j set_lastTailDir_s1_and_LED


	//all is drawn, go back, somewhere to main_loop
	endUpdating:
	la	$t1, backUp1
	lw	$ra, 0($t1)
	jr $ra
	nop

get_lastTailDir_s1:
	la	$t2, s1_lastTailDir
	lw	$t5, 0($t2)
	nop
	j chckChange
	nop

get_lastTailDir_s2:
	la	$t2, s2_lastTailDir
	lw	$t5, 0($t2)
	nop
	j chckChange
	nop

set_lastTailDir_s1_and_LED:
	la	$t2, s1_lastTailDir
	sw	$t5, 0($t2)
	la	$ra, endUpdating
	li	$t1, LED_GREEN
	j	lightOn_One
	nop

set_lastTailDir_s2_and_LED:
	la	$t2, s2_lastTailDir
	sw	$t5, 0($t2)
	la	$ra, endUpdating
	li	$t1, LED_GREEN
	j	lightOn_Two
	nop

//calculates if snake passed left or right border of the screen
horizontalColDetection:
	li	$t6, LCD_FB_START
	li	$t4, -1
	mul	$t2, $t6, $t4
	add	$t1, $t3, $t2

	li	$t2, 7680
	div	$t1, $t2
	mflo	$t9

	mul	$t2, $t6, $t4
	add	$t1, $a1, $t2

	li	$t2, 7680
	div	$t1, $t2
	mflo	$t1
	mfhi	$t2

	bne	$t1, $t9, gameOver
	nop
	li	$t1, 0x3c0
	slt	$t4, $t2, $t1
	beq	$t4, $zero, gameOver
	nop
	j	collisionCont
	nop

//point where the game goes on terminal state
gameOver:	la	$t2, thisSnake
	lw	$t1, 0($t2)
	li	$t3, 1
	beq	$t1, $t3, gameOver_snake1
	nop
	j	gameOver_snake2
	nop

gameOver_snake1:
	la	$ra, gameoverRA
	li	$t1, LED_RED
	j	lightOn_One
	gameoverRA:
	nop
	break
	nop

gameOver_snake2:
	la	$ra, gameoverRA
	li	$t1, LED_RED
	j	lightOn_Two
	gameoverRA:
	nop
	break
	nop

//helper method for updateSnake() for snake behaviour when eating food
elongating:	
	la	$ra, elong1
	j	drawPoint
	nop

	elong1:
	//turn on the blue LED (1 or 2 depending on thisSnake variable)
	la	$ra, elong2
	li	$t1, LED_BLUE

	la	$t4, thisSnake
	lw	$t9, 0($t4)
	nop
	li	$t4, 1
	beq	$t9, $t4, lightOn_One
	nop
	j	lightOn_Two
	nop
	
	elong2:
	la	$ra, continue
	li	$t4, 1
	beq	$t9, $t4, drawFood
	nop

	la	$ra, afterUpdateSnake2	
	j drawFood	
	nop

//args: $t1 - color
lightOn_One:
	li	$t2, SPILED_REG_LED_RGB1
	lw	$t3, 0($t2)
	sw	$t1, 0($t2)
	jr	$ra
	nop

//args: $t1 - color
lightOn_Two:	
	li	$t2, SPILED_REG_LED_RGB2
	lw	$t3, 0($t2)
	sw	$t1, 0($t2)
	jr	$ra

//checkChange() checks if the tail is in directionChanges array
//if so, it sets tail direction ($t5) to the previously saved direction
checkChange:
	nop
	la	$t4, s1_arrOffset
	lw	$t3, 0($t4)

	la	$t2, thisSnake
	lw	$t1, 0($t2)
	li	$t4, 1
	beq	$t1, $t4, yesSnake1

	nop
	la	$t2, s2_arrOffset
	lw	$t3, 0($t2)
	nop

	yesSnake1:
	addi	$t2, $zero, 0
	nop

	la	$t6, s1_directionChanges
	beq	$t1, $t4, ccloop
	nop
	la	$t6, s2_directionChanges
	nop

	//looping through array
	//i = 0, i < arrOffset, i += 8
	ccloop:
	beq	$t2, $t3, updtTail
	nop
	lw	$t4, 0($t6)
	nop
	bne	$a2, $t4, nothing
	nop
	//Match, the tail is in the arr:
	addi	$t6, $t6, 4 //increment the idx of directionChanges arr
	nop	
	lw	$t7, 0($t6)

	//the method changes the direction saved in the array to zero after it gets used
	//so that it is not used again later

	//if dir in t7 is zero: continue looping
	nop
	beq	$t7, $zero, nevermind
	nop
	//if dir in t7 is not zero: store into $t5, set addr to zero, and jump out
	add	$t5, $zero, $t7
	sw	$zero, 0($t6)
	j	updtTail
	
	nevermind:
	addi	$t6, $t6, -4

	nothing:
	addi	$t2, $t2, 8
	addi	$t6, $t6, 8
	nop
	j ccloop
	nop

//drawSnake() - draws the whole snake; only used in the init
	//agrs:
	//$a0 - length
	//$a1 - address
	//$t0 - direction (1/2/3/4 -> up/down/left/right
	//colorVar - color of the snake
	//$ra
	//	returns:	
	//		new tail location in $a2
	//		new head location in $a1
drawSnake:
	li	$t5, 0
	add	$a2, $zero, $a1
	add	$t6, $0, $ra

	//depending on direction ($t0): set offset_between_each_square ($t8)
	la	$ra, bigLoop
	addi	$t1, $zero, 1
	beq	$t0, $t1, U_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, D_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, L_set
	addi	$t1, $t1, 1
	beq	$t0, $t1, R_set
	
	//for(i=0; i<len; i++):
	//	if not square 0: address += offset_between_each_square
	//	set color
	//	drawPoint(address, color)
	bigLoop:
	add	$ra, $zero, $t6
	beq	$t5, $a0, endDS //if all is drawn: end drawSnake
	nop
	beq	$t5, $zero, postOffset
	nop
	nop
	nop
	add	$a1, $a1, $t8 //address += offset_between_each_square
	postOffset:
	la	$t1, colorVar
	lw	$a3, 0($t1)
	la	$ra, bigLoop
	addi	$t5, $t5, 1
	//drawPoint(address-$a1, color-$a3)
	j	drawPoint
	nop
	endDS:	jr $ra
	nop

U_set:
	li	$t8, -7680
	jr	$ra
	nop

D_set:
	li	$t8, 7680
	jr	$ra
	nop

L_set:
	li	$t8, -16
	jr	$ra
	nop

R_set:
	li	$t8, 16
	jr	$ra
	nop

//drawFood() is used on init and after eating food for drawing the food
drawFood:	nop
	//t1 = lastX; t2 = lastY [indexes in the 2 kinda-random arrays]
	la	$t3, lastX
	lw	$t1, 0($t3)
	la	$t3, lastY
	lw	$t2, 0($t3)

	//t3 = kinda-randomXcoord; t4 = kinda-randomYcoord
	la	$t6, x_values
	add	$t6, $t6, $t1
	lw	$t3, 0($t6)
	nop
	la	$t6, y_values
	add	$t6, $t6, $t2
	lw	$t4, 0($t6)	

	//calcucate LCD adress for drawPoint() from coordinates, save to $t1
	li	$t5, 7680
	mul	$t1, $t4, $t5
	li	$t5, 16
	mul	$t2, $t3, $t5
	add	$t1, $t1, $t2
	la	$t3, LCD_FB_START
	add	$t1, $t1, $t3

	//check if that position is available, if not try the next one
	addi	$t2, $t1, 3848
	lw	$t3, 0($t2)
	bne	$t3, $zero, finish2
	
	//draw the point
	add	$t6, $zero, $ra
	la	$a3, WHITE
	add	$t5, $zero, $a1
	add	$a1, $zero, $t1
	la	$ra, finishFood
	nop
	j	drawPoint
	nop

	finishFood:
	//save the food location (now in $a1) to foodLocation variable
	la	$t1, foodLocation
	sw	$a1, 0($t1)	

	add	$a1, $zero, $t5
	add	$ra, $zero, $t6

	//update lastX, lastY array indexes

	//lastX+=4, if == 48: lastX = 0
	finish2: la	$t2, lastX
	lw	$t1, 0($t2)
	addi	$t1, $t1, 4
	addi	$t3, $zero, 48
	bne	$t1, $t3, checked1
	nop
	add	$t1, $zero, $zero
	nop
	//lastY+=4, if == 32: lastX = 0
	checked1:
	sw	$t1, 0($t2)
	nop
	la	$t2, lastY
	lw	$t1, 0($t2)
	addi	$t1, $t1, 4
	addi	$t3, $zero, 32
	bne	$t1, $t3, checked2
	nop
	add	$t1, $zero, $zero
	nop
	checked2:
	sw	$t1, 0($t2)
	jr	$ra

//not used, was planned to be used for drawing food using random system call
drawFood_:	nop
	break
	//backup $a0 and $a1 to $t1 and $t2
	add	$t1, $zero, $a0
	add	$t2, $zero, $a1
	//generate random coordinate x (0,60) - put it to $t3
	//a0 = buffer
	//a1 = buffer_len
	la	$a0, randomNumber
	li	$a1, 4
	li	$v0, 4353
	syscall
	nop
	lw	$t3, 0($a0)	
	nop
	nop
	add	$t3, $zero, $a0
	//generate random coordinate y (0,40) - put it to $t4
	li	$a1, 40
	li	$v0, 4053
	syscall
	add	$t4, $zero, $a0
	//restore original $a0 and $a1
	add	$a0, $zero, $t1
	add	$a1, $zero, $t2
	//calc adress for drawPoint() from random coordinates to $t1
	li	$t5, 7680
	mul	$t1, $t4, $t5
	li	$t5, 16
	mul	$t2, $t3, $t5
	add	$t1, $t1, $t2
	la	$t2, LCD_FB_START
	add	$t1, $t1, $t2
	//check if point in the middle of the square is black
		//if not j drawFood
	addi	$t2, $t1, 3848
	//draw the point and save its address
	//backup a1 to t5
	add	$t5, $zero, $a1
	add	$t6, $zero, $ra
	la	$a3, YELLOW
	la	$ra, finishFood
	j	drawPoint
	nop
	//jump to $ra
	_finishFood:
	add	$a1, $zero, $t5
	add	$ra, $zero, $t6
	jr	$ra

//drawPoint() is the method used for all drawing on the screen
//it draws one square at $a1 adress with $a3 color
drawPoint:	
	li	$t3, 0
	li	$t4, 8
	add	$t7, $a1, $zero

dpLoop1:	
	beq	$t3, $t4, dpDone1
	//outer loop
	li	$t1, 0
	li	$t2, 8
dpLoop2:
	beq	$t1, $t2, dpDone2
	//inner loop:
	//if x or y equals 0 or 7, skip storing the color - to create border
	li	$t9, BLACK
	nop
	sh	$t9, 0($a1)
	li	$t9, 0
	beq	$t1, $t9, skipHere
	nop
	beq	$t3, $t9, skipHere
	li	$t9, 7
	beq	$t1, $t9, skipHere
	nop
	beq	$t3, $t9, skipHere
	nop

	sh	$a3, 0($a1)
	nop

	skipHere:
	addi	$a1, $a1, 2 //move to next 2 pixels
	addi	$t1, $t1, 1
	j	dpLoop2
	nop
dpDone2:
	addi	$t3, $t3, 1
	addi	$a1, $a1, 944
	j	dpLoop1
	nop
dpDone1:	
	add	$a1, $zero, $t7
	nop
	jr	$ra
	nop
	
.end _start

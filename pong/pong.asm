pong game, v1.1 written by Hrvoje Cavrak, 12/2018

	ioh=iot i
	szm=sza sma-szf	

define swap
	rcl 9s
	rcl 9s
	terminate

define  point A, B
	law B
	add y
	sal 8s

	swap

	law A
	add x
	sal 8s

	dpy-i 300
	ioh
	terminate



/ 5 points
define  circle A, B
	point 0, 1
	point 0, 3
	
	point 4, 1
	point 4, 3

	point 1, 0
	point 1, 3
	
	point 1, 4
	point 3, 4

	terminate

define paddle X, Y				/ Draws paddles
	lac pdlwidth
	cma
	dac p1cnt
pdloop,
	lac Y
	add pdlwidth
	add p1cnt
	sal 8s

	swap

	lac X
	dpy-i 300
	ioh

	law 6
	add p1cnt
	dac p1cnt
	isp p1cnt

	jmp pdloop+R
	terminate

define line C, D				/ Central line which acts as the "net"
 	law 0	
	sub maxdown 
	sub maxdown 
	dac p1cnt

ploop2,
	lac p1cnt
	add maxdown 
	sal 9s

	swap
	law D
	dpy
	ioh
	
	law 70 
	add p1cnt
	dac p1cnt

	isp p1cnt
	jmp ploop2+R
	terminate



0/	opr
	opr
	opr
	opr
	jmp loop


500/
loop,   circle
	lac x
	add dx
	dac x

	jsp checkx

	lac y
	add dy
	dac y

	jsp checky

	paddle left, pdl1y
	paddle right, pdl2y

	jsp move

	line 0, 0
	
	jmp loop


define testkey K, N				/ Tests if key K was pressed and skips to N if it is not
	lac controls
	and K
	sza
	jmp N
	terminate

define padmove Y, A				/ Initiates moving of the pads
	lac Y
	dac pdly
	jsp A
	lac pdly
	dac Y
	terminate


move,
	dap mvret				/ Moves the paddles
	cli					/ Load current controller button state
	iot 11
	dio controls

move1,
	testkey rghtup, move2			/ Right UP
	padmove pdl1y, mvup

move2,
	testkey leftup, move3			/ Left UP
	padmove pdl2y, mvup

move3,						/ Right DOWN
	testkey rghtdown, move4
	padmove pdl1y, mvdown

move4,						/ Left DOWN
	testkey leftdown, mvret
	padmove pdl2y, mvdown

mvret,  jmp .


define flip A
	lac A
	cma
	dac A
	terminate


mvup,	dap upret				/ Move pad UP
	lac pdly
	sub limitup				/ Check if pad at top edge
	sma
	jmp upret				/ Do nothing if it is
	lac pdly
	add padoff
	dac pdly

	add random				/ Use pad coordinates as user provided randomness
	dac random

upret, jmp .

mvdown,	dap downret
	lac pdly
	add limitdown
	spa
	jmp downret
	lac pdly
	sub padoff
	dac pdly
	
	add random				/ Use pad coordinates as user provided randomness
	dac random
downret, jmp .



delay, dap dlyret
	lac dlytime
	dac dlycnt
dlyloop,
	isp dlycnt
	jmp dlyloop

dlyret, jmp .


restart,
	jsp delay
	idx iter				/ Count the number of restarts

	lac random				
	and dymask
	add one					/ Don't want it to be 0
	dac dy	

	cla
	dac x

	lac random
	and ymask
	sub maxdown
	dac y
	
	lac iter
	and one
	sza
	jmp rr
	
rl,
	law 2	
	cma
	dac dx

	add offscrn 
	dac x

	jmp ckret
rr,
	law 2
	dac dx	

	sub offscrn
	dac x
	
	jmp ckret



hitpaddle, dap ckret				/ Check for colision with paddle
	lac y
	sub pdly
	sub one
	spa					/ must be true: y - pdl1y > 0
	jmp restart				/ return if not

	sub pdlwidth
	sma					/ must be true: y - pdlwidth - pdl1y < 0
	jmp restart				/ return if not

	flip dx
	idx dirchng				/ Count number of paddle hits, increase speed subsequently

	lac dx
	spa
	jmp skipfast				/ Consider increasing dx only if positive

	law 3					/ if 3 - dirchng < 0 (every 3 hits from right paddle), increase speed 
	sub dirchng
	spa
	idx dx 
	spa
	dzm dirchng				/ Reset dirchng counter back to zero, everything starts from scratch
skipfast,

	lac pdly				/ get distance from center of paddle
	add pdlhalf
	sub y

	spa
	cma					/ take abs() of accumulator
	sar 4s					/ shift 3 bits right (divide by 8)
	add one					/ To prevent x-only movement, add 1 so it should never be zero

	/ Here, accumulator holds the absolute offset from the paddle center divided by 8

	lio dy					/ Load dy to IO not to destroy ACC contents
	spi					/ If dy is positive, subtract
	cma

	dac dy					/ Set new y bounce angle
	
ckret,  jmp .


checkx,
	dap cxret
	lac pdl1y				/ Load position of right paddle
	dac pdly
	lac x
	add maxright				/ AC = x + maxright, if x < -500, swap dx
	spa
	jsp hitpaddle

	lac pdl2y				/ Load position of left paddle
	dac pdly
	lac x
	sub maxright				/ AC = x - maxright, if x > 500, swap dx
	sma
	jsp hitpaddle
cxret, jmp .


checky,
	dap cyret
	lac y
	add maxdown				/ AC = y + maxdown, if y < -500, swap dy
	spa
	jmp cnext
	flip dy

cnext,
	lac y
	sub maxdown				/ AC = y - maxdown, if y > 500, swap dy
	sma
	jmp cyret
	flip dy
cyret, jmp .


////////////////////////////////////////////////////////////////////////////////////////////////

x,		000500
y,		000000

dx,		777775	
dy,		000003

iter,		000000

padoff, 	000004
random,		000001

pdly,		000000

pdl1y, 		000000
pdl2y, 		000000

p1cnt,	  	000000
controls, 	000000

left, 		400400
right, 		374000

pdlwidth, 	000150
pdlhalf,  	000064

one,		000001

maxright,  	000764
maxdown,   	000764

offscrn,	000500
dymask,		000003
ymask,		000777

limitup,	000562
limitdown,	000760

leftdown,   	000001
leftup,		000002

rghtdown,	040000
rghtup,	 	100000

dlytime,	770000
dlycnt,		000000
dirchng,	000000				/ Counts direction changes, used for increasing ball speed

	start 500

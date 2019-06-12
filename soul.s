@@@
@@@     SOUL - Sistema Operacional do Uoli
@@@     Autores:    Gabriela Pereira Neri                   RA168357
@@@                 Isabela Telles Furtado Doswaldo         RA170012
@@@

.org 0x0
.section .iv,"a"

_start:

interrupt_vector:
    b reset_handler

.org 0x08
    b syscall_handler     @ software interruption

.org 0x18
    b irq_handler

@ CODE SECTION @
.org 0x100
.text

    @ syscalls identifiers
	.set BACK_TO_IRQ_ID, 	  15
    .set READ_SONAR_ID,       16
    .set CALLBACK_ID,         17
    .set MOTOR_SPEED_ID,      18
    .set MOTORS_SPEED_ID,     19
    .set GET_TIME_ID,         20
    .set SET_TIME_ID,         21
    .set SET_ALARM_ID,        22

    @ contants for general purpose
    .set SONAR_MAX_ID,        15        @ maximum number for sonar id
    .set MAX_CALLBACKS,       8         @ maximum number of callbacks
    .set MAX_ALARMS,          8         @ maximum number of alarms

    @ GPT constants
    .set GPT_MEM_BASE,        0x53FA0000
    .set GPT_CR,              0x0
    .set GPT_PR,              0x04
    .set GPT_SR,              0x08
    .set GPT_OCR1,            0x10
    .set GPT_IR,     	      0x0C
    .set clock_src,           0x41

    @ TZIC constants
    .set TZIC_BASE,           0x0FFFC000
    .set TZIC_INTCTRL,        0x0
    .set TZIC_INTSEC1,        0x84
    .set TZIC_ENSET1,         0x104
    .set TZIC_PRIOMASK,       0xC
    .set TZIC_PRIORITY9,      0x424

    @ GPIO constants
    .set GPIO_BASE,			  0x53F84000
    .set GPIO_DR,			  0x0
    .set GPIO_GDIR,			  0x4
    .set GPIO_PSR,			  0x8
    .set TIME_SZ,			  0x10

	@ Mask values
    .set GDIR_MASK,           0b11111111111111000000000000111110        @ connection -> configuration
    .set SONAR_MUX,           0b11111111111111111111111111000011        @ extract / set sonar mux
    .set TRIGGER_0,           0b11111111111111111111111111111101        @ extract / set trigger
    .set TRIGGER_1,           0b00000000000000000000000000000010
    .set GET_FLAG,            0b00000000000000000000000000000001        @ extract / set flag
    .set MOTOR0_MASK,         0b11111110000000111111111111111111
    .set MOTOR1_MASK,         0b00000001111111111111111111111111
    .set SONAR_DATA,          0b11111111111111000000000000111111

    @ users code
    .set USER_CODE,                0x10
    .set SUPERVISOR_CODE,          0x13
    .set IRQ_CODE,                 0xD2
    .set SYSTEM_CODE,              0x1F

    .set TEXT,               0x77802000
    .set USER_STACK,         0x78802000
    .set SUPERVISOR_STACK,   0x7A802000
    .set IRQ_STACK,          0x7FFFFFFF

reset_handler:
    @ set counter to 0
    ldr r2, =SYSTEM_TIME
    mov r0, #0
    str r0, [r2]

    @ set interrupt table base address on coprocessor 15.
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0


set_stacks:
    msr CPSR_c, #SUPERVISOR_CODE
    ldr sp, =SUPERVISOR_STACK

    msr CPSR_c, #IRQ_CODE
    ldr sp, =IRQ_STACK

    msr CPSR_c, #USER_CODE
    ldr sp, =USER_STACK

    msr CPSR_c, #SUPERVISOR_CODE

@ set GPT registers address
set_gpt:
    @ load to r1 the first memory position of gpt registers
    ldr r1, =GPT_MEM_BASE

    @ set default values given
    ldr r0, =clock_src                       @ load to r1 the given clock_src address
    str r0, [r1, #GPT_CR]                    @ store the value of clock_src on GPT_CR to enable it

    mov r0, #0                               @ zero for the prescaler
    str r0, [r1, #GPT_PR]

    ldr r0, =TIME_SZ                         @ value for the counter 100 (dec) to compare
    str r0, [r1, #GPT_OCR1]

    mov r0, #0x1                             @ enabling the OCR1 interruption
    str r0, [r1, #GPT_IR]

@ set TZIC registers address
set_tzic:
    ldr	r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov	r0, #1
    str	r0, [r1, #TZIC_INTCTRL]

    @instrucao msr - habilita interrupcoes
    msr    CPSR_c, #SUPERVISOR_CODE             @ SUPERVISOR mode, IRQ/FIQ enabled

@ set GPIO registers address
set_gpio:
	@ load to r1 the first memory position of gpio registers
	ldr r1, =GPIO_BASE

	@ set GDIR according to the configuration of the pins
	ldr r0, =GDIR_MASK
	str r0, [r1, #GPIO_GDIR]

@ change to user mode
@ and load loco code
@ starting uoli
as_user:
    msr CPSR_c, #USER_CODE
    ldr r0, =TEXT
    bx r0

irq_handler:
    stmfd sp!, {r0-r12, lr}

    @ save spsr for preventing user changes to lose last mode saved
    mrs r11, SPSR
    stmfd sp!, {r11}

	ldr r8, =INTERRUPTION_CASE
	str r9, [r9]

    @ first, set GPT_SR to 1 to clean OF1 flag
    mov r1, #1
    ldr r0, =GPT_MEM_BASE
    str r1, [r0, #GPT_SR]

    @ increment system time by 1
    ldr r0, =SYSTEM_TIME
	ldr r1, [r0]
	add r1, r1, #1
	str r1, [r0]

	cmp r9, #1
	beq irq_return

check_alarms:
	add r9, r9, #1
	str r9, [r8]
	msr CPSR_c, #IRQ_CODE

    ldr r7, =NUM_ALARMS
    ldr r1, [r7]                @ get the number of active alarms

    cmp r1, #0
    beq check_callbacks         @ if there's no alarm to check

    mov r4, #0                  @ counter = 0

    ldr r2, =F_ALARMS_ARRAY
    ldr r3, =ST_ALARMS_ARRAY

    for_check:
        ldr r0, =SYSTEM_TIME
        ldr r0, [r0]

        ldr r5, [r3, r4, lsl #2]    @ get system time of this alarm

        cmp r0, r5
        bge alarm_rings             @ if system time >= system time of this alarm

        add r4, r4, #1              @ increment r4
        cmp r4, r1
        blt for_check               @ if counter =< number of alarms

    b check_callbacks

    alarm_rings:
        ldr r5, [r2, r4, lsl #2]    @ get function pointer of this alarm

		stmfd sp!, {r0-r12, lr}
		msr CPSR_c, #USER_CODE
        blx r5						@ execute function without losing the values in registers
		mov r7, #BACK_TO_IRQ_ID
		svc 0x0
		msr CPSR_c, #IRQ_CODE
		ldmfd sp!, {r0-r12, lr}

        mov r6, r4

        @ rearrange the alarms in the array in order to remove the current alarm
        rearrange_alarms:
            add r6, r6, #1
            cmp r1, r6
            beq remove_alarm            @ if the alarm that must be rearranged is
                                        @ in the last position of the array

            ldr r5, [r3, r6, lsl #2]    @ get system time of the next alarm
            str r5, [r3, r4, lsl #2]    @ substitute system time of the current
                                        @ alarm by the next ones

            ldr r5, [r2, r6, lsl #2]    @ get function pointer of the next alarm
            str r5, [r2, r4, lsl #2]    @ substitute function pointer of the
                                        @ current alarm by the next ones
            b rearrange_alarms

    remove_alarm:
        sub r1, r1, #1
        str r1, [r7]                @ decrement number of active alarms

check_callbacks:
    ldr r0, =NUM_CALLBACKS
    ldr r0, [r0]

    cmp r0, #0
    beq irq_return

    ldr r1, =F_CALLBACKS_ARRAY          @ load functions array base memory
    ldr r2, =D_CALLBACKS_ARRAY          @ load distance array base memory
    ldr r3, =S_CALLBACKS_ARRAY          @ load sonars array base memory

    mov r4, #0                  @ loop counter

    while_callback:
        mov r5, #4
        mul r6, r4, r5          @ multiply byte * index
        add r1, r1, r6          @ pointer = 4 bytes
        add r2, r2, r6          @ int = 4 bytes
        add r3, r3, r4          @ char = 1 byte = counter

        ldr r8, [r2]            @ load distance
        ldrb r9, [r3]           @ load sonar id
        ldr r10, [r1]           @ load pointer to function

        stmfd sp!, {r0-r12, lr}

        msr CPSR_c, #USER_CODE           @ system mode to access user stack

        stmfd sp!, {r9}                 @ parameter to read_sonar: sonar_id
        mov r7, #READ_SONAR_ID
        svc 0x0                 @ syscall read sonar
        add sp, sp, #4

        cmp r0, r8              @ compare distance read from sonar with distance threshold
        bhi continue_loop       @ sonardistance > threshold

        blx r10                 @ sonardistance <= threshold, calls function

    continue_loop:
        mov r7, #BACK_TO_IRQ_ID
        svc 0x0
        msr CPSR_c, #IRQ_CODE
        ldmfd sp!, {r0-r12, lr}

        add r4, r4, #1          @ increments counter

        ldr r0, =NUM_CALLBACKS  @ restores the r0 value with callbacks size
        ldr r0, [r0]

        cmp r4, r0              @ counter < num_callbacks ?
        blo while_callback      @ continue loop

irq_return:
	ldr r0, =INTERRUPTION_CASE
	mov r1, #0
	str r1, [r0]

    @ retrives last saved user mode
    ldmfd sp!, {r11}
    msr SPSR, r11

    ldmfd sp!, {r0-r12, lr}

    sub lr, lr, #4          @ subtract 4 before return

    @ return
	movs pc, lr

@ handle the syscalls
syscall_handler:
    @ calling from irq_handler may cause to lose the spsr value that would help to
    @ get back to user code
    stmfd sp!, {r11}
    mrs r11, SPSR                   @ save SPSR before going to system

    msr CPSR_c, #SUPERVISOR_CODE    @ change to back to SUPERVISOR mode

    msr SPSR, r11                   @ retrieve previous SPSR
    ldmfd sp!, {r11}

	cmp r7, #BACK_TO_IRQ_ID
	beq back_to_irq

    cmp r7, #READ_SONAR_ID
    beq read_sonar

    cmp r7, #CALLBACK_ID
    beq register_proximity_callback

    cmp r7, #MOTOR_SPEED_ID
    beq set_motor_speed

    cmp r7, #MOTORS_SPEED_ID
    beq set_motors_speed

    cmp r7, #GET_TIME_ID
    beq get_time

    cmp r7, #SET_TIME_ID
    beq set_time

    cmp r7, #SET_ALARM_ID
    beq set_alarm

    @ back to user mode
    movs pc, lr

@ syscalls and their behaviors

back_to_irq:
	mov pc, lr

@ Parametros
@       P0: Identificador do sonar (valores válidos: 0 a 15).
@       R0: Valor obtido na leitura dos sonares;
@           -1 caso o identificador do sonar seja inválido.
read_sonar:

    stmfd sp!, {lr}                 @ saves the lr value because branching on the code

    @ calling read sonar from irq_handler may cause to lose the spsr value
    @ after changing to system and after to supervisor
    stmfd sp!, {r11}
    mrs r11, SPSR                   @ save SPSR before going to system

    msr CPSR_c, #SYSTEM_CODE        @ change to SYSTEM mode to fetch values from USER stack
    ldr r0, [sp]                    @ read from stack the first parameter to r0

    msr CPSR_c, #SUPERVISOR_CODE    @ change to back to SUPERVISOR mode

    msr SPSR, r11                      @ retrieve previous SPSR
    ldmfd sp!, {r11}

    cmp r0, #SONAR_MAX_ID
    bhi return_one_negative         @ invalid sonar id

    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]                    @ loads the gpio_dr value

    and r2, #SONAR_MUX          @ extract the SONAR_MUX value
    lsl r0, r0, #2                 @ shift sonar id by 2 to fit the gpio_dr mask
    orr r2, r0                  @ override with sonar id provided
    str r2, [r1, #GPIO_DR]

    @ set trigger to 0
    and r2, #TRIGGER_0
    str r2, [r1, #GPIO_DR]

    stmfd sp!, {r0-r1}          @ put on stack caller-save registers before calling delay function
    mov  r0, #200                 @ time to wait as parameter
    bl delay                    @ delay the execution
    ldmfd sp!, {r0-r1}          @ pop the caller-save registers

    @ set trigger to 1
    orr r2, #TRIGGER_1
    str r2, [r1, #GPIO_DR]

    stmfd sp!, {r0-r1}          @ put on stack caller-save registers before calling delay function
    mov  r0, #200                 @ time to wait as parameter
    bl delay                    @ delay the execution
    ldmfd sp!, {r0-r1}          @ pop the caller-save registers

    @ set trigger to 0

    and r2, #TRIGGER_0
    str r2, [r1, #GPIO_DR]

wait_flag:
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]
    and r2, #GET_FLAG           @ extracts flag value
    cmp r2, #1
    beq flag_ready              @ flag is ready; go to next steps

    @ flag is not ready; delay
    stmfd sp!, {r0-r1}          @ put on stack caller-save registers before calling delay function
    mov  r0, #100                @ time to wait as parameter
    bl delay                    @ delay the execution
    ldmfd sp!, {r0-r1}          @ pop the caller-save registers

    b wait_flag                 @ go to begining while waiting the flag to be setted

flag_ready:
    ldr r2, [r1, #GPIO_DR]
    ldr r3, =SONAR_DATA         @ load sonar data address
    ldr r3, [r3]
    and r2, r3
    mov r0, r2, lsr #6          @ moves the sonar_data to r0

    @ recover lr
    ldmfd sp!, {lr}
    b return_ok

@ Parametros
@       P0: Identificador do sonar (valores válidos: 0 a 15).
@       P1: Limiar de distância (veja descrição em api_robot2.h).
@       P2: ponteiro para função a ser chamada na ocorrência do alarme.
@       R0: -1 caso o número de callbacks máximo ativo no sistema seja maior do que MAX_CALLBACKS.
@           -2 caso o identificador do sonar seja inválido.
@           Caso contrário retorna 0.
register_proximity_callback:
    msr CPSR_c, #SYSTEM_CODE        @ change to SYSTEM mode to fetch values from USER stack
    ldr r0, [sp]                    @ get from user stack the parameters to r0 r1 r2
    ldr r1, [sp, #4]
    ldr r2, [sp, #8]

    msr CPSR_c, #SUPERVISOR_CODE    @ change to back to SUPERVISOR mode

    ldr r8, =NUM_CALLBACKS
    ldr r3, [r8]                    @ loads num callbacks value
    cmp r3, #MAX_CALLBACKS
    bcs return_one_negative         @ reached max callbacks allowed return -1

    @ldr r4, =SONAR_MAX_ID
    @ldr r4, [r4]
    cmp r0, #SONAR_MAX_ID
    bhi return_two_negative         @   invalid sonar, return -2

    @ add the new alarm to the array
    ldr r4, =F_CALLBACKS_ARRAY
    ldr r5, =D_CALLBACKS_ARRAY
    ldr r6, =S_CALLBACKS_ARRAY

    str r2, [r4, r3, lsl #2]
    str r1, [r5, r3, lsl #2]
    strb r0, [r6, r3]

    @ update number of callbacks
    add r3, r3, #1
    str r3, [r8]

    mov r0, #0
    b return_ok

@ Parametros
@       P0: Identificador do motor (valores válidos 0 ou 1).
@       P1: Velocidade.
@       R0: -1 caso o identificador do motor seja inválido,
@           -2 caso a velocidade seja inválida,
@           0 caso Ok.
set_motor_speed:

    @ change to system to fetch parameters from user stack
    msr CPSR_c, #SYSTEM_CODE
    ldr r0, [sp]
    ldr r1, [sp, #4]

    msr CPSR_c, #SUPERVISOR_CODE
    ldr r2, =GPIO_BASE
    ldr r3, [r2, #GPIO_DR]

    cmp r0, #0
    beq set_motor0_speed

    cmp r0, #1
    beq set_motor1_speed

    b return_one_negative

    set_motor0_speed:
        mov r1, r1, lsl #19
        and r3, #MOTOR0_MASK
        b set_speed

    set_motor1_speed:
        mov r1, r1, lsl #26
        and r3, #MOTOR1_MASK
        b set_speed

    set_speed:
        orr r3, r1
        str r3, [r2, #GPIO_DR]

    mov r0, #0
    b return_ok

@ Parametros
@       P0: Velocidade para o motor 0.
@       P1: Velocidade para o motor 1.
@       R0: -1 caso a velocidade para o motor 0 seja inválida,
@           -2 caso a velocidade para o motor 1 seja inválida,
@           0 caso Ok.
set_motors_speed:
    msr CPSR_c, #SYSTEM_CODE
    ldr r0, [sp]
    ldr r1, [sp, #4]

    msr CPSR_c, #SUPERVISOR_CODE
    ldr r2, =GPIO_BASE
    ldr r3, [r2, #GPIO_DR]

    @ set motor0 speed
    mov r0, r0, lsl #19
    and r3, #MOTOR0_MASK
    orr r3, r0
    str r3, [r2, #GPIO_DR]

    @ set motor1 speed
    mov r1, r1, lsl #26
    and r3, #MOTOR1_MASK
    orr r3, r1
    str r3, [r2, #GPIO_DR]

    mov r0, #0
    b return_ok

@ Parametros
@       R0: retorna o tempo do sistema.
get_time:
	ldr r1, =SYSTEM_TIME
	ldr r0, [r1]

    b return_ok

@ Parametros
@       P0: tempo do sistema.
set_time:
    msr CPSR_c, #SYSTEM_CODE
    ldr r0, [sp]

    msr CPSR_c, #SUPERVISOR_CODE
	ldr r1, =SYSTEM_TIME
	str r0, [r1]

    b return_ok

@ Parametros
@   P0: ponteiro para função a ser chamada na ocorrência do alarme.
@   P1: tempo do sistema.
@   R0: -1 caso o número de alarmes máximo ativo no sistema seja maior do que
@       MAX_ALARMS.
@       -2 caso o tempo seja menor do que o tempo atual do sistema.
@       Caso contrário retorna 0.
set_alarm:
    msr CPSR_c, #SYSTEM_CODE
    ldr r0, [sp]
    ldr r1, [sp, #4]

    msr CPSR_c, #SUPERVISOR_CODE
    ldr r2, =NUM_ALARMS                  @ r2 <= number of alarms
    ldr r3, [r2]

    cmp r3, #MAX_ALARMS                  @ if r3 > MAX_ALARMS
    bhi return_one_negative

    ldr r4, =SYSTEM_TIME
    ldr r4, [r4]

    cmp r1, r4                           @ if r1 < SYSTEM_TIME
    blo return_two_negative

    @ add pointer function of the new alarm to the array
    ldr r4, =F_ALARMS_ARRAY
    str r0, [r4, r3, lsl #2]

    @ add system time of the new alarm to the array
    ldr r4, =ST_ALARMS_ARRAY
    str r1, [r4, r3, lsl #2]

    @ update number of alarms
    add r3, r3, #1
    str r3, [r2]

    b return_ok

@ time to wait as parameter on r0
delay:
    mov r1, r0
    mov r0, #0                  @ counter

    loop:
      add r0, r0, #1
      cmp r0, r1
      bls loop

    mov pc, lr                  @ returns the execution

@ RETURNS
@ return values defined on each function
return_ok:
    movs pc, lr

@ return -1 on r0 and returns to user mode
return_one_negative:
    mov r0, #-1
    movs pc, lr

@ return -2 on r0 and returns to user mode
return_two_negative:
    mov r0, #-2
    movs pc, lr

@ DATA SECTION @
.data
INTERRUPTION_CASE:
	.word 0

SYSTEM_TIME:
    .word 0         @ initializing the counter with 0

@ ALARM ARRAYS
@ pointers of functions that will be called by the alarms (4 bytes)
F_ALARMS_ARRAY:
    .skip MAX_ALARMS * 4

@ system times of the alarms (4 bytes)
ST_ALARMS_ARRAY:
    .skip MAX_ALARMS * 4

@ number of active alarms in the array
NUM_ALARMS:
    .word 0

@ CALLBACK ARRAYS
@ pointers of functions that will be called as callbacks (4 bytes)
F_CALLBACKS_ARRAY:
    .skip MAX_CALLBACKS * 4

@ distances limiars related to each callback (4 bytes)
D_CALLBACKS_ARRAY:
    .skip MAX_CALLBACKS * 4

@ sonar related to each callback (1 byte)
S_CALLBACKS_ARRAY:
    .skip MAX_CALLBACKS * 1

@ number of active callbacks in the array
NUM_CALLBACKS:
    .word 0

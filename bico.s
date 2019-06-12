@ global symbols
    .global read_sonar, read_sonars
    .global register_proximity_callback
    .global set_motor_speed, set_motors_speed
    .global get_time, set_time
    .global add_alarm

    .align 4

@ reads one of the sonars
read_sonar:
    @ save the callee-save registers,
    @ the parameter to the syscall,
    @ and the return address
    stmfd sp!, {r0, lr}

    mov r7, #16
    svc 0x0

    @ restore the registers and return
    ldmfd sp!, {r0, pc}

@ register a function to be called whenever the robot gets close to an object
register_proximity_callback:
    @ save the callee-save registers
    @ and the return address
    stmfd sp!, {r0-r2, lr}

    mov r7, #17
    svc 0x0

    @ restore the registers and return
    ldmfd sp!, {r0-r2, pc}

@ reads all sonars at once
read_sonars:
    .set TOTAL_SONARS, 15

@ sets motor speed
set_motor_speed:
    stmfd sp!, {lr}
    ldrb r1, [r0, #1]            @ load the motor speed in r1
    ldrb r0, [r0]                @ load the motor id in r0

    stmfd sp!, {r0-r1}           @ pass parameters to the syscall through stack
    mov r7, #18
    svc 0x0
    add sp, sp, #8               @ clean the stack

    ldmfd sp!, {pc}

@ sets both motors speed
set_motors_speed:
    stmfd sp!, {lr}
    ldrb r2, [r1, #1]            @ load the motor speed in r1
    ldrb r3, [r0, #1]

    stmfd sp!, {r2-r3, lr}

    mov r7, #19
    svc 0x0
    add sp, sp, #8

    @ restore the registers and return
    ldmfd sp!, {pc}

add_alarm:
    stmfd sp!, {lr}

    stmfd sp!, {r0-r1}           @ pass parameters to the syscall through stack
    mov r7, #22
    svc 0x0
    add sp, sp, #8               @ clean the stack

    ldmfd sp!, {pc}

@ reads the system time
get_time:
    @ save the callee-save registers
    @ and the return address
    stmfd sp!, {lr}

	mov r1, r0
	stmfd sp!, {r1}
    mov r7, #20
    svc 0x0
	ldmfd sp!, {r1}
	str r0, [r1]

    @ restore the registers and return
    ldmfd sp!, {pc}

@ sets the system time
set_time:
    stmfd sp!, {lr}

    stmfd sp!, {r0}              @ pass parameters to the syscall through stack
    mov r7, #21
    svc 0x0
    add sp, sp, #4

    ldmfd sp!, {pc}

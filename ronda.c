#include "bico.h" /* Robot control API */

#define LEFT_SONAR	3
#define RIGHT_SONAR	4
#define MIN_DIST	1200
#define WALK_SPEED 	10
#define TIME_UNITY	5000

void delay();
void walk();
void turn_right();
void spin();

int counter = 1;

/* main function */
void _start() {

	int current_time = 0;

	set_time(current_time);

	/* callbacks for detecting collision */
	register_proximity_callback(LEFT_SONAR, MIN_DIST, &turn_right);
	register_proximity_callback(RIGHT_SONAR, MIN_DIST, &turn_right);

	walk();

	get_time(&current_time);
	add_alarm(&turn_right, current_time + TIME_UNITY);

	while(1); /* keeps the execution */
}

/* set the same speed for both motors */
void walk() {
	motor_cfg_t left, right;

	left.speed = WALK_SPEED;
	right.speed = WALK_SPEED;
	set_motors_speed(&left, &right);
}

void turn_right() {
	motor_cfg_t left, right;
	/* only left motor with speed to turn right */
	left.speed = 25;
	right.speed = 0;
	set_motors_speed(&left, &right);

	delay();

    walk();
}

/* set to zero the left motor speed
so uoli can turn right ~90 degrees */
void spin() {
	motor_cfg_t left, right;
	int current_time;

	/* only left motor with speed to turn right */
	left.speed = 36;
	right.speed = 0;
	set_motors_speed(&left, &right);

    delay();

    walk();

	get_time(&current_time);
	add_alarm(&spin, current_time + (TIME_UNITY * counter));
	counter++;

	/* if 50th round, restart */
	if (counter > 50){
		counter = 1;
	}
}

/* spend some time doing nothing */
void delay() {
	int i, top = TIME_UNITY * counter;

	for(i = 0; i < top; i++);
}

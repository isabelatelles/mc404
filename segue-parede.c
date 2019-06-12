#include "bico.h" /* Robot control API */

#define LEFT_SONAR	3
#define RIGHT_SONAR	4
#define MIN_DIST	1000

void walk();
void busca_parede();
void stop();
void turn_right();
void init();

motor_cfg_t left, right;
/* main function */
void _start(void){
	walk();
	busca_parede();


}

void walk() {
	left.speed = 10;
	right.speed = 10;
	set_motors_speed(&left, &right);
}

void stop() {
	left.speed = 0;
	right.speed = 0;
	set_motors_speed(&left, &right);
}

void turn_right() {
	left.speed = 4;
	right.speed = 0;
	set_motors_speed(&left, &right);
}

void busca_parede(){

	int distance = 0;
	int sonar3;
	int sonar4;
	int is_near_wall = 0;

	do {
		sonar3 = read_sonar(LEFT_SONAR);
		sonar4 = read_sonar(RIGHT_SONAR);

		if (sonar3 > sonar4) {
			distance = sonar3;
		} else {
			distance = sonar4;
		}

		if (distance < MIN_DIST) {
			is_near_wall = 1;
		}

	} while(!is_near_wall);

	stop();
	while(1);
}

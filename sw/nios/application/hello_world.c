/*
 * "Hello World" example.
 *
 * This example prints 'Hello from Nios II' to the STDOUT stream. It runs on
 * the Nios II 'standard', 'full_featured', 'fast', and 'low_cost' example
 * designs. It runs with or without the MicroC/OS-II RTOS and requires a STDOUT
 * device in your system's hardware.
 * The memory footprint of this hosted application is ~69 kbytes by default
 * using the standard reference design.
 *
 * For a reduced footprint version of this template, and an explanation of how
 * to reduce the memory footprint for a given application, see the
 * "small_hello_world" template.
 *
 */

#include <stdio.h>
#include <stdint.h>
#include <sys/alt_irq.h>
#include "system.h"
#include "io.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator_regs.h"

#define FRAME0 0x00000000
#define FRAME1 0x00020000
#define FRAME_SIZE 76800
#define CAMERA_CONTROLLER_FRAME0 0
#define CAMERA_CONTROLLER_FRAME1 1
#define CAMERA_CONTROLLER_START 2
#define MASK_RED 0xf800
#define MASK_GREEN 0x07e0
#define MASK_BLUE 0x001f
#define OFF_RED 11
#define OFF_GREEN 5
#define OFF_BLUE 0

int currentFrame;
//cmos_sensor_output_generator_dev cmos_sensor_output_generator;

//void init_sensor(){
//	cmos_sensor_output_generator_dev cmos_sensor_output_generator = cmos_sensor_output_generator_inst(CMOS_SENSOR_OUTPUT_GENERATOR_0_BASE,
//	                                                    CMOS_SENSOR_OUTPUT_GENERATOR_0_PIX_DEPTH,
//														CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_WIDTH,
//	                                                    CMOS_SENSOR_OUTPUT_GENERATOR_0_MAX_HEIGHT);
//	cmos_sensor_output_generator_init(&cmos_sensor_output_generator);
//    cmos_sensor_output_generator_stop(&cmos_sensor_output_generator);
//    cmos_sensor_output_generator_configure(&cmos_sensor_output_generator,
//	                           240,
//	                           320,
//	                           CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_FRAME_BLANK_MIN,
//	                           CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_LINE_BLANK_MIN,
//	                           CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_LINE_BLANK_MIN,
//	                           CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_FRAME_BLANK_MIN);
//    cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
//}



int load_image(uint32_t addr){
	//char* filename = "/mnt/host/image.ppm";
	char* filename = "/mnt/host/image.ppm";
	FILE *foutput = fopen(filename, "w");
	if (!foutput) {
		printf("Error: could not open \"%s\" for writing\n", filename);
		return 1;
	}
	//write: rgb byte format
	fprintf(foutput, "P3\n");
	//write: dimensions
	fprintf(foutput, "320 240\n");
	//write: largest possible value (6 bits)
	fprintf(foutput, "63\n");
	for(int i = 0; i < FRAME_SIZE; i++){
		uint16_t pixel = IORD_16DIRECT(addr, i);
		//REAL CAMERA INTERFACE
		/*
		int red = (int)((pixel & MASK_RED) >> OFF_RED);
		int green = (int)((pixel & MASK_GREEN) >> OFF_GREEN);
		int blue = (int)((pixel & MASK_BLUE) >> OFF_BLUE);
		fprintf(foutput, "%d %d %d\n", red, green, blue);
		*/
		//MOCK CAMERA INTERFACE
		//one pixel value is written per fifo entry, use that value for a gray-scale pixel
		fprintf(foutput, "%d %d %d\n", pixel, pixel, pixel);
	}
	fclose(foutput);
	return 0;
}
static void CameraControllerISR(void *unused){
	uint32_t addr;
	if(currentFrame == 0){
		addr = FRAME0;
	}
	else{
		addr = FRAME1;
	}
	load_image(addr);
	currentFrame = (currentFrame + 1)%2;
	//restart Camera Controller
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_START, 1);
	//cmos_sensor_output_generator_start(&cmos_sensor_output_generator);
}
int main()
{
	currentFrame = 0;
	//set up interrupt handlers
	int fail = alt_ic_isr_register(0,
			0, CameraControllerISR, NULL, 0x0);
	if(fail)
		return 1;
	alt_ic_irq_enable(0,0);

	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_FRAME0, FRAME0);
	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_FRAME1, FRAME1);
	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_START, 1);
	//init_sensor();
	printf("Hello from Nios II!\n");
	return 0;
}

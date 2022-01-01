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
#include <stdbool.h>
#include <unistd.h>

#include "system.h"
#include "io.h"
#include "i2c/i2c.h"

#include <stdint.h>
#include <sys/alt_irq.h>
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
#define CLK_FREQ 50000000 //50MHz

// Camera configuration
#define COLUMNS 640
#define ROWS 480
#define ROW_SIZE_ADDR 3
#define COL_SIZE_ADDR 4
#define DIV_CLK_ADDR 10
#define ROW_MODE_ADDR 34
#define COL_MODE_ADDR 35

#define I2C_FREQ              (50000000) /* Clock frequency driving the i2c core: 50 MHz in this example (ADAPT TO YOUR DESIGN) */
#define TRDB_D5M_I2C_ADDRESS  (0xba)

#define TRDB_D5M_0_I2C_0_BASE (0x0000)   /* i2c base address from system.h (ADAPT TO YOUR DESIGN) */

int currentFrame;
/**
 * Taken from demo_i2c.c
 */
bool trdb_d5m_write(i2c_dev *i2c, uint8_t register_offset, uint16_t data) {
    uint8_t byte_data[2] = {(data >> 8) & 0xff, data & 0xff};

    int success = i2c_write_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        return true;
    }
}

bool trdb_d5m_read(i2c_dev *i2c, uint8_t register_offset, uint16_t *data) {
    uint8_t byte_data[2] = {0, 0};

    int success = i2c_read_array(i2c, TRDB_D5M_I2C_ADDRESS, register_offset, byte_data, sizeof(byte_data));

    if (success != I2C_SUCCESS) {
        return false;
    } else {
        *data = ((uint16_t) byte_data[0] << 8) + byte_data[1];
        return true;
    }
}


void init_TRDB_D5M() {
	i2c_dev i2c = I2C_INST(I2C_0);
	i2c_init(&i2c, CLK_FREQ);

	// Set column and row size
	trdb_d5m_write(&i2c, ROW_SIZE_ADDR, 4*ROWS-1);
	trdb_d5m_write(&i2c, COL_SIZE_ADDR, 4*COLUMNS-1);

	// Divide pixclk by 8
	trdb_d5m_write(&i2c, DIV_CLK_ADDR, 0x0004);

	// Set skip and binning
	trdb_d5m_write(&i2c, ROW_MODE_ADDR, 0x0033); // row skip 4x, row bin 4x
	trdb_d5m_write(&i2c, COL_MODE_ADDR, 0x0033); // col skip 4x, col bin 4x
}

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
		int red = (int)((pixel & MASK_RED) >> OFF_RED);
		int green = (int)((pixel & MASK_GREEN) >> OFF_GREEN);
		int blue = (int)((pixel & MASK_BLUE) >> OFF_BLUE);
		fprintf(foutput, "%d %d %d\n", red, green, blue);

		//MOCK CAMERA INTERFACE
		//one pixel value is written per fifo entry, use that value for a gray-scale pixel
		//fprintf(foutput, "%d %d %d\n", pixel, pixel, pixel);
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
//	currentFrame = 0;
//	//set up interrupt handlers
//	int fail = alt_ic_isr_register(0,
//			0, CameraControllerISR, NULL, 0x0);
//	if(fail)
//		return 1;
//	alt_ic_irq_enable(0,0);

	//init_TRDB_D5M();
	//usleep(1000*1000);


	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_FRAME0, FRAME0);
	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_FRAME1, FRAME1);
	//IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, CAMERA_CONTROLLER_START, 1);
	//init_sensor();
	printf("Hello from Nios II!\n");




	return 0;
}

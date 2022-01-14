#include <stdio.h>
#include <stdbool.h>
#include <unistd.h>

#include "system.h"
#include "io.h"
#include "i2c/i2c.h"
#include "sys/alt_irq.h"
#include "altera_avalon_pio_regs.h"
#include "lcd.h"

#include <stdint.h>
#include "cmos_sensor_output_generator/cmos_sensor_output_generator.h"
#include "cmos_sensor_output_generator/cmos_sensor_output_generator_regs.h"

#define FRAME0 0x00000000
#define FRAME1 0x00040000
#define FRAME_SIZE 76800

//LCD CONTROLLER
#define LCD_FRONT_IMAGE_OFF 0
#define LCD_BACK_IMAGE_OFF 4
#define LCD_START_OFF 8
#define LCD_CMD_DATA_OFF 12
#define LCD_IS_WRITING_CMD_OFF 16
#define LCD_IRQ_PENDING_OFF 20

//CAMERA CONTROLLER
#define CAMERA_CONTROLLER_FRAME0 0
#define CAMERA_CONTROLLER_FRAME1 1
#define CAMERA_CONTROLLER_START 2
#define CAMERA_CONTROLLER_RE_IRQ 3
#define MASK_RED 0xf800
#define MASK_GREEN 0x07e0
#define MASK_BLUE 0x001f
#define OFF_RED 11
#define OFF_GREEN 5
#define OFF_BLUE 0
#define CLK_FREQ 50000000 //50MHz

// Camera configuration
#define COLUMNS_CAM 640
#define ROWS_CAM 480
#define ROW_SIZE_ADDR 3
#define COL_SIZE_ADDR 4
#define DIV_CLK_ADDR 10
#define ROW_MODE_ADDR 34
#define COL_MODE_ADDR 35

#define I2C_FREQ              (50000000) /* Clock frequency driving the i2c core: 50 MHz in this example (ADAPT TO YOUR DESIGN) */
#define TRDB_D5M_I2C_ADDRESS  (0xba)

int currentFrame;
int iter;
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
	trdb_d5m_write(&i2c, ROW_SIZE_ADDR, 4*ROWS_CAM-1);
	trdb_d5m_write(&i2c, COL_SIZE_ADDR, 4*COLUMNS_CAM-1);

	// Divide pixclk by 1 -- xclkin is already divided by 8
	trdb_d5m_write(&i2c, DIV_CLK_ADDR, 0x0004);

	// Set skip and binning
	trdb_d5m_write(&i2c, ROW_MODE_ADDR, 0x0033); // row skip 4x, row bin 4x
	trdb_d5m_write(&i2c, COL_MODE_ADDR, 0x0033); // col skip 4x, col bin 4x
}

static void CameraControllerISR(void *unused){
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, 4*CAMERA_CONTROLLER_RE_IRQ, 1);
	//restart Camera Controller
	//load_image();
	lcd_camera_ready();
}
static void LCDControllerISR(void *unused){
	lcd_clear_irq();
	//restart Camera Controller
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, 4*CAMERA_CONTROLLER_START, 1);
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
	fprintf(foutput, "31\n");

	for(int i = 0; i < FRAME_SIZE; i++){
	 	uint16_t pixel = IORD_16DIRECT(addr, 2*i);
	 	//REAL CAMERA INTERFACE
	 	int red = (int)((pixel & MASK_RED) >> OFF_RED);
	 	int green = (int)((pixel & MASK_GREEN) >> OFF_GREEN);
	 	int blue = (int)((pixel & MASK_BLUE) >> OFF_BLUE);
	 	green = green / 2;
	 	fprintf(foutput, "%d %d %d\n", red, green, blue);
	 	//printf("Pixel %d\n", i);

	 	//MOCK CAMERA INTERFACE
	 	//one pixel value is written per fifo entry, use that value for a gray-scale pixel
	 	//fprintf(foutput, "%d %d %d\n", pixel, pixel, pixel);
	 }
	//printf("Finished writing image\n");
	fclose(foutput);
	return 0;
}
int main()
{
	iter = 0;
	currentFrame = 0;
	//Enable interrupts for camera controller
	//IOWR_ALTERA_AVALON_PIO_IRQ_MASK(CAMERACONTROLLER_0_BASE, 0xFF);
	//set up interrupt handlers
	usleep(1000*1000);
	int fail = alt_ic_isr_register(0,
			0, CameraControllerISR, NULL, 0x0);
	if(fail)
		return 1;
	alt_ic_irq_enable(0,0);
	fail = alt_ic_isr_register(0,
				2, LCDControllerISR, NULL, 0x0);
	if(fail)
		return 1;
	alt_ic_irq_enable(0,0);

	init_TRDB_D5M();
	init_launch_lcd();
	usleep(1000*1000);
	start_lcd();

	printf("Hello from Nios II!\n");
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, 4*CAMERA_CONTROLLER_FRAME0, FRAME0);
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, 4*CAMERA_CONTROLLER_FRAME1, FRAME1);
	IOWR_32DIRECT(CAMERACONTROLLER_0_BASE, 4*CAMERA_CONTROLLER_START, 1);
	usleep(100*1000);
	printf("Finished loading image\n");
	while(1);
	return 0;
}

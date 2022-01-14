#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "io.h"
#include "system.h"

#define LCD_BASE (0x10000840)
#define FRONT_IMAGE_OFF 0
#define BACK_IMAGE_OFF 4
#define START_OFF 8
#define CMD_DATA_OFF 12
#define IS_WRITING_CMD_OFF 16
#define CAMERA_IRQ 20
#define PENDING_IRQ 24

#define HPS_0_FRONT_FRAME_BASE 0x0
#define HPS_0_BACK_FRAME_BASE 0x40000



#define LCD_WR_REG(value) IOWR_32DIRECT(LCD_BASE, CMD_DATA_OFF, value)
#define LCD_WR_DATA(value) LCD_WR_REG(value)

#define SET_FRONT_FRAME_ADDR(value) IOWR_32DIRECT(LCD_BASE, FRONT_IMAGE_OFF, value)
#define SET_BACK_FRAME_ADDR(value) IOWR_32DIRECT(LCD_BASE, BACK_IMAGE_OFF, value)
#define SET_WRITING_CMD_REG(value) IOWR_32DIRECT(LCD_BASE, IS_WRITING_CMD_OFF, value)
#define SET_LCD_START_REG(value) IOWR_32DIRECT(LCD_BASE, START_OFF, value)
#define SET_CAMERA_READY_REG(value) IOWR_32DIRECT(LCD_BASE, CAMERA_IRQ, value)
#define SET_IRQ_PENDING_REG(value) IOWR_32DIRECT(LCD_BASE, PENDING_IRQ, value)


void lcd_clear_irq();
void lcd_camera_ready();

void set_frame_addr(uint32_t addr, int front);
void init_front_back_buffer_addr();
void start_lcd();

void LCD_init();

int set_LCD_IRQ_handler();

void init_launch_lcd();

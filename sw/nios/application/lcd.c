#include <assert.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "io.h"
#include "system.h"
#include "lcd.h"


void sleep_ms(int time) {
    usleep(1000 * time);
}

void lcd_clear_irq(){
    SET_IRQ_PENDING_REG(0);
}
void lcd_camera_ready(){
    SET_CAMERA_READY_REG(0);
}

void set_frame_addr(uint32_t addr, int front){
    if (front) {
        SET_FRONT_FRAME_ADDR(addr);
    } else {
        SET_BACK_FRAME_ADDR(addr);
    }
}
void init_front_back_buffer_addr(){
    SET_FRONT_FRAME_ADDR(HPS_0_FRONT_FRAME_BASE);
    SET_BACK_FRAME_ADDR(HPS_0_BACK_FRAME_BASE);
}
void start_lcd(){
    SET_LCD_START_REG(1);
}

void init_launch_lcd(){
    init_front_back_buffer_addr();
    LCD_init();

}

void LCD_init(){

    sleep_ms(131);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x0011); //Exit Sleep
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00CF); // Power Control B
        LCD_WR_DATA(0x0000); // Always 0x00
        LCD_WR_DATA(0x0081);
        LCD_WR_DATA(0X00c0);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00ED); // Power on sequence control
        LCD_WR_DATA(0x0064); // Soft Start Keep 1 frame
        LCD_WR_DATA(0x0003);
        LCD_WR_DATA(0X0012);
        LCD_WR_DATA(0X0081);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00E8); // Driver timing control A
        LCD_WR_DATA(0x0085);
        LCD_WR_DATA(0x0001);
        LCD_WR_DATA(0x00798);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00CB); // Power control A
        LCD_WR_DATA(0x0039);
        LCD_WR_DATA(0x002C);
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0034);
        LCD_WR_DATA(0x0002);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00F7); // Pump ratio control
        LCD_WR_DATA(0x0020);
    SET_WRITING_CMD_REG(0);
    
    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00EA); // Driver timing control B
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0000);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00B1); // Frame Control (In Normal Mode)
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x001b);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00B6); // Display Function Control
        LCD_WR_DATA(0x000A);
        LCD_WR_DATA(0x00A2);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00C0); //Power control 1
        LCD_WR_DATA(0x0005); //VRH[5:0]
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00C1); //Power control 2
        LCD_WR_DATA(0x0011); //SAP[2:0];BT[3:0]
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00C5); //VCM control 1
        LCD_WR_DATA(0x0045); //3F
        LCD_WR_DATA(0x0045); //3C
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00C7); //VCM control 2
        LCD_WR_DATA(0X00a2);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x0036); // Memory Access Control
        LCD_WR_DATA(0x0024);// RGB order							//changed
    SET_WRITING_CMD_REG(0);
 
    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00F2); // Enable 3G
        LCD_WR_DATA(0x0000); // 3Gamma Function Disable
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x0026); // Gamma Set
        LCD_WR_DATA(0x0001); // Gamma curve selected
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00E0); // Positive Gamma Correction, Set Gamma
        LCD_WR_DATA(0x000F);
        LCD_WR_DATA(0x0026);
        LCD_WR_DATA(0x0024);
        LCD_WR_DATA(0x000b);
        LCD_WR_DATA(0x000E);
        LCD_WR_DATA(0x0008);
        LCD_WR_DATA(0x004b);
        LCD_WR_DATA(0X00a8);
        LCD_WR_DATA(0x003b);
        LCD_WR_DATA(0x000a);
        LCD_WR_DATA(0x0014);
        LCD_WR_DATA(0x0006);
        LCD_WR_DATA(0x0010);
        LCD_WR_DATA(0x0009);
        LCD_WR_DATA(0x0000);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0X00E1); //Negative Gamma Correction, Set Gamma
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x001c);
        LCD_WR_DATA(0x0020);
        LCD_WR_DATA(0x0004);
        LCD_WR_DATA(0x0010);
        LCD_WR_DATA(0x0008);
        LCD_WR_DATA(0x0034);
        LCD_WR_DATA(0x0047);
        LCD_WR_DATA(0x0044);
        LCD_WR_DATA(0x0005);
        LCD_WR_DATA(0x000b);
        LCD_WR_DATA(0x0009);
        LCD_WR_DATA(0x002f);
        LCD_WR_DATA(0x0036);
        LCD_WR_DATA(0x000f);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x002A); // Column Address Set
    	LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0001);
        LCD_WR_DATA(0x003f);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x002B); // Page Address Set
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x0000);
        LCD_WR_DATA(0x00ef);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x003A); // COLMOD: Pixel Format Set
        LCD_WR_DATA(0x0055);
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x00f6); // Interface Control
        LCD_WR_DATA(0x0001);
        LCD_WR_DATA(0x0030);
        LCD_WR_DATA(0x0000);
    SET_WRITING_CMD_REG(0);

    //Command we added to reverse the order the colomns are read
    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x000B); // Read Display MADCTL
        LCD_WR_DATA(0x0000); // Don't care
        LCD_WR_DATA(0x0020); // B6 = '1' => Right to Left
    SET_WRITING_CMD_REG(0);
    
    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x0029); //display on
    SET_WRITING_CMD_REG(0);

    SET_WRITING_CMD_REG(1);
    LCD_WR_REG(0x002c); // 0x3C
    SET_WRITING_CMD_REG(0);

}

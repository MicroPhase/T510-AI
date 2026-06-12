/***************************************************************************//**
 *   @file   frequency/lmk04828/lmk04828.c
 *   @brief  Implementation of lmk04828 Driver.
 *   @author DBogdan (dragos.bogdan@analog.com)
********************************************************************************
 * Copyright 2015-2016(c) Analog Devices, Inc.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *  - Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  - Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *  - Neither the name of Analog Devices, Inc. nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *  - The use of this software may or may not infringe the patent rights
 *    of one or more patent holders.  This license does not release you
 *    from the requirement that you obtain separate licenses from these
 *    patent holders to use this software.
 *  - Use of the software either in source or binary form, must be run
 *    on or directly connected to an Analog Devices Inc. component.
 *
 * THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT,
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*******************************************************************************/

/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include "lmk04828.h"

// #include "platform.h"
#include <stdio.h>
#include "fcntl.h"
#include "stdio.h"
#include "sys/ioctl.h"
#include <sys/mman.h>
#include <linux/ioctl.h>
#include "linux/spi/spidev.h"
#include "unistd.h"
#include "stdint.h"

static uint32_t mode=0;
static uint32_t lsb=0;
static uint32_t speed = 10000000;
static uint8_t bits = 8;
static uint16_t delay;
static int fd_spi;


int _lmk04828_spi_init(const char * spi_path){
	int ret;
	fd_spi = open(spi_path, O_RDWR);
	if(fd_spi < 0)
	{
		return -1;
	}
	uint32_t request;
	mode |= SPI_MODE_0;
	request = mode;
	ret = ioctl(fd_spi,SPI_IOC_WR_MODE,&mode);
	if(ret == -1)
		fprintf(stderr,"cannot set spi mode\n");

	ret = ioctl(fd_spi, SPI_IOC_WR_MODE, &mode);
	if (ret == -1)
		fprintf(stderr,"cannot get spi mode\n");

	if (request != mode){
		printf("WARNING device does not support requested mode 0x%x\n",
				request);
		return -1;
	}

	ioctl(fd_spi,SPI_IOC_WR_LSB_FIRST, &lsb);
//    ioctl(fd_spi,SPI_IOC_RD_LSB_FIRST, &lsb);


	ret = ioctl(fd_spi, SPI_IOC_WR_BITS_PER_WORD, &bits);
	if (ret == -1){
		printf("can't set bits per word");
		return -1;
	}


	ret = ioctl(fd_spi, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
	if (ret == -1){
		printf("can't set max speed hz");
		return -1;
	}

	ret = ioctl(fd_spi, SPI_IOC_RD_MAX_SPEED_HZ, &speed);
	if (ret == -1){
		printf("can't get max speed hz");
		return -1;
	}
	printf("init spi %s\n", spi_path);

	return fd_spi;
}
	
void _lmk04828_spi_exit(int fd_spi){
	close(fd_spi);
}

int _lmk04828_spi_read_reg(int fd_spi, uint32_t reg){
	uint8_t rx[] = {0x00,0x00,0x00};
    uint8_t tx[] = {0x00,0x00,0x00};

    // uint16_t cmd;
    // cmd = AD_READ | AD_CNT(1) | AD_ADDR(reg);
    // tx[0] = cmd >> 8;
    // tx[1] = cmd & 0xff;
    // tx[2] = 0x0;

    tx[0] = 0x80 | (reg >> 8);
	tx[1] = reg & 0xFF;
	tx[2] = 0x00;
    int ret;
    struct spi_ioc_transfer tr = {
            .tx_buf = (unsigned long)tx,
            .rx_buf = (unsigned long)rx,
            .len = 3,
            .delay_usecs = delay,
            .bits_per_word = bits,
    };
    ret = ioctl(fd_spi, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 1)
    {
        printf("can't read spi message\n");
        return -1;
    }
    return rx[2];
}

int _lmk04828_spi_write_reg(int fd_spi, uint32_t reg,uint8_t val){
	uint8_t rx[] = {0x00,0x00,0x00};
    uint8_t tx[] = {0x00,0x00,0x00};

    // uint16_t cmd;
    // cmd = AD_WRITE | AD_CNT(1) | AD_ADDR(reg);
    // tx[0] = cmd >> 8;
    // tx[1] = cmd & 0xff;
    // tx[2] = val;

    tx[0] = reg >> 8;
	tx[1] = reg & 0xFF;
	tx[2] = val & 0xFF;
    int ret;
    struct spi_ioc_transfer tr = {
            .tx_buf = (unsigned long)tx,
            .rx_buf = (unsigned long)rx,
            .len = 3,
            .delay_usecs = delay,
            .bits_per_word = bits,
    };
    ret = ioctl(fd_spi, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 1)
    {
        return -1;
    }
    return 0;
}




/***************************************************************************//**
 * @brief Reads the value of the selected register.
 *
 * @param dev - The device structure.
 * @param reg_addr - The address of the register to read - address[31:16]
 *  holds the number of bytes to read (a round about method)-- it is also
 *  limited to 4 bytes max (to fill in a 32 bit integer type).
 * @param reg_data - The register's value.
 *
 * @return Returns 0 in case of success or negative error code.
*******************************************************************************/
int32_t lmk04828_spi_read(struct lmk04828_dev *dev,
			  uint32_t reg_addr)
{
	int32_t ret = 0;
	ret = _lmk04828_spi_read_reg(dev->fd_spi, reg_addr);
	if (ret < 0)
	{
		printf("spi read faile\r\n");
	}
	return ret;
}

/***************************************************************************//**
 * @brief Writes a value to the selected register.
 *
 * @param dev - The device structure.
 * @param reg_addr - The address of the register to write - address[31:16]
 *  holds the number of bytes to write (a round about method)-- it is also
 *  limited to 4 bytes max (to fill in a 32 bit integer type).
 * @param reg_data - The value to write to the register.
 *
 * @return Returns 0 in case of success or negative error code.
*******************************************************************************/
int32_t lmk04828_spi_write(struct lmk04828_dev *dev,
			   uint32_t reg_addr,
			   uint8_t reg_data)
{
	int32_t ret = 0;
	ret = _lmk04828_spi_write_reg(dev->fd_spi, reg_addr, reg_data);
	if (ret < 0)
	{
		printf("spi write faile\r\n");
	}
	usleep(10);
	return ret;
}


int32_t lmk04828_check_pll_lock(struct lmk04828_dev *dev)
{

	uint8_t pll1_lock_status;
	uint8_t pll2_lock_status;
	uint8_t pll1_locked = 0;

	lmk04828_spi_write(dev, 0x182, 0x1);
	lmk04828_spi_write(dev, 0x182, 0x0);
	lmk04828_spi_write(dev, 0x183, 0x1);
	lmk04828_spi_write(dev, 0x183, 0x0);
	pll1_lock_status = lmk04828_spi_read(dev, 0x182);
	if ((pll1_lock_status & 0x7) != 0x02)
		pll1_locked = 0;
	else
		pll1_locked = 1;

	pll2_lock_status = lmk04828_spi_read(dev, 0x183);

	printf("lmk04828 pll locked status, pll1_lock_status:%d, pll2_lock_status:%d\r\n", pll1_lock_status, pll2_lock_status);

	return pll1_locked ;

}

/***************************************************************************//**
 * @brief Initializes the lmk04828.
 *
 * @param device - The device structure.
 * @param init_param - The structure containing the device initial parameters.
 *
 * @return Returns 0 in case of success or negative error code.
*******************************************************************************/


int32_t lmk04828_setup(struct lmk04828_dev *device, const char * file_path, uint8_t chip_id)
{
	int ret;
	int fd_spi = _lmk04828_spi_init(file_path);
	if(fd_spi < 0)
	{
		printf("lmk04828 spi init failed\r\n");
		return -1;
	}
	printf("lmk04828 spi fd:%d\r\n", fd_spi);
	device->fd_spi = fd_spi;
	device->lmk_chip_id = chip_id;

	ret = lmk04828_initialize_clk_in0_10m_outclk_254p76(device);
	if (ret != 0)
		return ret;

	ret = lmk04828_set_sysref_req_mode(device);
	if (ret != 0)
		return ret;

	return 0;
}

int32_t lmk04828_set_base_rate(struct lmk04828_dev *device, double base_rate){
	double pll_rate = 2949.12e6;
	int div = pll_rate/base_rate;

	(void)device;
	(void)div;
	return 0;
}


/***************************************************************************//**
 * @brief Free the resources allocated by lmk04828_setup().
 *
 * @param dev - The device structure.
 *
 * @return 0 in case of success, negative error code otherwise.
*******************************************************************************/
void lmk04828_remove(struct lmk04828_dev *dev)
{
	_lmk04828_spi_exit(dev->fd_spi);
}


int32_t lmk04828_verify_chip_id(struct lmk04828_dev *device) {
	unsigned char chip_id;
	chip_id = lmk04828_spi_read(device, 0x03);
	printf("lmk04828_verify_chip_id spi fd:%d\r\n", device->fd_spi);
	if (chip_id != device->lmk_chip_id) {
		printf("LMK04828 chip id mismatch chip_id=%x \r\n", chip_id);
		return -1;
	}

	printf("LMK04828 chip id chip_id=%x \r\n", chip_id);

	return 0;
}




//*
// sysref oneshot, using lmk04828 reqest pin, 245.76M
// int32_t lmk04828_initialize(struct lmk04828_dev *device) {
// 	lmk04828_spi_write(device, 0x0000, 0x10);
// 	lmk04828_spi_write(device, 0x0002, 0x00);
// 	lmk04828_spi_write(device, 0x0003, 0x06);
// 	lmk04828_spi_write(device, 0x0004, 0xD0);
// 	lmk04828_spi_write(device, 0x0005, 0x5B);
// 	lmk04828_spi_write(device, 0x0006, 0x00);
// 	lmk04828_spi_write(device, 0x000C, 0x51);
// 	lmk04828_spi_write(device, 0x000D, 0x04);
// 	lmk04828_spi_write(device, 0x0100, 0x0C);
// 	lmk04828_spi_write(device, 0x0101, 0x55);
// 	lmk04828_spi_write(device, 0x0102, 0x55);
// 	lmk04828_spi_write(device, 0x0103, 0x00);
// 	lmk04828_spi_write(device, 0x0104, 0x22);
// 	lmk04828_spi_write(device, 0x0105, 0x00);
// 	lmk04828_spi_write(device, 0x0106, 0xF0);
// 	lmk04828_spi_write(device, 0x0107, 0x55);
// 	lmk04828_spi_write(device, 0x0108, 0x0C);
// 	lmk04828_spi_write(device, 0x0109, 0x55);
// 	lmk04828_spi_write(device, 0x010A, 0x55);
// 	lmk04828_spi_write(device, 0x010B, 0x00);
// 	lmk04828_spi_write(device, 0x010C, 0x22);
// 	lmk04828_spi_write(device, 0x010D, 0x00);
// 	lmk04828_spi_write(device, 0x010E, 0xF0);
// 	lmk04828_spi_write(device, 0x010F, 0x55);
// 	lmk04828_spi_write(device, 0x0110, 0x0C);
// 	lmk04828_spi_write(device, 0x0111, 0x55);
// 	lmk04828_spi_write(device, 0x0112, 0x55);
// 	lmk04828_spi_write(device, 0x0113, 0x00);
// 	lmk04828_spi_write(device, 0x0114, 0x02);
// 	lmk04828_spi_write(device, 0x0115, 0x00);
// 	lmk04828_spi_write(device, 0x0116, 0xF1);
// 	lmk04828_spi_write(device, 0x0117, 0x05);
// 	lmk04828_spi_write(device, 0x0118, 0x0C);
// 	lmk04828_spi_write(device, 0x0119, 0x55);
// 	lmk04828_spi_write(device, 0x011A, 0x55);
// 	lmk04828_spi_write(device, 0x011B, 0x00);
// 	lmk04828_spi_write(device, 0x011C, 0x02);
// 	lmk04828_spi_write(device, 0x011D, 0x00);
// 	lmk04828_spi_write(device, 0x011E, 0xF0);
// 	lmk04828_spi_write(device, 0x011F, 0x51);
// 	lmk04828_spi_write(device, 0x0120, 0x0C);
// 	lmk04828_spi_write(device, 0x0121, 0x55);
// 	lmk04828_spi_write(device, 0x0122, 0x55);
// 	lmk04828_spi_write(device, 0x0123, 0x00);
// 	lmk04828_spi_write(device, 0x0124, 0x22);
// 	lmk04828_spi_write(device, 0x0125, 0x00);
// 	lmk04828_spi_write(device, 0x0126, 0xF1);
// 	lmk04828_spi_write(device, 0x0127, 0x01);
// 	lmk04828_spi_write(device, 0x0128, 0x0C);
// 	lmk04828_spi_write(device, 0x0129, 0x55);
// 	lmk04828_spi_write(device, 0x012A, 0x55);
// 	lmk04828_spi_write(device, 0x012B, 0x00);
// 	lmk04828_spi_write(device, 0x012C, 0x02);
// 	lmk04828_spi_write(device, 0x012D, 0x00);
// 	lmk04828_spi_write(device, 0x012E, 0xF1);
// 	lmk04828_spi_write(device, 0x012F, 0x07);
// 	lmk04828_spi_write(device, 0x0130, 0x0C);
// 	lmk04828_spi_write(device, 0x0131, 0x55);
// 	lmk04828_spi_write(device, 0x0132, 0x55);
// 	lmk04828_spi_write(device, 0x0133, 0x00);
// 	lmk04828_spi_write(device, 0x0134, 0x02);
// 	lmk04828_spi_write(device, 0x0135, 0x00);
// 	lmk04828_spi_write(device, 0x0136, 0xF1);
// 	lmk04828_spi_write(device, 0x0137, 0x07);
// 	lmk04828_spi_write(device, 0x0138, 0x25);
// 	lmk04828_spi_write(device, 0x0139, 0x03);
// 	lmk04828_spi_write(device, 0x013A, 0x0F);
// 	lmk04828_spi_write(device, 0x013B, 0x00);
// 	lmk04828_spi_write(device, 0x013C, 0x00);
// 	lmk04828_spi_write(device, 0x013D, 0x08);
// 	lmk04828_spi_write(device, 0x013E, 0x00);
// 	lmk04828_spi_write(device, 0x013F, 0x00);
// 	lmk04828_spi_write(device, 0x0140, 0x01);
// 	lmk04828_spi_write(device, 0x0141, 0x00);
// 	lmk04828_spi_write(device, 0x0142, 0x00);
// 	lmk04828_spi_write(device, 0x0143, 0x51);
// 	lmk04828_spi_write(device, 0x0144, 0xFF);
// 	lmk04828_spi_write(device, 0x0145, 0x7F);
// 	lmk04828_spi_write(device, 0x0146, 0x3B);
// 	lmk04828_spi_write(device, 0x0147, 0x0A);
// 	lmk04828_spi_write(device, 0x0148, 0x00);
// 	lmk04828_spi_write(device, 0x0149, 0x00);
// 	lmk04828_spi_write(device, 0x014A, 0x0A);
// 	lmk04828_spi_write(device, 0x014B, 0x16);
// 	lmk04828_spi_write(device, 0x014C, 0x00);
// 	lmk04828_spi_write(device, 0x014D, 0x00);
// 	lmk04828_spi_write(device, 0x014E, 0xC0);
// 	lmk04828_spi_write(device, 0x014F, 0x7F);
// 	lmk04828_spi_write(device, 0x0150, 0x03);
// 	lmk04828_spi_write(device, 0x0151, 0x02);
// 	lmk04828_spi_write(device, 0x0152, 0x00);
// 	lmk04828_spi_write(device, 0x0153, 0x02);
// 	lmk04828_spi_write(device, 0x0154, 0x71);
// 	lmk04828_spi_write(device, 0x0155, 0x00);
// 	lmk04828_spi_write(device, 0x0156, 0x7D);
// 	lmk04828_spi_write(device, 0x0157, 0x00);
// 	lmk04828_spi_write(device, 0x0158, 0x7D);
// 	lmk04828_spi_write(device, 0x0159, 0x03);
// 	lmk04828_spi_write(device, 0x015A, 0x00);
// 	lmk04828_spi_write(device, 0x015B, 0xD4);
// 	lmk04828_spi_write(device, 0x015C, 0x20);
// 	lmk04828_spi_write(device, 0x015D, 0x00);
// 	lmk04828_spi_write(device, 0x015E, 0x00);
// 	lmk04828_spi_write(device, 0x015F, 0x0B);
// 	lmk04828_spi_write(device, 0x0160, 0x00);
// 	lmk04828_spi_write(device, 0x0161, 0x01);
// 	lmk04828_spi_write(device, 0x0162, 0x44);
// 	lmk04828_spi_write(device, 0x0163, 0x00);
// 	lmk04828_spi_write(device, 0x0164, 0x00);
// 	lmk04828_spi_write(device, 0x0165, 0x0C);
// 	lmk04828_spi_write(device, 0x0171, 0xAA);
// 	lmk04828_spi_write(device, 0x0172, 0x02);
// 	lmk04828_spi_write(device, 0x017C, 0x15);
// 	lmk04828_spi_write(device, 0x017D, 0x33);
// 	lmk04828_spi_write(device, 0x0166, 0x00);
// 	lmk04828_spi_write(device, 0x0167, 0x00);
// 	lmk04828_spi_write(device, 0x0168, 0x0C);
// 	lmk04828_spi_write(device, 0x0169, 0x59);
// 	lmk04828_spi_write(device, 0x016A, 0x20);
// 	lmk04828_spi_write(device, 0x016B, 0x00);
// 	lmk04828_spi_write(device, 0x016C, 0x00);
// 	lmk04828_spi_write(device, 0x016D, 0x00);
// 	lmk04828_spi_write(device, 0x016E, 0x3B);
// 	lmk04828_spi_write(device, 0x0173, 0x00);
// 	lmk04828_spi_write(device, 0x0182, 0x00);
// 	lmk04828_spi_write(device, 0x0183, 0x00);
// 	lmk04828_spi_write(device, 0x0184, 0x00);
// 	lmk04828_spi_write(device, 0x0185, 0x00);
// 	lmk04828_spi_write(device, 0x0188, 0x00);
// 	lmk04828_spi_write(device, 0x0189, 0x00);
// 	lmk04828_spi_write(device, 0x018A, 0x00);
// 	lmk04828_spi_write(device, 0x018B, 0x00);
// 	lmk04828_spi_write(device, 0x1FFD, 0x00);
// 	lmk04828_spi_write(device, 0x1FFE, 0x00);
// 	lmk04828_spi_write(device, 0x1FFF, 0x53);

// 	int retval = lmk04828_verify_chip_id(device);
// 	if (retval != 0) {
// 		printf("SPI is not working \r\n");
// 		return retval;
// 	}
// 	return 0;
// }

int32_t lmk04828_initialize(struct lmk04828_dev *device) {

	lmk04828_spi_write(device,0x0000, 0x90);
	lmk04828_spi_write(device,0x0000, 0x10);
	lmk04828_spi_write(device,0x0002, 0x00);
	lmk04828_spi_write(device,0x0003, 0x06);
	lmk04828_spi_write(device,0x0004, 0xD0);
	lmk04828_spi_write(device,0x0005, 0x5B);
	lmk04828_spi_write(device,0x0006, 0x00);
	lmk04828_spi_write(device,0x000C, 0x51);
	lmk04828_spi_write(device,0x000D, 0x04);
	lmk04828_spi_write(device,0x0100, 0x0C);
	lmk04828_spi_write(device,0x0101, 0x55);
	lmk04828_spi_write(device,0x0102, 0x55);
	lmk04828_spi_write(device,0x0103, 0x00);
	lmk04828_spi_write(device,0x0104, 0x22);
	lmk04828_spi_write(device,0x0105, 0x00);
	lmk04828_spi_write(device,0x0106, 0xF0);
	lmk04828_spi_write(device,0x0107, 0x55);
	lmk04828_spi_write(device,0x0108, 0x0C);
	lmk04828_spi_write(device,0x0109, 0x55);
	lmk04828_spi_write(device,0x010A, 0x55);
	lmk04828_spi_write(device,0x010B, 0x00);
	lmk04828_spi_write(device,0x010C, 0x22);
	lmk04828_spi_write(device,0x010D, 0x00);
	lmk04828_spi_write(device,0x010E, 0xF0);
	lmk04828_spi_write(device,0x010F, 0x15);
	lmk04828_spi_write(device,0x0110, 0x0C);
	lmk04828_spi_write(device,0x0111, 0x55);
	lmk04828_spi_write(device,0x0112, 0x55);
	lmk04828_spi_write(device,0x0113, 0x00);
	lmk04828_spi_write(device,0x0114, 0x02);
	lmk04828_spi_write(device,0x0115, 0x00);
	lmk04828_spi_write(device,0x0116, 0xF0);
	lmk04828_spi_write(device,0x0117, 0x55);
	lmk04828_spi_write(device,0x0118, 0x0C);
	lmk04828_spi_write(device,0x0119, 0x55);
	lmk04828_spi_write(device,0x011A, 0x55);
	lmk04828_spi_write(device,0x011B, 0x00);
	lmk04828_spi_write(device,0x011C, 0x02);
	lmk04828_spi_write(device,0x011D, 0x00);
	lmk04828_spi_write(device,0x011E, 0xF0);
	lmk04828_spi_write(device,0x011F, 0x15);
	lmk04828_spi_write(device,0x0120, 0x0C);
	lmk04828_spi_write(device,0x0121, 0x55);
	lmk04828_spi_write(device,0x0122, 0x55);
	lmk04828_spi_write(device,0x0123, 0x00);
	lmk04828_spi_write(device,0x0124, 0x22);
	lmk04828_spi_write(device,0x0125, 0x00);
	lmk04828_spi_write(device,0x0126, 0xF0);
	lmk04828_spi_write(device,0x0127, 0x05);
	lmk04828_spi_write(device,0x0128, 0x0C);
	lmk04828_spi_write(device,0x0129, 0x55);
	lmk04828_spi_write(device,0x012A, 0x55);
	lmk04828_spi_write(device,0x012B, 0x00);
	lmk04828_spi_write(device,0x012C, 0x02);
	lmk04828_spi_write(device,0x012D, 0x00);
	lmk04828_spi_write(device,0x012E, 0xF0);
	lmk04828_spi_write(device,0x012F, 0x55);
	lmk04828_spi_write(device,0x0130, 0x0C);
	lmk04828_spi_write(device,0x0131, 0x55);
	lmk04828_spi_write(device,0x0132, 0x55);
	lmk04828_spi_write(device,0x0133, 0x00);
	lmk04828_spi_write(device,0x0134, 0x02);
	lmk04828_spi_write(device,0x0135, 0x00);
	lmk04828_spi_write(device,0x0136, 0xF0);
	lmk04828_spi_write(device,0x0137, 0x55);
	lmk04828_spi_write(device,0x0138, 0x25);
	lmk04828_spi_write(device,0x0139, 0x02);
	lmk04828_spi_write(device,0x013A, 0x0C);
	lmk04828_spi_write(device,0x013B, 0x00);
	lmk04828_spi_write(device,0x013C, 0x00);
	lmk04828_spi_write(device,0x013D, 0x08);
	lmk04828_spi_write(device,0x013E, 0x03);
	lmk04828_spi_write(device,0x013F, 0x00);
	lmk04828_spi_write(device,0x0140, 0x00);
	lmk04828_spi_write(device,0x0141, 0x00);
	lmk04828_spi_write(device,0x0142, 0x00);
	lmk04828_spi_write(device,0x0143, 0x51);
	lmk04828_spi_write(device,0x0144, 0xFF);
	lmk04828_spi_write(device,0x0145, 0x7F);
	lmk04828_spi_write(device,0x0146, 0x39);
	lmk04828_spi_write(device,0x0147, 0x0E);
	lmk04828_spi_write(device,0x0148, 0x00);
	lmk04828_spi_write(device,0x0149, 0x40);
	lmk04828_spi_write(device,0x014A, 0x0B);
	lmk04828_spi_write(device,0x014B, 0x16);
	lmk04828_spi_write(device,0x014C, 0x00);
	lmk04828_spi_write(device,0x014D, 0x00);
	lmk04828_spi_write(device,0x014E, 0xC0);
	lmk04828_spi_write(device,0x014F, 0x7F);
	lmk04828_spi_write(device,0x0150, 0x03);
	lmk04828_spi_write(device,0x0151, 0x02);
	lmk04828_spi_write(device,0x0152, 0x00);
	lmk04828_spi_write(device,0x0153, 0x02);
	lmk04828_spi_write(device,0x0154, 0x71);
	lmk04828_spi_write(device,0x0155, 0x00);
	lmk04828_spi_write(device,0x0156, 0x7D);
	lmk04828_spi_write(device,0x0157, 0x00);
	lmk04828_spi_write(device,0x0158, 0x7D);
	lmk04828_spi_write(device,0x0159, 0x03);
	lmk04828_spi_write(device,0x015A, 0x00);
	lmk04828_spi_write(device,0x015B, 0xD4);
	lmk04828_spi_write(device,0x015C, 0x20);
	lmk04828_spi_write(device,0x015D, 0x00);
	lmk04828_spi_write(device,0x015E, 0x00);
	lmk04828_spi_write(device,0x015F, 0x13);
	lmk04828_spi_write(device,0x0160, 0x00);
	lmk04828_spi_write(device,0x0161, 0x01);
	lmk04828_spi_write(device,0x0162, 0x44);
	lmk04828_spi_write(device,0x0163, 0x00);
	lmk04828_spi_write(device,0x0164, 0x00);
	lmk04828_spi_write(device,0x0165, 0x0C);
	lmk04828_spi_write(device,0x0171, 0xAA);
	lmk04828_spi_write(device,0x0172, 0x02);
	lmk04828_spi_write(device,0x017C, 0x15);
	lmk04828_spi_write(device,0x017D, 0x33);
	lmk04828_spi_write(device,0x0166, 0x00);
	lmk04828_spi_write(device,0x0167, 0x00);
	lmk04828_spi_write(device,0x0168, 0x0C);
	lmk04828_spi_write(device,0x0169, 0x59);
	lmk04828_spi_write(device,0x016A, 0x20);
	lmk04828_spi_write(device,0x016B, 0x00);
	lmk04828_spi_write(device,0x016C, 0x00);
	lmk04828_spi_write(device,0x016D, 0x00);
	lmk04828_spi_write(device,0x016E, 0x3B);
	lmk04828_spi_write(device,0x0173, 0x00);
	// lmk04828_spi_write(device,0x0182, 0x00);
	// lmk04828_spi_write(device,0x0183, 0x00);
	// lmk04828_spi_write(device,0x0184, 0x00);
	// lmk04828_spi_write(device,0x0185, 0x00);
	// lmk04828_spi_write(device,0x0188, 0x00);
	// lmk04828_spi_write(device,0x0189, 0x00);
	// lmk04828_spi_write(device,0x018A, 0x00);
	// lmk04828_spi_write(device,0x018B, 0x00);
	lmk04828_spi_write(device,0x1FFD, 0x00);
	lmk04828_spi_write(device,0x1FFE, 0x00);
	lmk04828_spi_write(device,0x1FFF, 0x53);

	// lmk04828_spi_write(device, 0x0000, 0x90);
	// lmk04828_spi_write(device, 0x0000, 0x10);
	// lmk04828_spi_write(device, 0x0002, 0x00);
	// lmk04828_spi_write(device, 0x0003, 0x06);
	// lmk04828_spi_write(device, 0x0004, 0xD0);
	// lmk04828_spi_write(device, 0x0005, 0x5B);
	// lmk04828_spi_write(device, 0x0006, 0x00);
	// lmk04828_spi_write(device, 0x000C, 0x51);
	// lmk04828_spi_write(device, 0x000D, 0x04);
	// lmk04828_spi_write(device, 0x0100, 0x0C);
	// lmk04828_spi_write(device, 0x0101, 0x55);
	// lmk04828_spi_write(device, 0x0102, 0x55);
	// lmk04828_spi_write(device, 0x0103, 0x00);
	// lmk04828_spi_write(device, 0x0104, 0x22);
	// lmk04828_spi_write(device, 0x0105, 0x00);
	// lmk04828_spi_write(device, 0x0106, 0xF0);
	// lmk04828_spi_write(device, 0x0107, 0x55);
	// lmk04828_spi_write(device, 0x0108, 0x0C);
	// lmk04828_spi_write(device, 0x0109, 0x55);
	// lmk04828_spi_write(device, 0x010A, 0x55);
	// lmk04828_spi_write(device, 0x010B, 0x00);
	// lmk04828_spi_write(device, 0x010C, 0x22);
	// lmk04828_spi_write(device, 0x010D, 0x00);
	// lmk04828_spi_write(device, 0x010E, 0xF0);
	// lmk04828_spi_write(device, 0x010F, 0x15);
	// lmk04828_spi_write(device, 0x0110, 0x0C);
	// lmk04828_spi_write(device, 0x0111, 0x55);
	// lmk04828_spi_write(device, 0x0112, 0x55);
	// lmk04828_spi_write(device, 0x0113, 0x00);
	// lmk04828_spi_write(device, 0x0114, 0x02);
	// lmk04828_spi_write(device, 0x0115, 0x00);
	// lmk04828_spi_write(device, 0x0116, 0xF1);
	// lmk04828_spi_write(device, 0x0117, 0x05);
	// lmk04828_spi_write(device, 0x0118, 0x0C);
	// lmk04828_spi_write(device, 0x0119, 0x55);
	// lmk04828_spi_write(device, 0x011A, 0x55);
	// lmk04828_spi_write(device, 0x011B, 0x00);
	// lmk04828_spi_write(device, 0x011C, 0x02);
	// lmk04828_spi_write(device, 0x011D, 0x00);
	// lmk04828_spi_write(device, 0x011E, 0xF0);
	// lmk04828_spi_write(device, 0x011F, 0x15);
	// lmk04828_spi_write(device, 0x0120, 0x0C);
	// lmk04828_spi_write(device, 0x0121, 0x55);
	// lmk04828_spi_write(device, 0x0122, 0x55);
	// lmk04828_spi_write(device, 0x0123, 0x00);
	// lmk04828_spi_write(device, 0x0124, 0x22);
	// lmk04828_spi_write(device, 0x0125, 0x00);
	// lmk04828_spi_write(device, 0x0126, 0xF1);
	// lmk04828_spi_write(device, 0x0127, 0x05);
	// lmk04828_spi_write(device, 0x0128, 0x0C);
	// lmk04828_spi_write(device, 0x0129, 0x55);
	// lmk04828_spi_write(device, 0x012A, 0x55);
	// lmk04828_spi_write(device, 0x012B, 0x00);
	// lmk04828_spi_write(device, 0x012C, 0x02);
	// lmk04828_spi_write(device, 0x012D, 0x00);
	// lmk04828_spi_write(device, 0x012E, 0xF1);
	// lmk04828_spi_write(device, 0x012F, 0x05);
	// lmk04828_spi_write(device, 0x0130, 0x0C);
	// lmk04828_spi_write(device, 0x0131, 0x55);
	// lmk04828_spi_write(device, 0x0132, 0x55);
	// lmk04828_spi_write(device, 0x0133, 0x00);
	// lmk04828_spi_write(device, 0x0134, 0x02);
	// lmk04828_spi_write(device, 0x0135, 0x00);
	// lmk04828_spi_write(device, 0x0136, 0xF1);
	// lmk04828_spi_write(device, 0x0137, 0x07);
	// lmk04828_spi_write(device, 0x0138, 0x25);
	// lmk04828_spi_write(device, 0x0139, 0x03);
	// lmk04828_spi_write(device, 0x013A, 0x0F);
	// lmk04828_spi_write(device, 0x013B, 0x00);
	// lmk04828_spi_write(device, 0x013C, 0x00);
	// lmk04828_spi_write(device, 0x013D, 0x08);
	// lmk04828_spi_write(device, 0x013E, 0x00);
	// lmk04828_spi_write(device, 0x013F, 0x00);
	// lmk04828_spi_write(device, 0x0140, 0x01);
	// lmk04828_spi_write(device, 0x0141, 0x00);
	// lmk04828_spi_write(device, 0x0142, 0x00);
	// lmk04828_spi_write(device, 0x0143, 0x51);
	// lmk04828_spi_write(device, 0x0144, 0xFF);
	// lmk04828_spi_write(device, 0x0145, 0x7F);
	// lmk04828_spi_write(device, 0x0146, 0x3B);
	// lmk04828_spi_write(device, 0x0147, 0x0A);
	// lmk04828_spi_write(device, 0x0148, 0x00);
	// lmk04828_spi_write(device, 0x0149, 0x00);
	// lmk04828_spi_write(device, 0x014A, 0x0A);
	// lmk04828_spi_write(device, 0x014B, 0x16);
	// lmk04828_spi_write(device, 0x014C, 0x00);
	// lmk04828_spi_write(device, 0x014D, 0x00);
	// lmk04828_spi_write(device, 0x014E, 0xC0);
	// lmk04828_spi_write(device, 0x014F, 0x7F);
	// lmk04828_spi_write(device, 0x0150, 0x03);
	// lmk04828_spi_write(device, 0x0151, 0x02);
	// lmk04828_spi_write(device, 0x0152, 0x00);
	// lmk04828_spi_write(device, 0x0153, 0x02);
	// lmk04828_spi_write(device, 0x0154, 0x71);
	// lmk04828_spi_write(device, 0x0155, 0x00);
	// lmk04828_spi_write(device, 0x0156, 0x7D);
	// lmk04828_spi_write(device, 0x0157, 0x00);
	// lmk04828_spi_write(device, 0x0158, 0x7D);
	// lmk04828_spi_write(device, 0x0159, 0x03);
	// lmk04828_spi_write(device, 0x015A, 0x00);
	// lmk04828_spi_write(device, 0x015B, 0xD4);
	// lmk04828_spi_write(device, 0x015C, 0x20);
	// lmk04828_spi_write(device, 0x015D, 0x00);
	// lmk04828_spi_write(device, 0x015E, 0x00);
	// lmk04828_spi_write(device, 0x015F, 0x0B);
	// lmk04828_spi_write(device, 0x0160, 0x00);
	// lmk04828_spi_write(device, 0x0161, 0x01);
	// lmk04828_spi_write(device, 0x0162, 0x44);
	// lmk04828_spi_write(device, 0x0163, 0x00);
	// lmk04828_spi_write(device, 0x0164, 0x00);
	// lmk04828_spi_write(device, 0x0165, 0x0C);
	// lmk04828_spi_write(device, 0x0171, 0xAA);
	// lmk04828_spi_write(device, 0x0172, 0x02);
	// lmk04828_spi_write(device, 0x017C, 0x15);
	// lmk04828_spi_write(device, 0x017D, 0x33);
	// lmk04828_spi_write(device, 0x0166, 0x00);
	// lmk04828_spi_write(device, 0x0167, 0x00);
	// lmk04828_spi_write(device, 0x0168, 0x0C);
	// lmk04828_spi_write(device, 0x0169, 0x59);
	// lmk04828_spi_write(device, 0x016A, 0x20);
	// lmk04828_spi_write(device, 0x016B, 0x00);
	// lmk04828_spi_write(device, 0x016C, 0x00);
	// lmk04828_spi_write(device, 0x016D, 0x00);
	// lmk04828_spi_write(device, 0x016E, 0x3B);
	// lmk04828_spi_write(device, 0x0173, 0x00);
	// // lmk04828_spi_write(device, 0x0182,0x00);
	// // lmk04828_spi_write(device, 0x0183,0x00);
	// // lmk04828_spi_write(device, 0x0184,0x00);
	// // lmk04828_spi_write(device, 0x0185,0x00);
	// // lmk04828_spi_write(device, 0x0188,0x00);
	// // lmk04828_spi_write(device, 0x0189,0x00);
	// // lmk04828_spi_write(device, 0x018A,0x00);
	// // lmk04828_spi_write(device, 0x018B,0x00);
	// lmk04828_spi_write(device, 0x1FFD, 0x00);
	// lmk04828_spi_write(device, 0x1FFE, 0x00);
	// lmk04828_spi_write(device, 0x1FFF, 0x53);


	int retval = lmk04828_verify_chip_id(device);
	if (retval != 0) {
		printf("SPI is not working \r\n");
		return retval;
	}


	while(lmk04828_check_pll_lock(device)==0){
		usleep(1000000);
	}
	return 0;
}


//*/
int32_t lmk04828_initialize_clk_in0_10m_outclk_254p76(struct lmk04828_dev *device) {
	lmk04828_spi_write(device, 0x0000, 0x90);
	lmk04828_spi_write(device, 0x0000, 0x10);
	lmk04828_spi_write(device, 0x0002, 0x00);
	lmk04828_spi_write(device, 0x0003, 0x06);
	lmk04828_spi_write(device, 0x0004, 0xD0);
	lmk04828_spi_write(device, 0x0005, 0x5B);
	lmk04828_spi_write(device, 0x0006, 0x00);
	lmk04828_spi_write(device, 0x000C, 0x51);
	lmk04828_spi_write(device, 0x000D, 0x04);
	lmk04828_spi_write(device, 0x0100, 0x0C);
	lmk04828_spi_write(device, 0x0101, 0x55);
	lmk04828_spi_write(device, 0x0102, 0x55);
	lmk04828_spi_write(device, 0x0103, 0x00);
	lmk04828_spi_write(device, 0x0104, 0x22);
	lmk04828_spi_write(device, 0x0105, 0x00);
	lmk04828_spi_write(device, 0x0106, 0xF0);
	lmk04828_spi_write(device, 0x0107, 0x55);
	lmk04828_spi_write(device, 0x0108, 0x0C);
	lmk04828_spi_write(device, 0x0109, 0x55);
	lmk04828_spi_write(device, 0x010A, 0x55);
	lmk04828_spi_write(device, 0x010B, 0x00);
	lmk04828_spi_write(device, 0x010C, 0x22);
	lmk04828_spi_write(device, 0x010D, 0x00);
	lmk04828_spi_write(device, 0x010E, 0xF0);
	lmk04828_spi_write(device, 0x010F, 0x15);
	lmk04828_spi_write(device, 0x0110, 0x0C);
	lmk04828_spi_write(device, 0x0111, 0x55);
	lmk04828_spi_write(device, 0x0112, 0x55);
	lmk04828_spi_write(device, 0x0113, 0x00);
	lmk04828_spi_write(device, 0x0114, 0x02);
	lmk04828_spi_write(device, 0x0115, 0x00);
	lmk04828_spi_write(device, 0x0116, 0xF0);
	lmk04828_spi_write(device, 0x0117, 0x55);
	lmk04828_spi_write(device, 0x0118, 0x0C);
	lmk04828_spi_write(device, 0x0119, 0x55);
	lmk04828_spi_write(device, 0x011A, 0x55);
	lmk04828_spi_write(device, 0x011B, 0x00);
	lmk04828_spi_write(device, 0x011C, 0x02);
	lmk04828_spi_write(device, 0x011D, 0x00);
	lmk04828_spi_write(device, 0x011E, 0xF0);
	lmk04828_spi_write(device, 0x011F, 0x15);
	lmk04828_spi_write(device, 0x0120, 0x0C);
	lmk04828_spi_write(device, 0x0121, 0x55);
	lmk04828_spi_write(device, 0x0122, 0x55);
	lmk04828_spi_write(device, 0x0123, 0x00);
	lmk04828_spi_write(device, 0x0124, 0x22);
	lmk04828_spi_write(device, 0x0125, 0x00);
	lmk04828_spi_write(device, 0x0126, 0xF0);
	lmk04828_spi_write(device, 0x0127, 0x05);
	lmk04828_spi_write(device, 0x0128, 0x0C);
	lmk04828_spi_write(device, 0x0129, 0x55);
	lmk04828_spi_write(device, 0x012A, 0x55);
	lmk04828_spi_write(device, 0x012B, 0x00);
	lmk04828_spi_write(device, 0x012C, 0x02);
	lmk04828_spi_write(device, 0x012D, 0x00);
	lmk04828_spi_write(device, 0x012E, 0xF0);
	lmk04828_spi_write(device, 0x012F, 0x55);
	lmk04828_spi_write(device, 0x0130, 0x0C);
	lmk04828_spi_write(device, 0x0131, 0x55);
	lmk04828_spi_write(device, 0x0132, 0x55);
	lmk04828_spi_write(device, 0x0133, 0x00);
	lmk04828_spi_write(device, 0x0134, 0x02);
	lmk04828_spi_write(device, 0x0135, 0x00);
	lmk04828_spi_write(device, 0x0136, 0xF0);
	lmk04828_spi_write(device, 0x0137, 0x55);
	lmk04828_spi_write(device, 0x0138, 0x25);
	lmk04828_spi_write(device, 0x0139, 0x02);
	lmk04828_spi_write(device, 0x013A, 0x0C);
	lmk04828_spi_write(device, 0x013B, 0x00);
	lmk04828_spi_write(device, 0x013C, 0x00);
	lmk04828_spi_write(device, 0x013D, 0x08);
	lmk04828_spi_write(device, 0x013E, 0x03);
	lmk04828_spi_write(device, 0x013F, 0x00);
	lmk04828_spi_write(device, 0x0140, 0x00);
	lmk04828_spi_write(device, 0x0141, 0x00);
	lmk04828_spi_write(device, 0x0142, 0x00);
	lmk04828_spi_write(device, 0x0143, 0x51);
	lmk04828_spi_write(device, 0x0144, 0xFF);
	lmk04828_spi_write(device, 0x0145, 0x7F);
	lmk04828_spi_write(device, 0x0146, 0x38);
	lmk04828_spi_write(device, 0x0147, 0x0A);
	lmk04828_spi_write(device, 0x0148, 0x33);
	lmk04828_spi_write(device, 0x0149, 0x40);
	lmk04828_spi_write(device, 0x014A, 0x0B);
	lmk04828_spi_write(device, 0x014B, 0x16);
	lmk04828_spi_write(device, 0x014C, 0x00);
	lmk04828_spi_write(device, 0x014D, 0x00);
	lmk04828_spi_write(device, 0x014E, 0xC0);
	lmk04828_spi_write(device, 0x014F, 0x7F);
	lmk04828_spi_write(device, 0x0150, 0x03);
	lmk04828_spi_write(device, 0x0151, 0x02);
	lmk04828_spi_write(device, 0x0152, 0x00);
	lmk04828_spi_write(device, 0x0153, 0x00);
	lmk04828_spi_write(device, 0x0154, 0x7D);
	lmk04828_spi_write(device, 0x0155, 0x03);
	lmk04828_spi_write(device, 0x0156, 0x00);
	lmk04828_spi_write(device, 0x0157, 0x00);
	lmk04828_spi_write(device, 0x0158, 0x7D);
	lmk04828_spi_write(device, 0x0159, 0x06);
	lmk04828_spi_write(device, 0x015A, 0x00);
	lmk04828_spi_write(device, 0x015B, 0xD4);
	lmk04828_spi_write(device, 0x015C, 0x20);
	lmk04828_spi_write(device, 0x015D, 0x00);
	lmk04828_spi_write(device, 0x015E, 0x00);
	lmk04828_spi_write(device, 0x015F, 0x13);
	lmk04828_spi_write(device, 0x0160, 0x00);
	lmk04828_spi_write(device, 0x0161, 0x01);
	lmk04828_spi_write(device, 0x0162, 0x44);
	lmk04828_spi_write(device, 0x0163, 0x00);
	lmk04828_spi_write(device, 0x0164, 0x00);
	lmk04828_spi_write(device, 0x0165, 0x0C);
	lmk04828_spi_write(device, 0x0171, 0xAA);
	lmk04828_spi_write(device, 0x0172, 0x02);
	lmk04828_spi_write(device, 0x017C, 0x15);
	lmk04828_spi_write(device, 0x017D, 0x33);
	lmk04828_spi_write(device, 0x0166, 0x00);
	lmk04828_spi_write(device, 0x0167, 0x00);
	lmk04828_spi_write(device, 0x0168, 0x0C);
	lmk04828_spi_write(device, 0x0169, 0x59);
	lmk04828_spi_write(device, 0x016A, 0x20);
	lmk04828_spi_write(device, 0x016B, 0x00);
	lmk04828_spi_write(device, 0x016C, 0x00);
	lmk04828_spi_write(device, 0x016D, 0x00);
	lmk04828_spi_write(device, 0x016E, 0x3B);
	lmk04828_spi_write(device, 0x0173, 0x00);
	lmk04828_spi_write(device, 0x0182, 0x00);
	lmk04828_spi_write(device, 0x0183, 0x00);
	lmk04828_spi_write(device, 0x0184, 0x00);
	lmk04828_spi_write(device, 0x0185, 0x00);
	lmk04828_spi_write(device, 0x0188, 0x00);
	lmk04828_spi_write(device, 0x0189, 0x00);
	lmk04828_spi_write(device, 0x018A, 0x00);
	lmk04828_spi_write(device, 0x018B, 0x00);
	lmk04828_spi_write(device, 0x1FFD, 0x00);
	lmk04828_spi_write(device, 0x1FFE, 0x00);
	lmk04828_spi_write(device, 0x1FFF, 0x53);

	int retval = lmk04828_verify_chip_id(device);
	if (retval != 0) {
		printf("SPI is not working \r\n");
		return retval;
	}


	while(lmk04828_check_pll_lock(device)==0){
		usleep(1000000);
	}
	return 0;
}


int32_t lmk04828_initialize_122p88(struct lmk04828_dev *device) {
	lmk04828_spi_write(device, 0x0000, 0x90);
	lmk04828_spi_write(device, 0x0000, 0x10);
	lmk04828_spi_write(device, 0x0002, 0x00);
	lmk04828_spi_write(device, 0x0003, 0x06);
	lmk04828_spi_write(device, 0x0004, 0xD0);
	lmk04828_spi_write(device, 0x0005, 0x5B);
	lmk04828_spi_write(device, 0x0006, 0x00);
	lmk04828_spi_write(device, 0x000C, 0x51);
	lmk04828_spi_write(device, 0x000D, 0x04);
	lmk04828_spi_write(device, 0x0100, 0x18);
	lmk04828_spi_write(device, 0x0101, 0x55);
	lmk04828_spi_write(device, 0x0102, 0x55);
	lmk04828_spi_write(device, 0x0103, 0x00);
	lmk04828_spi_write(device, 0x0104, 0x22);
	lmk04828_spi_write(device, 0x0105, 0x00);
	lmk04828_spi_write(device, 0x0106, 0xF0);
	lmk04828_spi_write(device, 0x0107, 0x55);
	lmk04828_spi_write(device, 0x0108, 0x18);
	lmk04828_spi_write(device, 0x0109, 0x55);
	lmk04828_spi_write(device, 0x010A, 0x55);
	lmk04828_spi_write(device, 0x010B, 0x00);
	lmk04828_spi_write(device, 0x010C, 0x22);
	lmk04828_spi_write(device, 0x010D, 0x00);
	lmk04828_spi_write(device, 0x010E, 0xF0);
	lmk04828_spi_write(device, 0x010F, 0x55);
	lmk04828_spi_write(device, 0x0110, 0x18);
	lmk04828_spi_write(device, 0x0111, 0x55);
	lmk04828_spi_write(device, 0x0112, 0x55);
	lmk04828_spi_write(device, 0x0113, 0x00);
	lmk04828_spi_write(device, 0x0114, 0x02);
	lmk04828_spi_write(device, 0x0115, 0x00);
	lmk04828_spi_write(device, 0x0116, 0xF1);
	lmk04828_spi_write(device, 0x0117, 0x05);
	lmk04828_spi_write(device, 0x0118, 0x18);
	lmk04828_spi_write(device, 0x0119, 0x55);
	lmk04828_spi_write(device, 0x011A, 0x55);
	lmk04828_spi_write(device, 0x011B, 0x00);
	lmk04828_spi_write(device, 0x011C, 0x02);
	lmk04828_spi_write(device, 0x011D, 0x00);
	lmk04828_spi_write(device, 0x011E, 0xF0);
	lmk04828_spi_write(device, 0x011F, 0x15);
	lmk04828_spi_write(device, 0x0120, 0x18);
	lmk04828_spi_write(device, 0x0121, 0x55);
	lmk04828_spi_write(device, 0x0122, 0x55);
	lmk04828_spi_write(device, 0x0123, 0x00);
	lmk04828_spi_write(device, 0x0124, 0x22);
	lmk04828_spi_write(device, 0x0125, 0x00);
	lmk04828_spi_write(device, 0x0126, 0xF1);
	lmk04828_spi_write(device, 0x0127, 0x01);
	lmk04828_spi_write(device, 0x0128, 0x18);
	lmk04828_spi_write(device, 0x0129, 0x55);
	lmk04828_spi_write(device, 0x012A, 0x55);
	lmk04828_spi_write(device, 0x012B, 0x00);
	lmk04828_spi_write(device, 0x012C, 0x02);
	lmk04828_spi_write(device, 0x012D, 0x00);
	lmk04828_spi_write(device, 0x012E, 0xF1);
	lmk04828_spi_write(device, 0x012F, 0x07);
	lmk04828_spi_write(device, 0x0130, 0x18);
	lmk04828_spi_write(device, 0x0131, 0x55);
	lmk04828_spi_write(device, 0x0132, 0x55);
	lmk04828_spi_write(device, 0x0133, 0x00);
	lmk04828_spi_write(device, 0x0134, 0x02);
	lmk04828_spi_write(device, 0x0135, 0x00);
	lmk04828_spi_write(device, 0x0136, 0xF1);
	lmk04828_spi_write(device, 0x0137, 0x07);
	lmk04828_spi_write(device, 0x0138, 0x25);
	lmk04828_spi_write(device, 0x0139, 0x03);
	lmk04828_spi_write(device, 0x013A, 0x0F);
	lmk04828_spi_write(device, 0x013B, 0x00);
	lmk04828_spi_write(device, 0x013C, 0x00);
	lmk04828_spi_write(device, 0x013D, 0x08);
	lmk04828_spi_write(device, 0x013E, 0x00);
	lmk04828_spi_write(device, 0x013F, 0x00);
	lmk04828_spi_write(device, 0x0140, 0x01);
	lmk04828_spi_write(device, 0x0141, 0x00);
	lmk04828_spi_write(device, 0x0142, 0x00);
	lmk04828_spi_write(device, 0x0143, 0x51);
	lmk04828_spi_write(device, 0x0144, 0xFF);
	lmk04828_spi_write(device, 0x0145, 0x7F);
	lmk04828_spi_write(device, 0x0146, 0x3B);
	lmk04828_spi_write(device, 0x0147, 0x0A);
	lmk04828_spi_write(device, 0x0148, 0x00);
	lmk04828_spi_write(device, 0x0149, 0x00);
	lmk04828_spi_write(device, 0x014A, 0x0A);
	lmk04828_spi_write(device, 0x014B, 0x16);
	lmk04828_spi_write(device, 0x014C, 0x00);
	lmk04828_spi_write(device, 0x014D, 0x00);
	lmk04828_spi_write(device, 0x014E, 0xC0);
	lmk04828_spi_write(device, 0x014F, 0x7F);
	lmk04828_spi_write(device, 0x0150, 0x03);
	lmk04828_spi_write(device, 0x0151, 0x02);
	lmk04828_spi_write(device, 0x0152, 0x00);
	lmk04828_spi_write(device, 0x0153, 0x02);
	lmk04828_spi_write(device, 0x0154, 0x71);
	lmk04828_spi_write(device, 0x0155, 0x00);
	lmk04828_spi_write(device, 0x0156, 0x7D);
	lmk04828_spi_write(device, 0x0157, 0x00);
	lmk04828_spi_write(device, 0x0158, 0x7D);
	lmk04828_spi_write(device, 0x0159, 0x03);
	lmk04828_spi_write(device, 0x015A, 0x00);
	lmk04828_spi_write(device, 0x015B, 0xD4);
	lmk04828_spi_write(device, 0x015C, 0x20);
	lmk04828_spi_write(device, 0x015D, 0x00);
	lmk04828_spi_write(device, 0x015E, 0x00);
	lmk04828_spi_write(device, 0x015F, 0x0B);
	lmk04828_spi_write(device, 0x0160, 0x00);
	lmk04828_spi_write(device, 0x0161, 0x01);
	lmk04828_spi_write(device, 0x0162, 0x44);
	lmk04828_spi_write(device, 0x0163, 0x00);
	lmk04828_spi_write(device, 0x0164, 0x00);
	lmk04828_spi_write(device, 0x0165, 0x0C);
	lmk04828_spi_write(device, 0x0171, 0xAA);
	lmk04828_spi_write(device, 0x0172, 0x02);
	lmk04828_spi_write(device, 0x017C, 0x15);
	lmk04828_spi_write(device, 0x017D, 0x33);
	lmk04828_spi_write(device, 0x0166, 0x00);
	lmk04828_spi_write(device, 0x0167, 0x00);
	lmk04828_spi_write(device, 0x0168, 0x0C);
	lmk04828_spi_write(device, 0x0169, 0x59);
	lmk04828_spi_write(device, 0x016A, 0x20);
	lmk04828_spi_write(device, 0x016B, 0x00);
	lmk04828_spi_write(device, 0x016C, 0x00);
	lmk04828_spi_write(device, 0x016D, 0x00);
	lmk04828_spi_write(device, 0x016E, 0x3B);
	lmk04828_spi_write(device, 0x0173, 0x00);
	lmk04828_spi_write(device, 0x0182, 0x00);
	lmk04828_spi_write(device, 0x0183, 0x00);
	lmk04828_spi_write(device, 0x0184, 0x00);
	lmk04828_spi_write(device, 0x0185, 0x00);
	lmk04828_spi_write(device, 0x0188, 0x00);
	lmk04828_spi_write(device, 0x0189, 0x00);
	lmk04828_spi_write(device, 0x018A, 0x00);
	lmk04828_spi_write(device, 0x018B, 0x00);
	lmk04828_spi_write(device, 0x1FFD, 0x00);
	lmk04828_spi_write(device, 0x1FFE, 0x00);
	lmk04828_spi_write(device, 0x1FFF, 0x53);


	int retval = lmk04828_verify_chip_id(device);
	if (retval != 0) {
		printf("SPI is not working \r\n");
		return retval;
	}


	while(lmk04828_check_pll_lock(device)==0){
		usleep(1000000);
	}
	return 0;
}


int32_t lmk04828_set_sysref_req_mode(struct lmk04828_dev *device)
{
	int32_t ret = 0;

	usleep(10000);
	ret = lmk04828_spi_write(device, 0x0143, 0xD1);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0144, 0x00);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0143, 0xF1);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0143, 0xD1);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0144, 0xFF);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0143, 0x51);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0143, 0x50);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x0139, 0x02);
	usleep(10000);
	ret |= lmk04828_spi_write(device, 0x016A, 0x60);

	return ret;
}


/***************************************************************************//**
 *   @file   frequency/lmk04828/lmk04828.h
 *   @brief  Header file of lmk04828 Driver.
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
#ifndef _LMK04828_H_
#define _LMK04828_H_

/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include <stdint.h>
#include <stdbool.h>

// #define SPI_NAME "/dev/spidev0.0"
#define LMK04828_SPI_NAME "/dev/spidev1.0"

/******************************************************************************/
/****************************** lmk04828 ****************************************/
/******************************************************************************/
/* Registers */

struct lmk04828_dev {
	/* SPI */
	int fd_spi;
	uint8_t lmk_chip_id;

};


void lmk04828_remove(struct lmk04828_dev *dev);

int32_t lmk04828_reset(struct lmk04828_dev *dev);

int32_t lmk04828_setup(struct lmk04828_dev *device, const char * file_path, uint8_t chip_id);

int32_t lmk04828_set_base_rate(struct lmk04828_dev *device, double base_rate);

int32_t lmk04828_spi_write(struct lmk04828_dev *dev,
			   uint32_t reg_addr,
			   uint8_t reg_data);

int32_t lmk04828_spi_read(struct lmk04828_dev *dev,
			  uint32_t reg_addr);

int32_t lmk04828_initialize(struct lmk04828_dev *device);
int32_t lmk04828_initialize_clk_in0_10m_outclk_254p76(struct lmk04828_dev *device);
int32_t lmk04828_initialize_122p88(struct lmk04828_dev *device);
int32_t lmk04828_set_sysref_req_mode(struct lmk04828_dev *device);
int32_t lmk04828_verify_chip_id(struct lmk04828_dev *device);
int32_t lmk04828_check_pll_lock(struct lmk04828_dev *device);




int _lmk04828_spi_init(const char * spi_path);
void _lmk04828_spi_exit(int fd_spi);
int _lmk04828_spi_read_reg(int fd_spi, uint32_t reg);

int _lmk04828_spi_write_reg(int fd_spi, uint32_t reg,uint8_t val);

#endif // __lmk04828_H__

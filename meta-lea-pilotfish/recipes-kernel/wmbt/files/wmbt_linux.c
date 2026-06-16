/*
 * Copyright 2016-2023, Cypress Semiconductor Corporation (an Infineon company) or
 * an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
 *
 * This software, including source code, documentation and related
 * materials ("Software") is owned by Cypress Semiconductor Corporation
 * or one of its affiliates ("Cypress") and is protected by and subject to
 * worldwide patent protection (United States and foreign),
 * United States copyright laws and international treaty provisions.
 * Therefore, you may use this Software only as provided in the license
 * agreement accompanying the software package from which you
 * obtained this Software ("EULA").
 * If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
 * non-transferable license to copy, modify, and compile the Software
 * source code solely for use in connection with Cypress's
 * integrated circuit products.  Any reproduction, modification, translation,
 * compilation, or representation of this Software except as specified
 * above is prohibited without the express written permission of Cypress.
 *
 * Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
 * reserves the right to make changes to the Software without notice. Cypress
 * does not assume any liability arising out of the application or use of the
 * Software or any product or circuit described in the Software. Cypress does
 * not authorize its products for use in any products where a malfunction or
 * failure of the Cypress product may reasonably be expected to result in
 * significant property damage, injury or death ("High Risk Product"). By
 * including Cypress's product in a High Risk Product, the manufacturer
 * of such system or application assumes all risk of such use and in doing
 * so agrees to indemnify Cypress against all liability.
 */
 /*****************************************************************************
  *
  *  Name:          wmbt_linux.c
  *
  *  Description:   The WICED Manufacturing Bluetooth test tool (WMBT) is used to test and verify the RF
  *                 performance of the Cypress family of SoC Bluetooth BR/EDR/LE standalone and
  *                 combo devices. Each test sends an WICED HCI command to the device and then waits
  *                 for an WICED HCI Command Complete event from the device.
  *
  *                 For usage description, execute:
  *
  *                 ./wmbt help
  *
  *****************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#define __USE_MISC 1
#include <sys/termios.h>
#include <stdbool.h>

#include <sys/ioctl.h>

static speed_t BaudrateMap[][2] = {
    {57600  , B57600   },
    {115200 , B115200  },
    {230400 , B230400  },
    {460800 , B460800  },
    {500000 , B500000  },
    {576000 , B576000  },
    {921600 , B921600  },
    {1000000, B1000000 },
    {1152000, B1152000 },
    {1500000, B1500000 },
    {2000000, B2000000 },
    {2500000, B2500000 },
    {3000000, B3000000 },
    {3500000, B3500000 },
    {4000000, B4000000 },
};

void init_uart(int uart_fd, int baudRate)
{
    struct termios termios;

    speed_t speed = B115200;

    for (size_t i = 0; i < sizeof(BaudrateMap) / sizeof(BaudrateMap[0]); i++)
    {
        if (BaudrateMap[i][0] == baudRate)
        {
            speed = BaudrateMap[i][1];
            break;
        }
    }

    tcflush(uart_fd, TCIOFLUSH);
    tcgetattr(uart_fd, &termios);

    termios.c_iflag &= (tcflag_t)(~(IGNBRK | BRKINT | PARMRK | ISTRIP
        | INLCR | IGNCR | ICRNL | IXON));
    termios.c_oflag &= (tcflag_t)(~OPOST);
    termios.c_lflag &= (tcflag_t)(~(ECHO | ECHONL | ICANON | ISIG | IEXTEN));
    termios.c_cflag &= (tcflag_t)(~(CSIZE | PARENB));
    termios.c_cflag |= (tcflag_t)CS8;
    termios.c_cflag |= (tcflag_t)(CRTSCTS);

    tcsetattr(uart_fd, TCSANOW, &termios);
    tcflush(uart_fd, TCIOFLUSH);
    tcsetattr(uart_fd, TCSANOW, &termios);
    tcflush(uart_fd, TCIOFLUSH);
    tcflush(uart_fd, TCIOFLUSH);
    cfsetospeed(&termios, speed);
    cfsetispeed(&termios, speed);
    tcsetattr(uart_fd, TCSANOW, &termios);
}

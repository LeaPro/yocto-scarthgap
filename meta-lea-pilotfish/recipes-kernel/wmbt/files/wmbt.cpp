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
 // wmbt.cpp : Defines the entry point for the console application.
 //
#include <stdio.h>

#include "common/wmbt_uart.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <thread>
#include <unistd.h>

BOOL SendHCIReset(ComHelper* p_port);
BOOL execute_download_hcd(ComHelper* p_port, const char* pathname, const char* minidrv);

char port_num[256];
void OpenPortError(const char* port_num) { printf("Open %s port Failed\n", port_num); }
int _stricmp(const char* s1, const char* s2) { return strcmp(s1, s2); }
#define TRANSPORT "/dev/ttyUSBx"

typedef int(*command_function_t) (const char* argv[]);
typedef void(*command_usage_t)    (bool full);

typedef struct
{
    char* command_name;
    command_function_t command_function;
    int                arg_count;
    command_usage_t    command_usage;
} command_table_t;

UINT8 in_buffer[1024];
int baud_rate = 115200;
int download_baudrate = 115200;//It is not recommended to upgrade programming baudrate.

//
// print hexadecimal digits of an array of bytes formatted as:
// 0000 < 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F >
// 0010 < 10 11 12 13 14 15 16 1718 19 1A 1B 1C 1D 1E 1F >
//
void HexDump(LPBYTE p, DWORD dwLen)
{
    for (DWORD i = 0; i < dwLen; ++i)
    {
        if (i % 16 == 0)
            printf("%04X <", i);
        printf(" %02X", p[i]);
        if ((i + 1) % 16 == 0)
            printf(" >\n");
    }
    printf(" >\n");
}

BOOL send_hci_command(ComHelper* p_port, LPBYTE cmd, DWORD cmd_len, LPBYTE expected_evt, DWORD evt_len, BOOL reopen, BOOL compare)
{
    /* Toggle COM port to get around issue caused by some sample applications
     * that send the Device Started Event message once the transport interface
     * has completed initialization
     */
    if (reopen)
    {
        printf("Attempting to toggle COM port\n");
        p_port->ClosePort();
        if (!p_port->OpenPort(port_num, baud_rate))
        {
            OpenPortError(port_num);
            return FALSE;
        }
        sleep(1);
        printf("Re-Opened COM port successfully!\n");
    }
    if (cmd)
    {
        // write HCI Command
        printf("Sending HCI Command:\n");
        HexDump(cmd, cmd_len);
        p_port->Write(cmd, cmd_len);
    }

    if (!expected_evt || evt_len == 0)
    {
        return TRUE;
    }
    // read HCI response header
    DWORD dwRead = p_port->Read((LPBYTE)&in_buffer[0], 3);

    // read HCI response payload
    if (dwRead == 3 && in_buffer[2] > 0)
        dwRead += p_port->Read((LPBYTE)&in_buffer[3], in_buffer[2]);

    printf("Received HCI Event:\n");
    HexDump(in_buffer, dwRead);

    if (!compare)
    {
        if (dwRead <= evt_len)
        {
            memset(expected_evt, 0, evt_len);
            memcpy(expected_evt, in_buffer, dwRead);
            printf("Success %d bytes.\n", dwRead);
            return TRUE;
        }
        else
        {
            printf("Outbuf is too small %d < %d.\n", evt_len, dwRead);
            return FALSE;
        }
    }
    else if (dwRead == evt_len)
    {
        if (memcmp(in_buffer, expected_evt, evt_len) == 0)
        {
            return TRUE;
        }
        else
        {
            printf("Expected HCI Event:\n");
            HexDump(expected_evt, evt_len);
        }
    }

    printf("send_hci_command and compare failed.\n");
    return FALSE;
}

static void print_usage_reset(bool full)
{
    printf("Usage: wmbt reset %s\n", TRANSPORT);
    printf("       NOTE: Sends HCI_RESET at 115200\n");
}

static int execute_reset(ComHelper* p_port)
{
    BOOL res;

    if (p_port == NULL)
    {
        p_port = new ComHelper;
        if (!p_port->OpenPort(port_num, baud_rate))
        {
            OpenPortError(port_num);
            delete p_port;
            return 0;
        }
    }

    res = SendHCIReset(p_port);

    delete p_port;

    return res;
}

static int execute_reset_indirect(const char* argv[])
{
    return execute_reset(NULL);
}

static void print_usage_download(bool full)
{
    printf("Usage: wmbt download %s <minidriver_hcd_pathname> <application_hcd_pathname>\n", TRANSPORT);
}

static int execute_download(const char* argv[])
{

    ComHelper SerialPort;
    const char* hcdfile_minidrv = argv[0];
    const char* hcifile_app = argv[1];

    if (!SerialPort.OpenPort(port_num, baud_rate))
    {
        OpenPortError(port_num);
        return 0;
    }

    usleep(10000);

    return execute_download_hcd(&SerialPort, hcifile_app, hcdfile_minidrv);
}

static int print_help(const char* argv[])
{
    printf("Usage: wmbt help\n");
    print_usage_download(false);
    print_usage_reset(false);
    return TRUE;
}


/* Command Table */
command_table_t wmbt_command_table[] =
{
    /*        Command Name                      Command Execution Function              # of args    Helper Function*/
    { (char*)"help",                           print_help,                             0,           NULL                                      },
    { (char*)"reset",                          execute_reset_indirect,                 0,           print_usage_reset                         },
    { (char*)"download",                       execute_download,                       2,           print_usage_download                      },
};

/* MAIN */
int main(int argc, const char** argv)
{
    command_function_t command_function = NULL;
    UINT32 command_table_size = sizeof(wmbt_command_table) / sizeof(command_table_t);

    // If not enough input args, print help
    if (argc < 2)
    {
        print_help(NULL);
        return 0;
    }

    if (argc >= 3)
        strcpy(port_num, argv[2]);

    // Find the given command in the command_table
    for (UINT32 i = 0; i < command_table_size; i++)
    {
        if (_stricmp(argv[1], wmbt_command_table[i].command_name) == 0)
        {
            if (i == 0) // help is the only command that does not use the COM port, no need to check args
            {
                print_help(NULL);
                return 0;
            }
            else if ((argc - 3) != wmbt_command_table[i].arg_count) // Check input argument count
            {
                printf("ERROR: Input arg mismatch!\n\n");
                wmbt_command_table[i].command_usage(TRUE);
                return 0;
            }
            else if (port_num == 0) // Validate COM port
            {
                printf("ERROR: Please specify the COM port correctly.\n\n");
                wmbt_command_table[i].command_usage(TRUE);
                return 0;
            }

            command_function = wmbt_command_table[i].command_function;

            break;
        }
    }

    // If the command was not found, print the help message
    if (command_function == NULL)
    {
        print_help(NULL);
        return 0;
    }

    // Execute command
    command_function(&argv[3]);

    return 0;
}

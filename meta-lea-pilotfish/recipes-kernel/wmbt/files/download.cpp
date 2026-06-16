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
 // download.cpp : Demonstrate how to program application firmware into CYW20820A1.
 //
#include <stdio.h>

#include "common/wmbt_uart.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#define __USE_MISC 1
#include <sys/termios.h>
#include <stdbool.h>

extern char port_num[256];
extern int baud_rate;
extern int download_baudrate;

#define WHEX_MAX_PAYLOAD_SIZE 0xFB
typedef struct _BLOCK_CRC
{
    UINT32 StartAddr;
    UINT32 Size;
    UINT32 Crc;
}BLOCK_CRC, * PBLOCK_CRC;

#define RESET_BLOCK_CRC(_pblock, _startAddr) do {\
            memset((_pblock), 0, sizeof(BLOCK_CRC));\
            (_pblock)->StartAddr = _startAddr;\
            }while(0);

UINT32 CalculateCrc32(UINT32 crc, LPBYTE buf, UINT32 len);
void OpenPortError(const char* port_num);
void HexDump(LPBYTE p, DWORD dwLen);

BOOL send_hci_command(ComHelper* p_port, LPBYTE cmd, DWORD cmd_len, LPBYTE expected_evt, DWORD evt_len, BOOL reopen = FALSE, BOOL compare = TRUE);

BOOL SendHCIReset(ComHelper* p_port)
{
    UINT8 hci_reset[] = { 0x01, 0x03, 0x0c, 0x00 };
    UINT8 hci_reset_cmd_complete_event[] = { 0x04, 0x0e, 0x04, 0x01, 0x03, 0x0c, 0x00 };

    return send_hci_command(p_port, hci_reset, sizeof(hci_reset), hci_reset_cmd_complete_event, sizeof(hci_reset_cmd_complete_event), TRUE);
}

BOOL SendDownloadMinidriver(ComHelper* p_port)
{
    BYTE arHciCommandTx[] = { 0x01, 0x2E, 0xFC, 0x00 };
    BYTE arBytesExpectedRx[] = { 0x04, 0x0E, 0x04, 0x01, 0x2E, 0xFC, 0x00 };
    /*todo: If there is no reponse of this command, please ignore it and continue*/
    return (send_hci_command(p_port, arHciCommandTx, sizeof(arHciCommandTx), arBytesExpectedRx, sizeof(arBytesExpectedRx)));
}

BOOL SetBaudRate(ComHelper* p_port, int nBaudRate, bool update)
{
    p_port->ClosePort();

    p_port->OpenPort(port_num, nBaudRate);

    return (TRUE);
}

BOOL SendHcdRecord(ComHelper* p_port, UINT32 nAddr, UINT32 nHCDRecSize, LPBYTE arHCDDataBuffer)
{
    BYTE arHciCommandTx[261] = { 0x01, 0x4C, 0xFC, 0x00 };
    BYTE arBytesExpectedRx[] = { 0x04, 0x0E, 0x04, 0x01, 0x4C, 0xFC, 0x00 };

    arHciCommandTx[3] = (BYTE)(4 + nHCDRecSize);
    arHciCommandTx[4] = (BYTE)((nAddr & 0xff));
    arHciCommandTx[5] = (BYTE)((nAddr >> 8) & 0xff);
    arHciCommandTx[6] = (BYTE)((nAddr >> 16) & 0xff);
    arHciCommandTx[7] = (BYTE)((nAddr >> 24) & 0xff);
    memcpy(&arHciCommandTx[8], arHCDDataBuffer, nHCDRecSize);

    printf("sending record at:0x%x\n", nAddr);
    return (send_hci_command(p_port, arHciCommandTx, 4 + 4 + nHCDRecSize, arBytesExpectedRx, sizeof(arBytesExpectedRx)));
}

BOOL ReadNextHCDRecord(FILE* fHCD, UINT32* nAddr, UINT32* nHCDRecSize, LPBYTE arHCDDataBuffer, BOOL* bIsLaunch)
{
    const   int HCD_LAUNCH_COMMAND = 0x4E;
    const   int HCD_WRITE_COMMAND = 0x4C;
    const   int HCD_COMMAND_BYTE2 = 0xFC;

    BYTE     arRecHeader[3];
    BYTE     byRecLen;
    BYTE     arAddress[4];

    *bIsLaunch = FALSE;

    if (fread(arRecHeader, 1, 3, fHCD) != 3)               // Unexpected EOF
        return false;

    byRecLen = arRecHeader[2];

    if ((byRecLen < 4) || (arRecHeader[1] != HCD_COMMAND_BYTE2) ||
        ((arRecHeader[0] != HCD_WRITE_COMMAND) && (arRecHeader[0] != HCD_LAUNCH_COMMAND)))
    {
        printf("Wrong HCD file format trying to read the command information\n");
        return FALSE;
    }

    if (fread(arAddress, sizeof(arAddress), 1, fHCD) != 1)      // Unexpected EOF
    {
        printf("Wrong HCD file format trying to read 32-bit address\n");
        return FALSE;
    }

    *nAddr = arAddress[0] + (arAddress[1] << 8) + (arAddress[2] << 16) + (arAddress[3] << 24);

    *bIsLaunch = (arRecHeader[0] == HCD_LAUNCH_COMMAND);

    *nHCDRecSize = byRecLen - 4;

    if (*nHCDRecSize > 0)
    {
        if (fread(arHCDDataBuffer, 1, *nHCDRecSize, fHCD) != *nHCDRecSize)   // Unexpected EOF
        {
            printf("Not enough HCD data bytes in record\n");
            return FALSE;
        }
    }

    return TRUE;
}

BOOL SendLaunchRamAddr(ComHelper* p_port, UINT32 address)
{
    BYTE arHciCommandTx[] = { 0x01, 0x4E, 0xFC, 0x04, 0x00, 0x00, 0x22, 0x00 };
    BYTE arBytesExpectedRx[] = { 0x04, 0x0E, 0x04, 0x01, 0x4E, 0xFC, 0x00 };

    arHciCommandTx[4] = (BYTE)(address & 0xff);
    arHciCommandTx[5] = (BYTE)((address >> 8) & 0xff);
    arHciCommandTx[6] = (BYTE)((address >> 16) & 0xff);
    arHciCommandTx[7] = (BYTE)((address >> 24) & 0xff);

    return (send_hci_command(p_port, arHciCommandTx, sizeof(arHciCommandTx), arBytesExpectedRx, sizeof(arBytesExpectedRx)));
}

BOOL SendChipErase(ComHelper* p_port, UINT32 address)
{
	BYTE arHciCommandTx[] = { 0x01, 0xCE, 0xFF, 0x04, 0xEF, 0xEE, 0xBE, 0xFC };
    BYTE arBytesExpectedRxTmpl[] = { 0x04, 0x0E, 0x04, 0x01, 0xCE, 0xFF, 0x00 };
	BYTE arEventBytes[7] = { 0, };
    BYTE arChipEraseInProgressEvt[] = { 0x04, 0xFF, 0x01, 0xCE };
    arHciCommandTx[4] = (BYTE)(address & 0xff);
    arHciCommandTx[5] = (BYTE)((address >> 8) & 0xff);
    arHciCommandTx[6] = (BYTE)((address >> 16) & 0xff);
    arHciCommandTx[7] = (BYTE)((address >> 24) & 0xff);

    printf("Executing -- erasing chip\n");

    BOOL ret = send_hci_command(p_port, arHciCommandTx, sizeof(arHciCommandTx), arEventBytes, sizeof(arEventBytes), FALSE, FALSE);
    printf("erase command return %d\n", ret);
    while (ret)
    {
        if (!memcmp(arEventBytes, arChipEraseInProgressEvt, sizeof(arChipEraseInProgressEvt)))
        {
            printf("Chip erase in progress...\n");
        }
        else if (!memcmp(arEventBytes, arBytesExpectedRxTmpl, sizeof(arBytesExpectedRxTmpl)))
        {
            return TRUE;
        }

        memset(arEventBytes, 0, sizeof(arEventBytes));

        ret = send_hci_command(p_port, NULL, 0, arEventBytes, sizeof(arEventBytes), FALSE, FALSE);
    }

    return ret;
}

BOOL SendUpdateBaudRate(ComHelper* p_port, int newBaudRate)
{
    BYTE arHciCommandTx[] = { 0x01, 0x18, 0xFC, 0x06, 0x00, 0x00, 0xAA, 0xAA, 0xAA, 0xAA };
    BYTE arBytesExpectedRx[] = { 0x04, 0x0E, 0x04, 0x01, 0x18, 0xFC, 0x00 };

    arHciCommandTx[6] = (BYTE)(newBaudRate & 0xff);
    arHciCommandTx[7] = (BYTE)((newBaudRate >> 8) & 0xff);
    arHciCommandTx[8] = (BYTE)((newBaudRate >> 16) & 0xff);
    arHciCommandTx[9] = (BYTE)((newBaudRate >> 24) & 0xff);

    return (send_hci_command(p_port, arHciCommandTx, sizeof(arHciCommandTx), arBytesExpectedRx, sizeof(arBytesExpectedRx)));
}

BOOL VerifyCRC(ComHelper* p_port, PBLOCK_CRC pBlockCrc)
{
    printf("VerifyCRC  checking %d bytes starting at 0x%08X     Expecting CRC value 0x%08X\n",
        pBlockCrc->Size, pBlockCrc->StartAddr, pBlockCrc->Crc);

    BYTE arHciCommandTx[12] = { 0x01, 0xCC, 0xFC, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    BYTE arBytesExpectedRx[11] = { 0x04, 0x0E, 0x08, 0x01, 0xCC, 0xFC, 0x00, 0x00, 0x00, 0x00, 0x00 };

    //Start address
    arHciCommandTx[4] = (BYTE)(pBlockCrc->StartAddr & 0xff);
    arHciCommandTx[5] = (BYTE)((pBlockCrc->StartAddr >> 8) & 0xff);
    arHciCommandTx[6] = (BYTE)((pBlockCrc->StartAddr >> 16) & 0xff);
    arHciCommandTx[7] = (BYTE)((pBlockCrc->StartAddr >> 24) & 0xff);

    //Size
    arHciCommandTx[8] = (BYTE)(pBlockCrc->Size & 0xff);
    arHciCommandTx[9] = (BYTE)((pBlockCrc->Size >> 8) & 0xff);
    arHciCommandTx[10] = (BYTE)((pBlockCrc->Size >> 16) & 0xff);
    arHciCommandTx[11] = (BYTE)((pBlockCrc->Size >> 24) & 0xff);

    //Excepted CRC data
    arBytesExpectedRx[7] = (BYTE)(pBlockCrc->Crc & 0xff);
    arBytesExpectedRx[8] = (BYTE)((pBlockCrc->Crc >> 8) & 0xff);
    arBytesExpectedRx[9] = (BYTE)((pBlockCrc->Crc >> 16) & 0xff);
    arBytesExpectedRx[10] = (BYTE)((pBlockCrc->Crc >> 24) & 0xff);

    if (send_hci_command(p_port, arHciCommandTx, sizeof(arHciCommandTx), arBytesExpectedRx, sizeof(arBytesExpectedRx), FALSE, FALSE))
    {
        printf("Verify CRC data successfully. FW return 0x%08X.\n", * ((UINT32*)(arBytesExpectedRx + 7)));
        return TRUE;
    }

    printf("Failed to verify CRC data. FW return 0x%08X.\n", * ((UINT32*)(arBytesExpectedRx + 7)));

    return FALSE;
}

BOOL CalcCRC(ComHelper* p_port, UINT32 address, UINT32 size, LPBYTE data)
{
    static int SectionID = -1;
    static BLOCK_CRC blockCrc = { 0, };

    UINT32 nextAddr = blockCrc.StartAddr + blockCrc.Size;

    if (nextAddr != address)
    {
        if (blockCrc.Size)
        {
            printf("Verify Section[%d] [0x%08X, 0x%08X]\n", SectionID, blockCrc.StartAddr, blockCrc.StartAddr + blockCrc.Size - 1);
            if (!VerifyCRC(p_port, &blockCrc))
                return FALSE;
        }
        if (!size)
            return TRUE;
        RESET_BLOCK_CRC(&blockCrc, address);
        SectionID++;
        printf("Section[%d]: start 0x%08X\n", SectionID, address);
    }

    if (size)
    {
        printf("Section[%d]: queue %d bytes\n", SectionID, size);
        blockCrc.Crc = CalculateCrc32(blockCrc.Crc, data, size);
        blockCrc.Size += size;
    }

    return TRUE;
}

BOOL execute_download_hcd(ComHelper* p_port, const char* pathname, const char* minidrv)
{
    FILE* fMiniDrvHCD = NULL;
    FILE* fHCD = NULL;
    UINT32 nAddr, nHCDRecSize;
    BYTE  arHCDDataBuffer[256];
    BOOL  bIsLaunch = FALSE;
    BOOL  ret = 0;

    if (!p_port)
        return 0;
    do {
        fHCD = fopen(pathname, "rb");
        if (!fHCD)
        {
            printf("Failed to open HCD file %s", pathname);
            break;
        }

        fMiniDrvHCD = fopen(minidrv, "rb");
        if (!fMiniDrvHCD)
        {
            printf("Failed to open Minidriver HCD file %s", minidrv);
            break;
        }

        if (!SendHCIReset(p_port))
        {
            printf("Failed to HCI Reset\n");
            break;
        }

        printf("HCI Reset success\n");

        if (download_baudrate != baud_rate)
        {
            if (!SendUpdateBaudRate(p_port, download_baudrate))
            {
                printf("Failed to send update baud rate\n");
                break;
            }
            p_port->ClosePort();
            baud_rate = download_baudrate;
            p_port->OpenPort(port_num, baud_rate);
            printf("Set Baud Rate to %d success\n", download_baudrate);
        }
        if (!SendDownloadMinidriver(p_port))
        {
            printf("Failed to send download minidriver\n");
            break;
        }

        printf("Download minidriver command success, downloading minidriver...\n");

        while (ReadNextHCDRecord(fMiniDrvHCD, &nAddr, &nHCDRecSize, arHCDDataBuffer, &bIsLaunch))
        {
            if (bIsLaunch)
            {
                if (!SendLaunchRamAddr(p_port, nAddr))
                {
                    printf("Failed to launch Minidriver\n");
                }
                else
                {
                    ret = 1;
                    printf("Launch minidriver success\n");
                }
                break;
            }
            else if (!SendHcdRecord(p_port, nAddr, nHCDRecSize, arHCDDataBuffer))
            {
                printf("Failed to send hcd portion at %x\n", nAddr);
                break;
            }
        }
        if (!ret)
            break;
        ret = 0;

        printf("Download minidriver success, chip erasing...\n");

        if (!SendChipErase(p_port, 0xFF000000))
        {
            printf("Failed to erase chip\n");
            break;
        }

        printf("Chip erased, downloading configuration...\n");

        while (ReadNextHCDRecord(fHCD, &nAddr, &nHCDRecSize, arHCDDataBuffer, &bIsLaunch))
        {
            if (bIsLaunch) {
                if (!CalcCRC(p_port, 0, 0, 0))
                {
                    printf("CRC error\n");
                    ret = 0;
                    break;
                }
                if (!SendLaunchRamAddr(p_port, nAddr))
                {
                    printf("Failed to send launch application\n");
                }
                else
                {
                    ret = 1;
                    printf("Launch application success\n");
                }
                break;
            }
            if (!SendHcdRecord(p_port, nAddr, nHCDRecSize, arHCDDataBuffer))
            {
                printf("Failed to send hcd portion at %x\n", nAddr);
                ret = 0;
                break;
            }

            if (!CalcCRC(p_port, nAddr, nHCDRecSize, arHCDDataBuffer))
            {
                printf("CRC error\n");
                ret = 0;
                break;
            }
        }
        if (!ret)
            break;

        printf("Download configuration success\n");
    } while (0);
    if (fHCD)
        fclose(fHCD);
    if (fMiniDrvHCD)
        fclose(fMiniDrvHCD);
    p_port->ClosePort();

    return ret;
}

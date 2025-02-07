/******************************************************************************

 @file     SDDPStatus.h
 @brief    ...
 @section  Platforms Platform(s)
            All
            
Copyright 2017 Control4 Corporation. All rights reserved.

This software is owned by Control4 Corporation and/or its  licensors and is 
protected by applicable copyright laws. The software may only be used, 
duplicated, modified or distributed pursuant to the terms and conditions of a 
separate, written license agreement executed between you and Control4 (an 
"Authorized License"). Except as set forth in an Authorized License, Control4 
grants no license (express or implied), right to use, or waiver of any kind 
with respect to the software, and Control4 expressly reserves all rights in 
and to the software and all intellectual property rights therein. 

IF YOU HAVE NO AUTHORIZED LICENSE, THEN YOU HAVE NO RIGHT TO USE THIS SOFTWARE 
IN ANY WAY, AND SHOULD IMMEDIATELY NOTIFY CONTROL4 AND DISCONTINUE ALL USE OF 
THE SOFTWARE. 

You may not combine this software with open-source software in order to form a 
larger program in such a way as to subject  any software to such open source 
license.

            
            
******************************************************************************/
#ifndef _SDDP_STATUS_H_
#define _SDDP_STATUS_H_

#ifdef __cplusplus
extern "C" {
#endif

///////////////////////////////////////
// Includes
///////////////////////////////////////


///////////////////////////////////////
// Defines
///////////////////////////////////////


///////////////////////////////////////
// Typedefs
///////////////////////////////////////
/******************************************************************************
 @enum     SDDPStatus
           SDDP status codes:        
           SDDP_STATUS_SUCCESS - success
           SDDP_STATUS_FATAL_ERROR - global error
           SDDP_STATUS_INVALID_PARAM - invalid parameter or state data provided
           SDDP_STATUS_NETWORK_ERROR - network interface problem
           SDDP_STATUS_TIME_ERROR - time not implemented          
******************************************************************************/
typedef enum 
{
    SDDP_STATUS_SUCCESS         =  0,
    SDDP_STATUS_FATAL_ERROR     = -1,
    SDDP_STATUS_INVALID_PARAM   = -2,
    SDDP_STATUS_NETWORK_ERROR   = -3,
    SDDP_STATUS_TIME_ERROR      = -4,
    SDDP_STATUS_UNINITIALIZED   = -5,
} SDDPStatus;


///////////////////////////////////////
// Functions
///////////////////////////////////////


#ifdef __cplusplus
}
#endif
#endif

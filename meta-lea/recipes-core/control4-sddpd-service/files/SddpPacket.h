/****************************************************************************
Copyright 2017 Corporation. All rights reserved.

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
*****************************************************************************/


#ifndef _SDDP_PACKET_H_
#define _SDDP_PACKET_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef enum
{
	SddpPacketUnknown = 0,
	SddpPacketRequest,
	SddpPacketResponse
} SddpPacketType;

typedef struct
{
	SddpPacketType packet_type;
	union
	{
		struct
		{
			char *method;
			char *argument;
			char *version;
		} request;
		struct
		{
			char *status_code;
			char *reason;
			char *version;
		} response;
	} h;
	
	char *from;
	char *host;
	char *tran;
	char *max_age;
	char *timeout;
	char *primary_proxy;
	char *proxies;
	char *manufacturer;
	char *model;
	char *driver;
	char *config_url;
	char *type;
	
	char *body;
} SddpPacket;

void BuildSDDPResponse(SddpPacket *packet, char *version, char *statusCode, char *reason);
void BuildSDDPRequest(SddpPacket *packet, char *version, char *method, char *argument);
SddpPacket *ParseSDDPPacket(const char *packet);
void FreeSDDPPacket(SddpPacket *packet);
size_t WriteSDDPPacket(const SddpPacket *packet, char *buffer, size_t bufferSize);

#ifdef __cplusplus
}
#endif

#endif

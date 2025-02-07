/******************************************************************************

  @file     SddpServer.c
  @brief    Provides an example SDDP application

Copyright 2020 Wirepath Home Systems, LLC. All rights reserved.

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


  @section  Platform Platform(s)
      Linux
  @section  Detail Detail
            This application demonstrations the usage of SDDP APIs provided
            by sddp.c/h. This file is intended to be utilized on linux
            platforms but can be ported to others, or provide a good starting
            point for an example. 
            
            Use the '-n' commandline option to run in the foreground (no daemon),
            or no commandline options to start as daemon. '-h' will provide
            usage. 

******************************************************************************/
///////////////////////////////////////
// Includes
///////////////////////////////////////
#include <sys/stat.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <syslog.h>
#include <ctype.h>
#include <dirent.h>
#include <time.h>

#include "Sddp.h"

///////////////////////////////////////
// Defines
///////////////////////////////////////
#define DAEMON_NAME    		"sddpd"
#define CONFIG_FILE		"/etc/sddpd.conf"
#define CONFIG_DIR		"/etc/sddpd.d"
#define CONFIG_EXT		".conf"


///////////////////////////////////////
// Typedefs
///////////////////////////////////////


///////////////////////////////////////
// Variables
///////////////////////////////////////
static volatile int identify_signal = 0;
static volatile int refresh_signal = 0;
static volatile sig_atomic_t restart_signal = 0;
static volatile int termination_signal = 0;
static char config_dir[256] = CONFIG_DIR;

///////////////////////////////////////
// Function Prototypes
///////////////////////////////////////
static int HandleArgs(int argc, char *argv[], const SDDPHandle handle);
static void SignalHandler(int iSignal);
static void daemonize();
static void PrintUsage(int argc, char *argv[]);
static int ReadSddpConfig(const SDDPHandle handle, int index, const char *configFile);
static bool parseBool(const char *str);
static char *trimRight(char *str, char *end);
static char *skipWhitespace(char *str);
static int LoadConfig(const SDDPHandle handle, int index, const char *configFile);
static int LoadConfigDir(const SDDPHandle handle, const char *configDir);

/*****************************************************************************

 Function Name: main

 Description: Program entry

 Parameters:  argc - Standard argument count
        argv - Standard argument array

 Returns:     int status code

*****************************************************************************/
int main(int argc, char *argv[])
{
  SDDPHandle handle;
  char host[MAX_HOST_SIZE];
  int daemon;

        struct timespec default_delay, error_delay;
        default_delay.tv_sec = 0;
        default_delay.tv_nsec = 100000000;

        error_delay.tv_sec = 2;
        error_delay.tv_nsec = 0;

  // Setup logging
    openlog(DAEMON_NAME, LOG_CONS | LOG_PID, LOG_LOCAL0);

  // Set up SDDP library
  SDDPInit(&handle);

    // Handle command line arguments, load config files as needed
  daemon = HandleArgs(argc, argv, handle);

  // daemonize if required, daemonize will cause the starting process to
  // exit and the child will continue below
  if (daemon)
    daemonize();

  // Setup signal handling. USR1 sends IDENTIFY message
  signal(SIGTERM, SignalHandler);
  signal(SIGUSR1, SignalHandler);
  signal(SIGUSR2, SignalHandler);
  signal(SIGHUP, SignalHandler);

  if(SDDPGetUniqueHostName(handle, host, MAX_HOST_SIZE) == SDDP_STATUS_SUCCESS)
    SDDPSetHost(handle, host);
  else
    SDDPSetHost(handle, "unknown");

  syslog(LOG_INFO, "Device Host %s", host);

  // Start up SDDP
  if (SDDPStart(handle) != SDDP_STATUS_SUCCESS)
            restart_signal = 1;

  // Run SDDP loop
  while(!termination_signal)
  {
            if(restart_signal)
            {
                restart_signal = 0;

                // restart

                // Shutdown and free memory
                SDDPShutdown(&handle);

                syslog(LOG_INFO, "Restarting %s", argv[0]);

                // Re initialize
                SDDPInit(&handle);

                // HandleArgs also does initialization so it must be done again
                // we don't care about daemon here since we are in the loop
                daemon = HandleArgs(argc, argv, handle);

                if(SDDPGetUniqueHostName(handle, host, MAX_HOST_SIZE) == SDDP_STATUS_SUCCESS)
                    SDDPSetHost(handle, host);
                else
                    SDDPSetHost(handle, "unknown");

                // And now we start and continue the loop
                syslog(LOG_INFO, "Device Host %s", host);
                if (SDDPStart(handle) != SDDP_STATUS_SUCCESS)
                    restart_signal = 1;
            }
            else
            {
                // Call SDDP tick to process incoming and outgoing SDDP messages
                SDDPTick(handle, 0);

                if (identify_signal)
                {
                    // Send identify
                    syslog(LOG_INFO, "Sending SDDP identify");

                    SDDPIdentify(handle);

                    identify_signal = 0;
                }
                else if (refresh_signal)
                {
                    if(SDDPGetUniqueHostName(handle, host, MAX_HOST_SIZE) == SDDP_STATUS_SUCCESS)
                        SDDPSetHost(handle, host);
                    else
                        SDDPSetHost(handle, "unknown");

                    syslog(LOG_INFO, "Device Host %s", host);

                    SDDPTick(handle, 1); // Force alive messages

                    refresh_signal = 0;
                }
            }

            if (restart_signal)
                nanosleep(&error_delay, NULL);
            else
                nanosleep(&default_delay, NULL);
  }

  // Shutdown SDDP
  SDDPShutdown(&handle);

  // Cleanup
  closelog();
  exit(EXIT_SUCCESS);

} // End of main

/*****************************************************************************

 Function Name: HandleArgs

 Description: Handles command line arguments

 Parameters:  argc - Standard argument count
        argv - Standard argument array
        handle - SDDP API handle

 Returns:     1 if we should run as daemon

*****************************************************************************/
int HandleArgs(int argc, char *argv[], const SDDPHandle handle)
{
  int daemon = 0, hasConfig = 0, hasConfDir = 0;

  #ifndef NO_GETOPT_HACK // this part not working under yocto-hardknott; hacking around it for now...
  // Check provided arguments
  char c;
  while((c = getopt(argc, argv, "nhc:d:|help")) != -1)
  {
    switch(c)
    {
            case 'h':
                PrintUsage(argc, argv);
                exit(EXIT_SUCCESS);
                break;
        
            case 'n':
                daemon = 0;
                break;
            
            case 'c':
                if (!LoadConfig(handle, 0, optarg))
                {
                    exit(EXIT_FAILURE);
                }
                hasConfig++;
                break;
            case 'd':
                if (hasConfDir)
                {
                    fprintf(stderr, "Only one config file allowed\n");
                    exit(EXIT_FAILURE);
                }
                else if (strlen(optarg) >= sizeof(config_dir))
                {
                    fprintf(stderr, "Invalid config directory\n");
                    exit(EXIT_FAILURE);
                }
                strcpy(config_dir, optarg);
                hasConfDir = 1;
                break;
            default:
                PrintUsage(argc, argv);
                exit(EXIT_SUCCESS);
                break;
        }
    }
  #endif
  
  if (hasConfig == 0)
  {
    if (!hasConfDir && LoadConfig(handle, 0, CONFIG_FILE))
    {
      hasConfig++;
    }
    else
    {
      hasConfig = LoadConfigDir(handle, config_dir);
      if (hasConfig == 0)
        exit(EXIT_FAILURE);
    }
  }

  return daemon;
}

void daemonize()
{
  pid_t pid, sid;

  syslog(LOG_INFO, "Daemonizing");
  // Fork off the parent process
  pid = fork();
  if (pid < 0)
  {
    exit(EXIT_FAILURE);
  }

  // If we got a good PID, then exit the parent process
  if (pid > 0)
  {
    exit(EXIT_SUCCESS);
  }

  // Change the file mode mask
  umask(0);

  // Create a new SID for the child process
  sid = setsid();
  if (sid < 0)
  {
    exit(EXIT_FAILURE);
  }

  // Change the current working directory
  if ((chdir("/")) < 0)
  {
    exit(EXIT_FAILURE);
  }
}

/*****************************************************************************

 Function Name: SignalHandler

 Description: Handles signals

 Parameters:  iSignal - signal

 Returns:     void

*****************************************************************************/
static void SignalHandler(int iSignal)
{
  if (iSignal == SIGUSR1)
  {
    syslog(LOG_INFO, "Received button push event signal");
    
    identify_signal = 1;
  }
  else if (iSignal == SIGUSR2)
  {
      syslog(LOG_INFO, "Received reload signal");

      refresh_signal = 1;
  }
  else if (iSignal == SIGHUP)
  {
    // syslog is not async safe and must not be called here
    restart_signal = 1;
  }
  else if (iSignal == SIGTERM || iSignal == SIGINT)
  {
    if (!termination_signal)
    {
      termination_signal = 1;
      syslog(LOG_INFO, "Terminating...");
    }
  }
}

/*****************************************************************************

 Function Name: PrintUsage

 Description: Prints comandline options

 Parameters:  argc - Standard argument count
        argv - Standard argument array

 Returns:     void

*****************************************************************************/
static void PrintUsage(int argc, char *argv[]) 
{
    if (argc >=1) 
  {
        printf("Usage: %s -n\n", argv[0]);
        printf("  Options:\n");
        printf("      -n\tDon't start as daemon\n");
        printf("      -c FILE\tLoad the config file FILE.  If this argument is not specified, \n");
        printf("             \tit defaults to %s\n", CONFIG_FILE);
        printf("      -d DIR\tLoad all configuration files in directory DIR.  Configuration \n");
        printf("            \tfiles must have the extension %s.  If this argument is not \n", CONFIG_EXT);
        printf("            \tspecified, it defaults to %s\n", CONFIG_DIR);
    }
}

/*****************************************************************************

 Function Name: ReadSddpConfig

 Description: Reads the configuration file

 Parameters:  handle - the SDDP API handle
              index - device index (usually 0)
              configFile - File name of the configuration file

 Returns:     int

*****************************************************************************/
int ReadSddpConfig(SDDPHandle handle, int index, const char *configFile)
{
  char line[256];
  char product_name[100], primary_proxy[100], proxies[256],
            manufacturer[100], model[100], driver[100], config_url[100];
  int max_age;
        bool local_only;
  char *key, *sep, *val;
  FILE *file;

  product_name[0] = '\0';
  primary_proxy[0] = '\0';
  proxies[0] = '\0';
  manufacturer[0] = '\0';
  model[0] = '\0';
  driver[0] = '\0';
  config_url[0] = '\0';
  max_age = 0;
  local_only = false;
  
  file = fopen(configFile, "r");
  if (file)
  {
    while (fgets(line, sizeof(line), file))
    {
      key = skipWhitespace(line);
      if (!key || key[0] == ';')
        continue;

      sep = strchr(key, '=');
      if (!sep)
        continue;

      key = trimRight(key, sep);
      if (!key)
        continue;

      val = skipWhitespace(sep + 1);
      if (val[0] != '\0')
        val = trimRight(val, val + strlen(val));

      if (strcmp(key, "Type") == 0)
        strcpy(product_name, val);
      else if (strcmp(key, "PrimaryProxy") == 0)
        strcpy(primary_proxy, val);
      else if (strcmp(key, "Proxies") == 0)
        strcpy(proxies, val);
      else if (strcmp(key, "Manufacturer") == 0)
        strcpy(manufacturer, val);
      else if (strcmp(key, "Model") == 0)
        strcpy(model, val);
      else if (strcmp(key, "Driver") == 0)
        strcpy(driver, val);
      else if (strcmp(key, "Config-Url") == 0)
        strcpy(config_url, val);
      else if (strcmp(key, "MaxAge") == 0)
        max_age = val ? atoi(val) : 1800;
      else if (strcmp(key, "LocalOnly") == 0)
        local_only = parseBool(val);
    }

    fclose(file);

    SDDPSetDevice(handle, index, product_name, primary_proxy, proxies,
            manufacturer, model, driver, config_url, max_age, local_only);
    return 1;
  }

  return 0;
}

static bool parseBool(const char *str)
{
  if (str && (!strcmp(str, "1") || !strcmp(str, "true")))
    return true;
  return false;
}

static char *trimRight(char *str, char *end)
{
  if (end == str)
    return NULL;
  
  while (end > str)
  {
    if (!isspace(*(end - 1)))
      break;
    end--;
  }
  
  *end = '\0';
  return str;
}

static char *skipWhitespace(char *str)
{
  while (*str && isspace(*str))
    str++;
  return str;
}

static int LoadConfig(const SDDPHandle handle, int index, const char *configFile)
{
  int ret = ReadSddpConfig(handle, index, configFile);
  if (!ret)
  {
    fprintf(stderr, "Incomplete config file `%s'\n", configFile);
  }

  return ret;
}

static int ConfigDirFilter(const struct dirent *entry)
{
  static const char file_ext[] = CONFIG_EXT;
  static const size_t file_ext_len = sizeof(file_ext) - 1;

  size_t len;

  if (!strcmp(entry->d_name, "."))
    return 0;
  if (!strcmp(entry->d_name, ".."))
    return 0;

  // Only interested in files that have the right file extension
  len = strlen(entry->d_name);
  if (len < file_ext_len)
    return 0;
  if (!strcmp(entry->d_name + len - file_ext_len, file_ext))
    return 1;
  return 0;
}

static int LoadConfigDir(const SDDPHandle handle, const char *configDir)
{
  struct dirent **entries;
  char confFile[512];
  int i, n, count = 0;

  n = scandir(configDir, &entries, ConfigDirFilter, alphasort);
  if (n < 0)
    return 0;

  for (i = 0; i < n; i++)
  {
    snprintf(confFile, sizeof(confFile), "%s/%s", configDir, entries[i]->d_name);
    if (LoadConfig(handle, i, confFile))
      count++;
  }

  while (n > 0)
  {
    free(entries[n]);
    n--;
  }
  free(entries);

  return count;
}

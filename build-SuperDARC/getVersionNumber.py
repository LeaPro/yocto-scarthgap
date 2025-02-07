#!/usr/bin/env python
#
# Python script used to extract the fw version number from the version.h file and return it
# as a string to be used in auto name generation

#import os
#import shutil
#import sys
#import subprocess

# relative location of the version.h file to read
versionFilePath = "../../SuperDARC/application-server/version.h"

#----------- Start of program -------------------------
# Ex: python3 getVersionNumber.py
# open version.h file and extract the version number
# Gets the last 2 characters on each line of #define xxx_VER
# input:  path to version.h file to read
# output: version number (ex. 1-2-3-4)

#print("reading version number from", versionFilePath)
version_file = open(versionFilePath, "r")
version_lines_list = version_file.readlines()
version_file.close()

majorNum = ""
minorNum = ""
releaseNum = ""
buildNum = ""

for version_line in version_lines_list:
    lineLen = len(version_line)
    #print(version_line)
    if version_line.startswith("#define MAJOR_VER"):
        majorNum = version_line[-3:lineLen]
        #print("Found Major number ", majorNum)
    elif version_line.startswith("#define MINOR_VER"):
        minorNum = version_line[-3:lineLen]
        #print("Found Minor number ", minorNum)
    elif version_line.startswith("#define RELEASE_VER"):
        releaseNum = version_line[-3:lineLen]
        #print("Found Release number ", releaseNum)
    elif version_line.startswith("#define BUILD_VER"):
        buildNum = version_line[-3:lineLen]
        #print("Found Build number ", buildNum)

  # if incBuildNum == True:
  #     if buildNum:
  #         # Bump the build number in the header file and return the new build number
  #         buildNum = bumpBuildNum(version_h_path, buildNum)
  #     else:
  #         print("Error! bogus build number, check " + version_h_path)

# get rid of new lines and whitespaces
versionNumber = majorNum.rstrip() + "-" + minorNum.rstrip() + "-" + releaseNum.rstrip() + "-" + buildNum.rstrip()
versionNumber = versionNumber.replace(" ", "")
print(versionNumber)
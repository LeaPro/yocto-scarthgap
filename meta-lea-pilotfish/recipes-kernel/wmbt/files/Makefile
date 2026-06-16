#makefile

CC=gcc
CXX=g++

CFLAGS=

OBJ_FILES := wmbt_uart.o \
		wmbt_linux.o \
		download.o \
		crc.o \
		wmbt.o

LOCAL_INCLUDES ?= ./common


%.o: ./common/%.c
	$(CC) -c -o $@ $< $(CFLAGS)  -I$(LOCAL_INCLUDES)

%.o: ./common/%.cpp
	$(CXX) -c -o $@ $< $(CFLAGS)  -I$(LOCAL_INCLUDES)

%.o: ./%.cpp
	$(CXX) -c -o $@ $< $(CFLAGS)  -I$(LOCAL_INCLUDES)

wmbt : $(OBJ_FILES)
	$(CXX) -o $@ $^ $(LDFLAGS) -lstdc++

clean :
	@rm *.o $(OUTPUT_FILE) 2> /dev/null

.PHONY: clean

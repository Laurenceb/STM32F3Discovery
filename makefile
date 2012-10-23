# Compile the project

# Uncomment the appropriate device type and startup file
DEVICE_TYPE = STM32F30X
STARTUP_FILE = stm32f30x

# Set the external clock frequency
HSE_VALUE = 8000000UL

# Enable debug compilation
#DEBUG = 1

# [OPTIONAL] Set the serial details for bootloading
STM32LDR_PORT = /dev/rfcomm0
STM32LDR_BAUD = 115200
# [OPTIONAL] Comment out to disable bootloader verification
STM32LDR_VERIFY = -v

# [OPTIONAL] Uncomment to link to maths library libm
LIBM = -lm

export DEBUG
export MESSAGES

TARGET_ARCH = -mcpu=cortex-m4 -mthumb

INCLUDE_DIRS = -I . -I lib/STM32F30x_StdPeriph_Driver/inc \
 -I lib/STM32_USB-FS-Device_Driver/inc \
 -I lib/CMSIS/Include \
 -I util \
 -I util/STM32F3_Discovery \
 -I inc \
 -I lib/CMSIS/Device/ST/STM32F30x/Include

#LIBRARY_DIRS = -L lib/STM32F10x_StdPeriph_Driver/\
# -L lib/STM32_USB-FS-Device_Driver

DEFINES = -D$(DEVICE_TYPE) -DHSE_Value=$(HSE_VALUE) -DUSE_STDPERIPH_DRIVER

COMPILE_OPTS = $(WARNINGS) $(TARGET_OPTS) $(MESSAGES) $(INCLUDE_DIRS) $(DEFINES)
WARNINGS = -Wall -W -Wshadow -Wcast-qual -Wwrite-strings -Winline

ifdef DEBUG
 TARGET_OPTS = -O3 -g3
 DEBUG_MACRO = -DDEBUG
else
 TARGET_OPTS = $(OPTIMISE) -finline -finline-functions-called-once -mfloat-abi=softfp -mfpu=fpv4-sp-d16\
  -funroll-loops -fno-common -fpromote-loop-indices -fno-rtti -fno-exceptions -ffunction-sections -fdata-sections
endif

CC = arm-none-eabi-gcc	
CXX = arm-none-eabi-g++
SIZE = arm-none-eabi-size
CFLAGS = -std=gnu99 $(COMPILE_OPTS)
CXXFLAGS = $(COMPILE_OPTS)

AS = $(CC) -x assembler-with-cpp -c $(TARGET_ARCH)
ASFLAGS = $(COMPILE_OPTS)

LD = $(CC)
LDFLAGS = -Wl,--gc-sections,-Map=$(MAIN_MAP),-cref -T STM32F303VC_FLASH.ld -L lib\
 $(INCLUDE_DIRS) $(LIBRARY_DIRS) $(LIBM) #-lstdc++

AR = arm-none-eabi-ar
ARFLAGS = cr

OBJCOPY = arm-none-eabi-objcopy
OBJCOPYFLAGS = -O binary

STARTUP_OBJ = lib/CMSIS/Device/ST/STM32F30x/Source/Templates/gcc_ride7/startup_$(STARTUP_FILE).s

MAIN_OUT = main.elf
MAIN_MAP = $(MAIN_OUT:%.elf=%.map)
MAIN_BIN = $(MAIN_OUT:%.elf=%.bin)

MAIN_OBJS = $(sort \
 $(patsubst %.cpp,%.o,$(wildcard src/*.cpp)) \
 $(patsubst %.cc,%.o,$(wildcard src/*.cc)) \
 $(patsubst %.c,%.o,$(wildcard src/*.c)) \
 $(patsubst %.s,%.o,$(wildcard src/*.s)) \
 $(patsubst %.c,%.o,$(wildcard util/*.c)) \
 $(patsubst %.c,%.o,$(wildcard util/STM32F3_Discovery/*.c)) \
 $(patsubst %.c,%.o,$(wildcard lib/STM32F30x_StdPeriph_Driver/src/*.c)) \
 $(patsubst %.c,%.o,$(wildcard lib/STM32_USB-FS-Device_Driver/src/*.c)) \
 $(patsubst %.c,%.o,$(wildcard lib/CMSIS/*.c)) \
 $(patsubst %.s,%.o,$(STARTUP_OBJ)))

#optimisation
$(MAIN_OBJS): OPTIMISE= -Os

#all - output the size from the elf
.PHONY: all
all: $(MAIN_BIN)
	$(SIZE) $(MAIN_OUT)

# main

$(MAIN_OUT): $(MAIN_OBJS) $(FWLIB) $(USBLIB)
	$(LD) $(TARGET_ARCH) $^ -o $@ $(LDFLAGS)

$(MAIN_OBJS): $(wildcard inc/*.h) $(wildcard lib/STM32F30x_StdPeriph_Driver/*.h)\
 $(wildcard lib/STM32_USB-FS-Device_Driver/inc/*.h)\
 $(wildcard lib/STM32F30x_StdPeriph_Driver/inc/*.h)\
 $(wildcard lib/CMSIS/Device/ST/STM32F30x/Include/*.h)\
 $(wildcard lib/CMSIS/Include/*.h)\
 $(wildcard util/*.h)\
 $(wildcard util/STM32F3_Discovery/*.h)

$(MAIN_BIN): $(MAIN_OUT)
	$(OBJCOPY) $(OBJCOPYFLAGS) $< $@

# fwlib

.PHONY: fwlib
fwlib: $(FWLIB)

$(FWLIB): $(wildcard lib/STM32F10x_StdPeriph_Driver/*.h)\
 $(wildcard lib/STM32F10x_StdPeriph_Driver/inc/*.h)
	@cd lib/STM32F10x_StdPeriph_Driver && $(MAKE)

# usblib

.PHONY: usblib
usblib: $(USBLIB)

$(USBLIB): $(wildcard lib/STM32_USB-FS-Device_Driver/inc*.h)
	@cd lib/STM32_USB-FS-Device_Driver && $(MAKE)

#size

.PHONY: size
size: all
	@echo "Size:"
	$(SIZE) $(MAIN_OUT) $@
	@$(CAT) $@

# flash

.PHONY: flash
flash: flash-elf
#flash: flash-bin

.PHONY: flash-elf
flash-elf: all
	@cp $(MAIN_OUT) jtag/flash.elf
	@cd jtag && openocd -f flash-elf.cfg
	@rm jtag/flash.elf

.PHONY: flash-bin
flash-bin: all
	@cp $(MAIN_BIN) jtag/flash.bin
	@cd jtag && openocd -f flash-bin.cfg
	@rm jtag/flash.bin

.PHONY: upload
upload: all
	@python jtag/stm32loader.py -p $(STM32LDR_PORT) -b $(STM32LDR_BAUD)\
    -e $(STM32LDR_VERIFY) -w main.bin


# clean

.PHONY: clean
clean:
	-rm -f $(MAIN_OBJS) $(MAIN_OUT) $(MAIN_MAP) $(MAIN_BIN)
	-rm -f jtag/flash.elf jtag/flash.bin
	@cd lib/STM32F30x_StdPeriph_Driver && $(MAKE) clean
	@cd lib/STM32_USB-FS-Device_Driver && $(MAKE) clean



###############################################################################
 #
 # Copyright (C) 2022-2023 Maxim Integrated Products, Inc. (now owned by
 # Analog Devices, Inc.),
 # Copyright (C) 2023-2024 Analog Devices, Inc.
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #
 ##############################################################################

ifeq "$(CMSIS_ROOT)" ""
$(error CMSIS_ROOT must be specified)
endif

TARGET_UC := $(subst m,M,$(subst a,A,$(subst x,X,$(TARGET))))
TARGET_LC := $(subst M,m,$(subst A,a,$(subst X,x,$(TARGET))))

# The build directory
ifeq "$(BUILD_DIR)" ""
ifeq "$(RISCV_CORE)" ""
BUILD_DIR=$(CURDIR)/build
else
BUILD_DIR=$(CURDIR)/buildrv
endif
endif

ifeq "$(STARTUPFILE)" ""
ifeq "$(RISCV_CORE)" ""
STARTUPFILE=startup_$(TARGET_LC).S
else
STARTUPFILE=startup_riscv_$(TARGET_LC).S
endif
endif

ifeq "$(LINKERFILE)" ""
ifeq "$(RISCV_CORE)" ""
LINKERFILE=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/$(TARGET_LC).ld
else
LINKERFILE=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/$(TARGET_LC)_rv.ld
endif
endif

ifeq "$(ENTRY)" ""
ENTRY=Reset_Handler
endif

# Default TARGET_REVISION
# "A1" in ASCII
ifeq "$(TARGET_REV)" ""
TARGET_REV=0x4131
endif

# Add target specific CMSIS source files
ifneq (${MAKECMDGOALS},lib)
SRCS += ${STARTUPFILE}
SRCS += heap.c
ifeq "$(RISCV_CORE)" ""
SRCS += system_$(TARGET_LC).c
else
SRCS += system_riscv_$(TARGET_LC).c
endif
endif

# RISC-V Loader - compile a project for the RISC-V core
# and link it into the same executable as the ARM code
# Configuration Variables:
# - RISCV_LOAD : Set to 1 to enable the RISC-V loader, 0 to disable.  Ex: RISCV_LOAD=1
# - RISCV_APP : Sets the directory of the project
# 				to compile for the RISC-V core.
#				Defaults to "Hello_World".
#				Absolute paths are recommended, but
#				relative paths will also work.
#
# Ex:  "make RISCV_LOAD=1 RISCV_APP=../GPIO"
################################################################################
ifeq ($(RISCV_LOAD),1)

LOADER_SCRIPT := $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/riscv-loader.S

# Directory for RISCV code, defaults to Hello_World
RISCV_APP ?= $(CMSIS_ROOT)/../../Examples/$(TARGET_UC)/Hello_World

# Build the RISC-V app inside of this project so that
# "make clean" will catch it automatically.
# Additionally, set the output directory and filename
# to what the RISC-V loader script expects.
RISCV_BUILD_DIR := $(CURDIR)/build/buildrv

# Binary name for RISCV code.
RISCV_APP_BIN = $(RISCV_BUILD_DIR)/riscv.bin
RISCV_APP_OBJ = $(RISCV_BUILD_DIR)/riscv.o

# Add the RISC-V object to the build.  This is the critical
# line that will get the linker to bring it into the .elf file.
PROJ_OBJS = ${RISCV_APP_OBJ}

.PHONY: rvapp
rvapp: $(RISCV_APP_BIN)

$(RISCV_APP_BIN): FORCE
	$(MAKE) -C ${RISCV_APP} BUILD_DIR=$(RISCV_BUILD_DIR) RISCV_CORE=1 RISCV_LOAD=0 PROJECT=riscv
	$(MAKE) -C ${RISCV_APP} BUILD_DIR=$(RISCV_BUILD_DIR) $(RISCV_APP_BIN) RISCV_CORE=1 RISCV_LOAD=0

.PHONY: rvobj
rvobj: $(RISCV_APP_OBJ)

${RISCV_APP_OBJ}: $(LOADER_SCRIPT) ${RISCV_APP_BIN}
	@${CC} ${AFLAGS} -o ${@} -c $(LOADER_SCRIPT)

endif
################################################################################

# Add target specific CMSIS source directories
VPATH+=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC
VPATH+=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source

# Add target specific CMSIS include directories
IPATH+=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Include

# Add CMSIS Core files
CMSIS_VER ?= 5.9.0
IPATH+=$(CMSIS_ROOT)/$(CMSIS_VER)/Core/Include

# Add directory with linker include file
LIBPATH+=$(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC

# Include memory definitions
include $(CMSIS_ROOT)/Device/Maxim/$(TARGET_UC)/Source/GCC/$(TARGET_LC)_memory.mk

# Select the xpack toolchain to use
RISCV_PREFIX ?= riscv-none-elf

# Include the rules and goals for building
ifeq "$(RISCV_CORE)" ""
include $(CMSIS_ROOT)/Device/Maxim/GCC/gcc.mk
else
include $(CMSIS_ROOT)/Device/Maxim/GCC/gcc_riscv.mk
endif

# Include rules for flashing
include $(CMSIS_ROOT)/../../Tools/Flash/flash.mk

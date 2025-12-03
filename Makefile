.POSIX:
.PHONY: all clean

# ================================================================
# UEFI Build Configuration
# ================================================================
# Homebrew MinGW-w64 cross compiler used to generate PE/COFF binaries.
GCC = /opt/homebrew/bin/x86_64-w64-mingw32-gcc

# Output UEFI binary
TARGET = BOOTX64.EFI

# Source files
SRCS = efi.c
OBJS = $(SRCS:.c=.o)
DEPS = $(OBJS:.o=.d)

# ================================================================
# Compiler Flags — UEFI requires freestanding C with no red zone
# ================================================================
CFLAGS = \
	-std=c17 \
	-MMD -MP \
	-Wall -Wextra -Wpedantic \
	-mno-red-zone \
	-ffreestanding \
	-fshort-wchar \
	-nostdlib

# ================================================================
# Linker Flags — Build a valid PE/COFF UEFI executable
# ================================================================
# subsystem=10 → UEFI application
# entry=efi_main → required entry symbol
# image-base & section-alignment improve firmware compatibility
LDFLAGS = \
	-Wl,--subsystem,10 \
	-Wl,--entry,efi_main \
	-Wl,--image-base,0 \
	-Wl,--section-alignment,4096 \
	-Wl,--file-alignment,512

# ================================================================
# Build rules
# ================================================================
all: $(TARGET)

$(TARGET): $(OBJS)
	$(GCC) $(CFLAGS) $(LDFLAGS) -o $@ $^

# Compile .c → .o while generating dependency .d files
%.o: %.c
	$(GCC) $(CFLAGS) -c $< -o $@

# Auto-include generated dependency files
-include $(DEPS)

clean:
	rm -f $(TARGET) $(OBJS) $(DEPS)

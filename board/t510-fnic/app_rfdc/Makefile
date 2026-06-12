APP_RFDC_BIN ?= t510-fnic-rfdc
CC ?= gcc
CFLAGS ?= -O2
LDFLAGS ?=

CPPFLAGS += -I. -Ilmk04828 -Ixrfdc
CFLAGS += -Wall -Wextra -std=gnu11
LDLIBS += -lmetal -lm

APP_RFDC_SOURCES := \
	app_mailbox.c \
	app_gpio.c \
	main.c \
	rfdc_platform.c \
	lmk04828/lmk04828.c \
	xrfdc/xrfdc.c \
	xrfdc/xrfdc_ap.c \
	xrfdc/xrfdc_clock.c \
	xrfdc/xrfdc_dp.c \
	xrfdc/xrfdc_intr.c \
	xrfdc/xrfdc_mb.c \
	xrfdc/xrfdc_mixer.c \
	xrfdc/xrfdc_mts.c

APP_RFDC_OBJECTS := $(APP_RFDC_SOURCES:.c=.o)

.PHONY: all clean

all: $(APP_RFDC_BIN)

$(APP_RFDC_BIN): $(APP_RFDC_OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LDLIBS)

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(APP_RFDC_BIN) $(APP_RFDC_OBJECTS)

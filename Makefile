
# Makefile
#
# Copyright (C) 2014 Francesco Abbate
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#

# If the following variable is set to "yes" the lang.* modules will be
# embedded in the executable and preloaded into the Lua's state.
BC_PRELOAD = yes

ifneq (,$(findstring Windows,$(OS)))
  HOST_SYS= Windows
else
  HOST_SYS:= $(shell uname -s)
  ifneq (,$(findstring CYGWIN,$(TARGET_SYS)))
    HOST_SYS= Windows
  else ifeq (Darwin,$(HOST_SYS))
    LFLAGS += -pagezero_size 10000 -image_base 100000000
  endif
endif

AR= ar rcu
RANLIB= ranlib

ifeq ($(HOST_SYS),Windows)
  LUAJIT_CFLAGS := -I/usr/local/include/luajit-2.1
  LUAJIT_LIBS := -L/usr/local/lib -lluajit
else
  LUAJIT_CFLAGS := $(shell pkg-config luajit --cflags)
  LUAJIT_LIBS := $(shell pkg-config luajit --libs)
endif

CC = gcc
CFLAGS = -g -Wall

CFLAGS += $(LUAJIT_CFLAGS)
LIBS += $(LUAJIT_LIBS)

INCLUDES += -I..

COMPILE = $(CC) $(CFLAGS) $(DEFS) $(INCLUDES)

ifeq ($(strip $(BC_PRELOAD)),yes)
  LANG_SRC_FILES = language_bcloader.c
  DEFS += -DBC_PRELOAD
endif

LANG_SRC_FILES += language.c language_loaders.c
LANG_OBJ_FILES := $(LANG_SRC_FILES:%.c=%.o)
DEP_FILES := $(LANG_SRC_FILES:%.c=.deps/%.P)

DEPS_MAGIC := $(shell mkdir .deps > /dev/null 2>&1 || :)

TARGETS = liblang.a

all: $(TARGETS) luajit-x

luajit-x: $(LANG_OBJ_FILES) luajit-x.o
	$(CC) -o $@ $(LANG_OBJ_FILES) luajit-x.o $(LIBS)

liblang.a: $(LANG_OBJ_FILES)
	@echo Archive $@
	@$(AR) $@ $?
	@$(RANLIB) $@

%.o: %.c
	@echo Compiling $<
	@$(COMPILE) -Wp,-MMD,.deps/$(*F).pp -c $<
	@-cp .deps/$(*F).pp .deps/$(*F).P; \
	tr ' ' '\012' < .deps/$(*F).pp \
          | sed -e 's/^\\$$//' -e '/^$$/ d' -e '/:$$/ d' -e 's/$$/ :/' \
            >> .deps/$(*F).P; \
	rm .deps/$(*F).pp

.PHONY: clean all

clean:
	rm -fr *.o *.a $(TARGETS)

-include $(DEP_FILES)

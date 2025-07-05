# Fragment to be imported in all of our package-level Makefiles, defining useful utilities,
# variables, and empty overridable stub rules (build, test, clean).

# Function that prepends its argument ($(1)) to the PATH environment variable if it does not contain
# it yet. This is done by looking for `:$(1):` within `:$(PATH):`.
#
# Example use: $(call ADD_PATH , ./node_modules/.bin)
# To be used at the top-level of makefile.
#
# Note that due to an issue on Mac, all commands run in the makefile that are found via these path
# additions should add some "complex" syntax (we recommend ending with a semicolon) or they might
# not be recognized. This might be a symlink issue.
# cf. https://stackoverflow.com/a/21709821/298664
#
ADD_PATH = $(eval PATH := $(if $(findstring :$(PATH_TO_ADD):,:$(PATH):),$(PATH),$(1):$(PATH)))

# Unlock more powerful features than plain POSIX sh.
SHELL := /bin/bash

# Enables running bun-installed binaries without going through bun.
$(call ADD_PATH , ./node_modules/.bin)

# Enables running workspace-level bun-installed binaries easily and without going through bun.
# The condition makes sure this is not added in the top-level Makefile itself.
ifeq (,$(wildcard bun.lock))
$(call ADD_PATH , ../../node_modules/.bin)
endif

# Name of the package the makefile is executed for (based on the current directory).
PKG := $(notdir $(shell pwd))

# Empty stubs (so that we can iterate over packages and call these commands even if not defined)
# Can be overriden any including Makefile.

build:
.PHONY: build

clean:
.PHONY: clean

typecheck:
.PHONY: typecheck
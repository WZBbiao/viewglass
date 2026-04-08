PREFIX ?= /usr/local
INSTALL_DIR = $(PREFIX)/bin
BUILD_DIR = .build/release

.PHONY: build install uninstall clean test

build:
	swift build -c release --disable-sandbox

install: build
	@if [ -w "$(INSTALL_DIR)" ]; then \
		mkdir -p $(INSTALL_DIR); \
		cp $(BUILD_DIR)/viewglass $(INSTALL_DIR)/viewglass; \
	else \
		sudo mkdir -p $(INSTALL_DIR); \
		sudo cp $(BUILD_DIR)/viewglass $(INSTALL_DIR)/viewglass; \
	fi
	@echo "Installed viewglass to $(INSTALL_DIR)/viewglass"

uninstall:
	@if [ -w "$(INSTALL_DIR)/viewglass" ]; then \
		rm -f $(INSTALL_DIR)/viewglass; \
	else \
		sudo rm -f $(INSTALL_DIR)/viewglass; \
	fi
	@echo "Uninstalled viewglass"

clean:
	swift package clean

test:
	swift test

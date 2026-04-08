PREFIX ?= /usr/local
INSTALL_DIR = $(PREFIX)/bin
BUILD_DIR = .build/release

.PHONY: build install uninstall clean test

build:
	swift build -c release --disable-sandbox

install: build
	@if [ -w "$(INSTALL_DIR)" ]; then \
		mkdir -p $(INSTALL_DIR); \
		cp $(BUILD_DIR)/lookin-cli $(INSTALL_DIR)/lookin-cli; \
	else \
		sudo mkdir -p $(INSTALL_DIR); \
		sudo cp $(BUILD_DIR)/lookin-cli $(INSTALL_DIR)/lookin-cli; \
	fi
	@echo "Installed lookin-cli to $(INSTALL_DIR)/lookin-cli"

uninstall:
	@if [ -w "$(INSTALL_DIR)/lookin-cli" ]; then \
		rm -f $(INSTALL_DIR)/lookin-cli; \
	else \
		sudo rm -f $(INSTALL_DIR)/lookin-cli; \
	fi
	@echo "Uninstalled lookin-cli"

clean:
	swift package clean

test:
	swift test

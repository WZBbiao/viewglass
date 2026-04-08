PREFIX ?= /usr/local
INSTALL_DIR = $(PREFIX)/bin
BUILD_DIR = .build/release

.PHONY: build install uninstall clean test

build:
	swift build -c release --disable-sandbox

install: build
	@mkdir -p $(INSTALL_DIR)
	@cp $(BUILD_DIR)/lookin-cli $(INSTALL_DIR)/lookin-cli
	@echo "Installed lookin-cli to $(INSTALL_DIR)/lookin-cli"

uninstall:
	@rm -f $(INSTALL_DIR)/lookin-cli
	@echo "Uninstalled lookin-cli"

clean:
	swift package clean

test:
	swift test

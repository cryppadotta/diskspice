.PHONY: build-dev run-dev clean build-scanner bundle-scanner

XCODEBUILD := /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild
PROJECT := DiskSpice/DiskSpice.xcodeproj
SCHEME := DiskSpice
DESTINATION := platform=macOS
DERIVED_DATA := build/DerivedData
APP := $(DERIVED_DATA)/Build/Products/Debug/DiskSpice.app
SCANNER_SCRIPT := ./DiskSpice/Scanner/build-scanner.sh
SCANNER_BIN := DiskSpice/Scanner/bin/diskspice-scan
APP_RESOURCES := $(APP)/Contents/Resources

build-scanner:
	$(SCANNER_SCRIPT)

bundle-scanner:
	@test -d "$(APP)" || (echo "App not found at $(APP)"; exit 1)
	@test -f "$(SCANNER_BIN)" || (echo "Scanner binary not found at $(SCANNER_BIN)"; exit 1)
	@mkdir -p "$(APP_RESOURCES)"
	@install -m 755 "$(SCANNER_BIN)" "$(APP_RESOURCES)/diskspice-scan"

build-dev: build-scanner
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -derivedDataPath $(DERIVED_DATA) build
	@$(MAKE) bundle-scanner

run-dev: build-dev
	@test -d "$(APP)" || (echo "App not found at $(APP)"; exit 1)
	@echo "Launching $(APP) (built $$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$(APP)"))"
	open $(APP)

clean:
	rm -rf $(DERIVED_DATA)

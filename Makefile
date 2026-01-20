# Guitar Practice - Build & Install

SCHEME = GuitarPractice
APP_NAME = GuitarPractice.app
DERIVED_DATA = ~/Library/Developer/Xcode/DerivedData/GuitarPractice-*/Build/Products

.PHONY: build run release install clean

# Debug build
build:
	xcodebuild -scheme $(SCHEME) -configuration Debug -destination 'platform=macOS,arch=arm64' build

# Debug build and run
run: build
	pkill -x GuitarPractice || true
	sleep 0.5
	open $(DERIVED_DATA)/Debug/$(APP_NAME)
	@sleep 1 && pgrep -x GuitarPractice > /dev/null && echo "✓ App launched successfully" || (echo "✗ App failed to launch" && exit 1)

# Release build
release:
	xcodebuild -scheme $(SCHEME) -configuration Release -destination 'platform=macOS,arch=arm64' build

# Release build and install to /Applications
install: release
	pkill -x GuitarPractice || true
	sleep 0.5
	rm -rf /Applications/$(APP_NAME)
	cp -R $(DERIVED_DATA)/Release/$(APP_NAME) /Applications/
	@echo "Installed to /Applications/$(APP_NAME)"
	open /Applications/$(APP_NAME)
	@sleep 1 && pgrep -x GuitarPractice > /dev/null && echo "✓ App launched successfully" || (echo "✗ App failed to launch" && exit 1)

# Clean build artifacts
clean:
	xcodebuild -scheme $(SCHEME) clean
	@echo "Cleaned build artifacts"

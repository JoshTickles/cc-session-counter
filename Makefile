APP_NAME   = CCSessionCounter
BUNDLE     = $(APP_NAME).app
BINARY     = .build/release/$(APP_NAME)
INSTALL_TO = /Applications/$(BUNDLE)
PLIST      = $(BUNDLE)/Contents/Info.plist

.PHONY: build bundle run install clean

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	mkdir -p $(BUNDLE)/Contents/Resources
	cp icons/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string CCSessionCounter" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.local.ccsessioncounter" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 1.0" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string CCSessionCounter" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" $(PLIST)
	/usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" $(PLIST)
	@echo "✓ Built $(BUNDLE)"

run: bundle
	open $(BUNDLE)

install: bundle
	rm -rf $(INSTALL_TO)
	cp -r $(BUNDLE) $(INSTALL_TO)
	@echo "✓ Installed to $(INSTALL_TO)"
	open $(INSTALL_TO)

clean:
	rm -rf .build $(BUNDLE)

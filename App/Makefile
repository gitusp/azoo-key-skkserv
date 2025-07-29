
.PHONY: all clean build notarize staple

# Configuration variables
PROJECT_NAME := azoo-key-skkserv
PROJECT_FILE := $(PROJECT_NAME).xcodeproj
SCHEME := $(PROJECT_NAME)
VERSION := $(shell xcodebuild -project $(PROJECT_FILE) -target $(PROJECT_NAME) -showBuildSettings -json | jq -r '.[0].buildSettings.MARKETING_VERSION')
TEAM_ID := $(TEAM_ID)
APPLE_ID := $(APPLE_ID)
APPLE_APP_PASSWORD := $(APPLE_APP_PASSWORD)

BUILD_DIR := build
DIST_DIR := dist
ARCHIVE_PATH := $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
APP_PATH := $(BUILD_DIR)/$(PROJECT_NAME).app
PKG_ROOT_DIR := $(BUILD_DIR)/pkg-root
PKG_COMPONENT := $(BUILD_DIR)/$(PROJECT_NAME)-component.pkg
PKG_COMPONENT_ID := io.github.gitusp.azoo-key-skkserv.app
PKG_COMPONENT_PLIST := $(BUILD_DIR)/$(PROJECT_NAME)-component.plist
PKG_NAME := $(PROJECT_NAME).pkg
PKG_PATH := $(DIST_DIR)/$(PKG_NAME)
EXPORT_OPTIONS_PLIST := $(BUILD_DIR)/ExportOptions.plist
DISTRIBUTION_PLIST := $(BUILD_DIR)/Distribution.plist

all: $(PKG_PATH)

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(DIST_DIR)

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

# Create ExportOptions.plist
$(EXPORT_OPTIONS_PLIST):
	@echo "Creating ExportOptions.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $@
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $@
	@echo '<plist version="1.0">' >> $@
	@echo '<dict>' >> $@
	@echo '    <key>method</key>' >> $@
	@echo '    <string>developer-id</string>' >> $@
	@echo '    <key>destination</key>' >> $@
	@echo '    <string>export</string>' >> $@
	@echo '    <key>signingStyle</key>' >> $@
	@echo '    <string>automatic</string>' >> $@
	@echo '    <key>stripSwiftSymbols</key>' >> $@
	@echo '    <true/>' >> $@
	@echo '    <key>uploadBitcode</key>' >> $@
	@echo '    <false/>' >> $@
	@echo '    <key>uploadSymbols</key>' >> $@
	@echo '    <false/>' >> $@
	@echo '</dict>' >> $@
	@echo '</plist>' >> $@

# Archive the application
$(ARCHIVE_PATH):
	@echo "Archiving $(PROJECT_NAME)..."
	mkdir -p $(BUILD_DIR)
	xcodebuild -project $(PROJECT_FILE) -scheme $(SCHEME) -sdk macosx -configuration Release -archivePath $@ DEVELOPMENT_TEAM=$(TEAM_ID) ONLY_ACTIVE_ARCH=NO archive

# Export the application
$(APP_PATH): $(ARCHIVE_PATH) $(EXPORT_OPTIONS_PLIST)
	@echo "Exporting $(PROJECT_NAME).app..."
	xcodebuild -exportArchive -archivePath $< -exportPath $(BUILD_DIR) -exportOptionsPlist $(EXPORT_OPTIONS_PLIST)

# Create Distribution.plist for productbuild
$(DISTRIBUTION_PLIST):
	@echo "Creating Distribution.plist..."
	@echo '<?xml version="1.0" encoding="utf-8"?>' > $@
	@echo '<installer-gui-script minSpecVersion="1">' >> $@
	@echo '    <title>$(PROJECT_NAME)</title>' >> $@
	@echo '    <options customize="never" require-scripts="false" hostArchitectures="x86_64,arm64"/>' >> $@
	@echo '    <choices-outline>' >> $@
	@echo '        <line choice="default" />' >> $@
	@echo '    </choices-outline>' >> $@
	@echo '    <choice id="default" title="azooKey Skkserv" enabled="false">' >> $@
	@echo '        <pkg-ref id="$(PKG_COMPONENT_ID)">$(PROJECT_NAME)-component.pkg</pkg-ref>' >> $@
	@echo '    </choice>' >> $@
	@echo '</installer-gui-script>' >> $@

$(PKG_COMPONENT_PLIST):
	@echo "Creating component.plist..."
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $@
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $@
	@echo '<plist version="1.0">' >> $@
	@echo '<array>' >> $@
	@echo '    <dict>' >> $@
	@echo '        <key>BundleHasStrictIdentifier</key>' >> $@
	@echo '        <true/>' >> $@
	@echo '        <key>BundleIsRelocatable</key>' >> $@
	@echo '        <true/>' >> $@
	@echo '        <key>BundleIsVersionChecked</key>' >> $@
	@echo '        <false/>' >> $@
	@echo '        <key>BundleOverwriteAction</key>' >> $@
	@echo '        <string>upgrade</string>' >> $@
	@echo '        <key>RootRelativeBundlePath</key>' >> $@
	@echo '        <string>Applications/$(PROJECT_NAME).app</string>' >> $@
	@echo '    </dict>' >> $@
	@echo '</array>' >> $@
	@echo '</plist>' >> $@

# Prepare PKG root directory
$(PKG_ROOT_DIR): $(APP_PATH)
	@echo "Preparing PKG root directory..."
	mkdir -p $@/Applications
	cp -R $(APP_PATH) $@/Applications/

# Create component package with pkgbuild
$(PKG_COMPONENT): $(PKG_ROOT_DIR) $(PKG_COMPONENT_PLIST)
	@echo "Creating component package with pkgbuild..."
	pkgbuild --root $< --component-plist $(PKG_COMPONENT_PLIST) --identifier $(PKG_COMPONENT_ID) --version $(VERSION) --install-location / $@

# Create final package with productbuild and sign with productsign
$(PKG_PATH): $(PKG_COMPONENT) $(DISTRIBUTION_PLIST) $(DIST_DIR)
	@echo "Creating final package with productbuild..."
	productbuild --distribution $(DISTRIBUTION_PLIST) --package-path $(BUILD_DIR) $(BUILD_DIR)/$(PROJECT_NAME)-unsigned.pkg
	@echo "Signing package with productsign..."
	productsign --sign "Developer ID Installer" $(BUILD_DIR)/$(PROJECT_NAME)-unsigned.pkg $@

# Notarize PKG
notarize:
	@echo "Submitting $(PKG_NAME) for notarization..."
	xcrun notarytool submit $(PKG_PATH) --apple-id $(APPLE_ID) --password $(APPLE_APP_PASSWORD) --team-id $(TEAM_ID) --wait

# Staple notarization ticket
staple:
	@echo "Stapling notarization ticket to $(PKG_NAME)..."
	xcrun stapler staple $(PKG_PATH)

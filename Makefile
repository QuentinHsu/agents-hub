TARGET_NAME  := AgentsHub
DISPLAY_NAME := Agents Hub
BUNDLE_ID    := com.agentshub.app
BUILD_DIR    := .build
RELEASE_DIR  := $(BUILD_DIR)/release
APP_BUNDLE   := $(BUILD_DIR)/$(DISPLAY_NAME).app
DMG_FILE     := $(BUILD_DIR)/$(DISPLAY_NAME).dmg
INSTALL_DIR  := /Applications
LOCAL_APP_VERSION ?= dev
LOCAL_BUILD_NUMBER ?= $(LOCAL_APP_VERSION)
WORKFLOW_REPO ?= https://github.com/QuentinHsu/workflow.git
WORKFLOW_REF  ?= main
WORKFLOW_CACHE_DIR := $(BUILD_DIR)/workflow
WORKFLOW_SOURCE := $(WORKFLOW_REPO)#$(WORKFLOW_REF)
WORKFLOW_SOURCE_FILE := $(WORKFLOW_CACHE_DIR)/.release-kit-source
DEFAULT_RELEASE_KIT_DIR := $(WORKFLOW_CACHE_DIR)/release-kits/macos/swiftpm-sparkle
RELEASE_KIT_DIR ?= $(DEFAULT_RELEASE_KIT_DIR)
RELEASE_KIT_BUILD := $(RELEASE_KIT_DIR)/Scripts/build.sh

.PHONY: build clean app dmg install uninstall run prepare-release-kit

# ─── Development ──────────────────────────────────────────────

build:
	swift build -c release

run:
	swift run $(TARGET_NAME)

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)" "$(DMG_FILE)" dist

# ─── Release Kit ──────────────────────────────────────────────

prepare-release-kit:
	@if [ "$(RELEASE_KIT_DIR)" != "$(DEFAULT_RELEASE_KIT_DIR)" ]; then \
		if [ ! -x "$(RELEASE_KIT_BUILD)" ]; then \
			echo "✗ Release kit build script not found: $(RELEASE_KIT_BUILD)"; \
			exit 1; \
		fi; \
	elif [ ! -x "$(RELEASE_KIT_BUILD)" ] || [ "$$(cat "$(WORKFLOW_SOURCE_FILE)" 2>/dev/null)" != "$(WORKFLOW_SOURCE)" ]; then \
		echo "▸ Fetching release kit from $(WORKFLOW_REPO) ($(WORKFLOW_REF))..."; \
		rm -rf "$(WORKFLOW_CACHE_DIR)"; \
		git clone --depth 1 --filter=blob:none --sparse --branch "$(WORKFLOW_REF)" "$(WORKFLOW_REPO)" "$(WORKFLOW_CACHE_DIR)"; \
		git -C "$(WORKFLOW_CACHE_DIR)" sparse-checkout set release-kits/macos/swiftpm-sparkle; \
		echo "$(WORKFLOW_SOURCE)" > "$(WORKFLOW_SOURCE_FILE)"; \
	fi

# ─── App Bundle ───────────────────────────────────────────────

app: prepare-release-kit
	@APP_PROJECT_DIR="$(CURDIR)" \
	 APP_TARGET_NAME="$(TARGET_NAME)" \
	 APP_DISPLAY_NAME="$(DISPLAY_NAME)" \
	 APP_BUNDLE_NAME="$(DISPLAY_NAME)" \
	 APP_BUNDLE_ID="$(BUNDLE_ID)" \
	 APP_MIN_MACOS="15.0" \
	 APP_ICON_PATH="Assets/AppIcon.icns" \
	 APP_REPOSITORY="QuentinHsu/agents-hub" \
	 APP_VERSION="$(LOCAL_APP_VERSION)" \
	 BUILD_NUMBER="$(LOCAL_BUILD_NUMBER)" \
	 "$(RELEASE_KIT_BUILD)" app

# ─── DMG ──────────────────────────────────────────────────────

dmg: prepare-release-kit
	@APP_PROJECT_DIR="$(CURDIR)" \
	 APP_TARGET_NAME="$(TARGET_NAME)" \
	 APP_DISPLAY_NAME="$(DISPLAY_NAME)" \
	 APP_BUNDLE_NAME="$(DISPLAY_NAME)" \
	 APP_BUNDLE_ID="$(BUNDLE_ID)" \
	 APP_MIN_MACOS="15.0" \
	 APP_ICON_PATH="Assets/AppIcon.icns" \
	 APP_REPOSITORY="QuentinHsu/agents-hub" \
	 APP_VERSION="$(LOCAL_APP_VERSION)" \
	 BUILD_NUMBER="$(LOCAL_BUILD_NUMBER)" \
	 "$(RELEASE_KIT_BUILD)" dmg

# ─── Install / Uninstall ─────────────────────────────────────

install: app
	@echo "▸ Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(DISPLAY_NAME).app"
	@cp -r "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	@echo "✓ $(INSTALL_DIR)/$(DISPLAY_NAME).app"

uninstall:
	@echo "▸ Removing $(INSTALL_DIR)/$(DISPLAY_NAME).app..."
	@rm -rf "$(INSTALL_DIR)/$(DISPLAY_NAME).app"
	@echo "✓ Removed"

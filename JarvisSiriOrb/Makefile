# =====================================
# JARVIS C++ (macOS native)
# =====================================

APP_NAME := jarvis
APP_BUNDLE := build/JARVIS.app

CXX := clang++

SDK := $(shell xcrun --show-sdk-path)

BUILD_DIR := build

CXXFLAGS := -std=c++17 -stdlib=libc++ -isysroot $(SDK) -O2 -Wall -Wextra -DJARVIS_PROJECT_DIR=\"$(CURDIR)\"

OBJCXXFLAGS := $(CXXFLAGS) -fobjc-arc -Wno-deprecated-declarations

LIBS := -framework Foundation -framework AppKit \
		-framework AVFoundation -framework Speech \
		-lcurl

SOURCES_CPP := src/main.cpp src/ai.cpp src/memory.cpp \
	src/commands.cpp src/executor.cpp src/http.cpp

SOURCES_MM := src/speech.mm src/gui.mm

OBJECTS := $(addprefix $(BUILD_DIR)/,$(notdir $(SOURCES_CPP:.cpp=.o)) $(notdir $(SOURCES_MM:.mm=.o)))

.PHONY: all clean run

all: $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)

$(APP_BUNDLE): $(BUILD_DIR)/$(APP_NAME) Info.plist | $(BUILD_DIR)
	codesign --force --sign - $(BUILD_DIR)/$(APP_NAME) >/dev/null
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/JARVIS
	cp Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE) >/dev/null

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: src/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: src/%.mm | $(BUILD_DIR)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

$(BUILD_DIR)/$(APP_NAME): $(OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LIBS) -sectcreate __TEXT __info_plist Info.plist

run: $(APP_BUNDLE)
	open $(APP_BUNDLE)

clean:
	rm -rf $(BUILD_DIR)

# =====================================
# JARVIS C++ (macOS native)
# =====================================

APP_NAME := jarvis

CXX := clang++

SDK := $(shell xcrun --show-sdk-path)

BUILD_DIR := build

CXXFLAGS := -std=c++17 -stdlib=libc++ -isysroot $(SDK) -O2 -Wall -Wextra

OBJCXXFLAGS := $(CXXFLAGS) -fobjc-arc -Wno-deprecated-declarations

LIBS := -framework Foundation -framework AppKit \
		-framework AVFoundation -framework Speech \
		-lcurl

SOURCES_CPP := src/main.cpp src/ai.cpp src/memory.cpp \
	src/commands.cpp src/executor.cpp src/http.cpp

SOURCES_MM := src/speech.mm src/gui.mm

OBJECTS := $(addprefix $(BUILD_DIR)/,$(notdir $(SOURCES_CPP:.cpp=.o)) $(notdir $(SOURCES_MM:.mm=.o)))

.PHONY: all clean run

all: $(BUILD_DIR)/$(APP_NAME)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: src/%.cpp | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: src/%.mm | $(BUILD_DIR)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

$(BUILD_DIR)/$(APP_NAME): $(OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LIBS)

run: $(BUILD_DIR)/$(APP_NAME)
	$(BUILD_DIR)/$(APP_NAME)

clean:
	rm -rf $(BUILD_DIR)

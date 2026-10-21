ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WCCornerReverse

WCCornerReverse_FILES = \
	src/WCRConfig.mm \
	src/WCRTable.mm \
	src/WCRCornerVC.mm \
	src/WCRGlobalVC.mm \
	src/WCREngine.mm \
	src/WCRPlugin.mm \
	src/Tweak.xm

WCCornerReverse_CFLAGS = -fobjc-arc -Iinclude -std=c++17 -Wno-unused-variable
WCCornerReverse_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

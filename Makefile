# 单架构：只出 arm64（arm64e 设备可直接加载 arm64 slice）
ARCHS = arm64
# 需要 iPhoneOS16.5.sdk；自己环境 SDK 版本不同就改这里的数字
TARGET = iphone:clang:16.5:14.0
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

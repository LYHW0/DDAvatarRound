TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = WeChat
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WCRefineRebuild

WCRefineRebuild_FILES = Tweak.x $(wildcard Sources/*.x) $(wildcard Sources/*.m)
WCRefineRebuild_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-property-ivar
WCRefineRebuild_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics CoreFoundation
WCRefineRebuild_LIBRARIES =

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 WeChat || true"

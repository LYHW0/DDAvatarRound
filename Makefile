TARGET := iphone:clang:latest:14.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = WeChat
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LYHW

LYHW_FILES = Tweak.x $(wildcard Sources/*.x) $(wildcard Sources/*.m)
LYHW_CFLAGS = -fobjc-arc -ISources -Wno-error -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-property-ivar
LYHW_FRAMEWORKS = UIKit Foundation QuartzCore CoreGraphics CoreFoundation CoreText
LYHW_LIBRARIES = z

SUBPROJECTS += prefs

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 WeChat || true"

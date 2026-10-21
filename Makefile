TARGET := iphone:clang:latest:14.0
ARCHS = arm64
export THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = WeChat

TWEAK_NAME = DDAvatarRound
DISPLAY_NAME = DD头像圆角
BUNDLE_ID = com.cyansmoke.ddavatarrond

DDAvatarRound_FILES = Sources/DDAvatarRound.xm Sources/DDSettingsVC.xm
DDAvatarRound_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DDAvatarRound_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall WeChat"

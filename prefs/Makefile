THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LYHWPrefs
LYHWPrefs_INSTALL_PATH = /Library/PreferenceBundles
LYHWPrefs_FILES = WCRRootListController.m
LYHWPrefs_FRAMEWORKS = UIKit Foundation
LYHWPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
LYHWPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
LYHWPrefs_LIBRARIES =

include $(THEOS_MAKE_PATH)/bundle.mk

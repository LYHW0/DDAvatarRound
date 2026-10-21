THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = WCRefineRebuildPrefs
WCRefineRebuildPrefs_INSTALL_PATH = /Library/PreferenceBundles
WCRefineRebuildPrefs_FILES = WCRRootListController.m
WCRefineRebuildPrefs_FRAMEWORKS = UIKit Foundation
WCRefineRebuildPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
WCRefineRebuildPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
WCRefineRebuildPrefs_LIBRARIES =

include $(THEOS_MAKE_PATH)/bundle.mk

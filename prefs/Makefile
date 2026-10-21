THEOS_PACKAGE_SCHEME = rootless

BUNDLE_NAME = WCRefineRebuildPrefs
WCRefineRebuildPrefs_INSTALL_PATH = /Library/PreferenceBundles
WCRefineRebuildPrefs_FILES = WCRRootListController.m
WCRefineRebuildPrefs_FRAMEWORKS = UIKit Foundation
WCRefineRebuildPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
WCRefineRebuildPrefs_LIBRARIES =
WCRefineRebuildPrefs_CLEAN_FILES =

include $(THEOS_MAKE_PATH)/bundle.mk

internal-all::
	@echo "prefs bundle built"

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MImport

$(TWEAK_NAME)_FILES = /mnt/d/codes/MImport/mimporthook/MImport.xm

$(TWEAK_NAME)_FRAMEWORKS = Foundation CydiaSubstrate UIKit CoreMedia CoreGraphics AVFoundation MobileCoreServices
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = StoreServices Preferences
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv6 armv7 armv7s arm64 arm64e
$(TWEAK_NAME)_ARCHS = armv6 armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk
	
	
all::
	
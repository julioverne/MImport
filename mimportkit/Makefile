include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MImportKit

$(TWEAK_NAME)_FILES = /mnt/d/codes/MImport/mimportkit/MImportKit.xm

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = 
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv6 armv7 armv7s arm64 arm64e
$(TWEAK_NAME)_ARCHS = armv6 armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk

all::

	

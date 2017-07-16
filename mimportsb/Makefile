include theos/makefiles/common.mk

TWEAK_NAME = MImportSB

MImportSB_FILES = /mnt/d/codes/MImport/mimportsb/MImportSB.xm

MImportSB_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate AudioToolbox
MImportSB_CFLAGS = -fobjc-arc -std=c++11
MImportSB_LDFLAGS = -Wl,-segalign,4000
export ARCHS = armv7 arm64
MImportSB_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::

	

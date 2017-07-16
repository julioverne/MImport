include theos/makefiles/common.mk

TWEAK_NAME = MImport
MImport_FILES = /mnt/d/codes/MImport/mimporthook/MImport.xm

MImport_FRAMEWORKS = Foundation CydiaSubstrate UIKit CoreMedia AVFoundation MobileCoreServices
MImport_PRIVATE_FRAMEWORKS = StoreServices Preferences
MImport_CFLAGS = -fobjc-arc -std=c++11 -fPIC -g
MImport_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv7 arm64
MImport_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	
	
all::
	
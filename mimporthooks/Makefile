include theos/makefiles/common.mk

TWEAK_NAME = MImport
MImport_FILES = MImport.xm

MImport_FRAMEWORKS = CydiaSubstrate UIKit CoreMedia AVFoundation
MImport_PRIVATE_FRAMEWORKS = StoreServices Preferences
MImport_CFLAGS = -fobjc-arc -std=c++11 -fPIC -g
MImport_LDFLAGS = -Wl,-segalign,4000
export ARCHS = armv7 arm64
MImport_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	
	
all::
	@echo "[+] Copying Files..."
	@cp -rf ./obj/debug/MImport.dylib //Library/MobileSubstrate/DynamicLibraries/MImport.dylib
	@/usr/bin/ldid -S //Library/MobileSubstrate/DynamicLibraries/MImport.dylib
	@cp ./MImport.plist //Library/MobileSubstrate/DynamicLibraries/MImport.plist
	@echo "DONE"
	
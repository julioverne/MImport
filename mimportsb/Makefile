include theos/makefiles/common.mk

TWEAK_NAME = MImportSB

MImportSB_FILES = MImportSB.xm

MImportSB_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate AudioToolbox
MImportSB_CFLAGS = -fobjc-arc -std=c++11
MImportSB_LDFLAGS = -Wl,-segalign,4000
export ARCHS = armv7 arm64
MImportSB_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "[+] Copying Files..."
	@cp ./obj/debug/MImportSB.dylib //Library/MobileSubstrate/DynamicLibraries/MImportSB.dylib
	@/usr/bin/ldid -S //Library/MobileSubstrate/DynamicLibraries/MImportSB.dylib
	@cp ./MImportSB.plist //Library/MobileSubstrate/DynamicLibraries/MImportSB.plist
	@echo "DONE"
	

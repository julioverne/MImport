include theos/makefiles/common.mk

TWEAK_NAME = MImportKit
MImportKit_FILES = MImportKit.xm

MImportKit_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate
MImportKit_PRIVATE_FRAMEWORKS = 
MImportKit_CFLAGS = -fobjc-arc -std=c++11
MImportKit_LDFLAGS = -lz -Wl,-segalign,4000 -Wl,-undefined,dynamic_lookup
export ARCHS = armv7 arm64
MImportKit_ARCHS = armv7 arm64
include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "[+] Copying Files..."
	@cp ./obj/MImportKit.dylib //Library/MobileSubstrate/DynamicLibraries/MImportKit.dylib
	@/usr/bin/ldid -S //Library/MobileSubstrate/DynamicLibraries/MImportKit.dylib
	@cp ./MImportKit.plist //Library/MobileSubstrate/DynamicLibraries/MImportKit.plist
	@echo "DONE"
	#@killall SpringBoard

	

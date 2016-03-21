include theos/makefiles/common.mk

TWEAK_NAME = MImport
MImport_FILES = MImport.xm

MImport_FRAMEWORKS = CydiaSubstrate AVFoundation UIKit CoreMedia
MImport_PRIVATE_FRAMEWORKS = StoreServices Preferences
MImport_LDFLAGS = -lz -shared -current_version 1.0.0 -compatibility_version 1.0.0
MImport_CFLAGS = -fobjc-arc -std=c++11 -fPIC -g #-pedantic -Wall -Wextra -ggdb3 

export ARCHS = armv7 arm64
MImport_ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/tweak.mk
	
	
all::
	@echo "[+] Copying Files..."
	@ldid -S ./obj/obj/debug/MImport.dylib
	@cp ./obj/obj/debug/MImport.dylib //Library/MobileSubstrate/DynamicLibraries/MImport.dylib
	@cp ./MImport.plist //Library/MobileSubstrate/DynamicLibraries/MImport.plist
	@echo "DONE"
	@killall Music
	
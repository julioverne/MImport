include theos/makefiles/common.mk

TWEAK_NAME = MImportCenter
MImportCenter_FILES = MImportCenter.xm

MImportCenter_FILES += MImportWebServer/MImportWebServer.m MImportWebServer/MImportWebServerConnection.m MImportWebServer/MImportWebServerDataResponse.m 
MImportCenter_FILES += MImportWebServer/MImportWebServerFileRequest.m MImportWebServer/MImportWebServerFileResponse.m MImportWebServer/MImportWebServerFunctions.m 
MImportCenter_FILES += MImportWebServer/MImportWebServerRequest.m MImportWebServer/MImportWebServerResponse.m MImportWebServer/MImportWebServerStreamedResponse.m 
MImportCenter_FILES += MImportWebServer/MImportWebServerURLEncodedFormRequest.m MImportWebServer/MImportWebServerMultiPartFormRequest.m 
MImportCenter_FILES += MImportWebServer/MImportWebServerDataRequest.m MImportWebServer/MImportWebServerErrorResponse.m

MImportCenter_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate CFNetwork MobileCoreServices AudioToolbox
MImportCenter_PRIVATE_FRAMEWORKS = 
MImportCenter_CFLAGS = -fobjc-arc -std=c++11
MImportCenter_LDFLAGS = -lz -Wl,-segalign,4000
export ARCHS = armv7 arm64
MImportCenter_ARCHS = armv7 arm64
include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "[+] Copying Files..."
	@cp ./obj/MImportCenter.dylib //Library/MobileSubstrate/DynamicLibraries/MImportCenter.dylib
	@/usr/bin/ldid -S //Library/MobileSubstrate/DynamicLibraries/MImportCenter.dylib
	@cp ./MImportCenter.plist //Library/MobileSubstrate/DynamicLibraries/MImportCenter.plist
	@echo "DONE"
	@killall SpringBoard

	

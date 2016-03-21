include theos/makefiles/common.mk

TWEAK_NAME = MImportCenter
MImportCenter_FILES = MImportCenter.xm

MImportCenter_FILES += GCDWebServer/GCDWebServer.m GCDWebServer/GCDWebServerConnection.m GCDWebServer/GCDWebServerDataResponse.m 
MImportCenter_FILES += GCDWebServer/GCDWebServerFileRequest.m GCDWebServer/GCDWebServerFileResponse.m GCDWebServer/GCDWebServerFunctions.m 
MImportCenter_FILES += GCDWebServer/GCDWebServerRequest.m GCDWebServer/GCDWebServerResponse.m GCDWebServer/GCDWebServerStreamedResponse.m 
MImportCenter_FILES += GCDWebServer/GCDWebServerURLEncodedFormRequest.m GCDWebServer/GCDWebServerMultiPartFormRequest.m 
MImportCenter_FILES += GCDWebServer/GCDWebServerDataRequest.m GCDWebServer/GCDWebServerErrorResponse.m

MImportCenter_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate CFNetwork MobileCoreServices AudioToolbox
MImportCenter_PRIVATE_FRAMEWORKS = AppSupport
MImportCenter_CFLAGS = -fobjc-arc -std=c++11
MImportCenter_LDFLAGS = -lz -Wl,-segalign,4000
export ARCHS = armv7 arm64
MImportCenter_ARCHS = armv7 arm64
include $(THEOS_MAKE_PATH)/tweak.mk

all::
	@echo "[+] Copying Files..."
	@ldid -S ./obj/MImportCenter.dylib
	@cp ./obj/MImportCenter.dylib //Library/MobileSubstrate/DynamicLibraries/MImportCenter.dylib
	@cp ./MImportCenter.plist //Library/MobileSubstrate/DynamicLibraries/MImportCenter.plist
	@echo "DONE"
	@killall SpringBoard

	

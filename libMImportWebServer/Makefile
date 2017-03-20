include theos/makefiles/common.mk

LIBRARY_NAME = libMImportWebServer

libMImportWebServer_FILES += MImportWebServer.m MImportWebServerConnection.m MImportWebServerDataResponse.m 
libMImportWebServer_FILES += MImportWebServerFileRequest.m MImportWebServerFileResponse.m MImportWebServerFunctions.m 
libMImportWebServer_FILES += MImportWebServerRequest.m MImportWebServerResponse.m MImportWebServerStreamedResponse.m 
libMImportWebServer_FILES += MImportWebServerURLEncodedFormRequest.m MImportWebServerMultiPartFormRequest.m 
libMImportWebServer_FILES += MImportWebServerDataRequest.m MImportWebServerErrorResponse.m

libMImportWebServer_INSTALL_PATH = /usr/lib
libMImportWebServer_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate CFNetwork MobileCoreServices
libMImportWebServer_CFLAGS = -fobjc-arc -std=c++11
libMImportWebServer_LDFLAGS = -lz -Wl,-segalign,4000
libMImportWebServer_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/library.mk


all::
	@echo "[+] Copying Files..."
	@cp ./obj/debug/libMImportWebServer.dylib /usr/lib/libMImportWebServer.dylib
	@/usr/bin/ldid -S /usr/lib/libMImportWebServer.dylib
	@echo "DONE"


include theos/makefiles/common.mk

LIBRARY_NAME = libMImportWebServer

libMImportWebServer_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServer.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerConnection.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerDataResponse.m 
libMImportWebServer_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFileRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFileResponse.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFunctions.m 
libMImportWebServer_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerResponse.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerStreamedResponse.m 
libMImportWebServer_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerURLEncodedFormRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerMultiPartFormRequest.m 
libMImportWebServer_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerDataRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerErrorResponse.m

libMImportWebServer_INSTALL_PATH = /usr/lib
libMImportWebServer_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate CFNetwork MobileCoreServices
libMImportWebServer_CFLAGS = -fobjc-arc -std=c++11
libMImportWebServer_LDFLAGS = -lz -Wl,-segalign,4000
libMImportWebServer_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/library.mk



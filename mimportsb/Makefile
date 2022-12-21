include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MImportSB

$(TWEAK_NAME)_FILES = /mnt/d/codes/MImport/mimportsb/MImportSB.xm

$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServer.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerConnection.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerDataResponse.m 
$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFileRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFileResponse.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerFunctions.m 
$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerResponse.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerStreamedResponse.m 
$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerURLEncodedFormRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerMultiPartFormRequest.m 
$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerDataRequest.m /mnt/d/codes/MImport/libMImportWebServer/MImportWebServerErrorResponse.m
$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/libMImportWebServer/MImportWebUploader.m

$(TWEAK_NAME)_FILES += /mnt/d/codes/MImport/mimportsb/id3/frame.mm /mnt/d/codes/MImport/mimportsb/id3/header.mm /mnt/d/codes/MImport/mimportsb/id3/id3v2lib.mm /mnt/d/codes/MImport/mimportsb/id3/types.mm /mnt/d/codes/MImport/mimportsb/id3/utils.mm

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreFoundation CydiaSubstrate AudioToolbox CFNetwork MobileCoreServices
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_LDFLAGS = -Wl,-segalign,4000

export ARCHS = armv6 armv7 armv7s arm64 arm64e
$(TWEAK_NAME)_ARCHS = armv6 armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/tweak.mk

include theos/makefiles/common.mk

BUNDLE_NAME = MImport
MImport_FILES = MImportController.mm
MImport_INSTALL_PATH = /Library/PreferenceBundles
MImport_FRAMEWORKS = UIKit QuartzCore CoreGraphics MessageUI Social Twitter
MImport_PRIVATE_FRAMEWORKS = Preferences
MImport_CFLAGS = -fobjc-arc
MImport_LDFLAGS = -Wl,-segalign,4000
MImport_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/bundle.mk

all::
	@echo "[+] Copying Files..."
	@cp ./obj/debug/MImport.bundle/MImport //Library/PreferenceBundles/MImport.bundle/MImport
	@/usr/bin/ldid -S //Library/PreferenceBundles/MImport.bundle/MImport
	@echo "DONE"
	
	
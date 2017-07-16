include theos/makefiles/common.mk

APPLICATION_NAME = mimportplugin
mimportplugin_FILES = /mnt/d/codes/MImport/mimportplugin/mimportplugin.mm
mimportplugin_FRAMEWORKS = UIKit #QuartzCore CoreGraphics
mimportplugin_PRIVATE_FRAMEWORKS = #Preferences
mimportplugin_CFLAGS = -fobjc-arc
mimportplugin_LDFLAGS = -Wl,-segalign,4000
mimportplugin_ARCHS = armv7 arm64
export ARCHS = armv7 arm64

include $(THEOS_MAKE_PATH)/application.mk

all::
	
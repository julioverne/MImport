include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = mimportplugin

$(APPLICATION_NAME)_FILES = /mnt/d/codes/MImport/mimportplugin/mimportplugin.mm
$(APPLICATION_NAME)_FRAMEWORKS = UIKit #QuartzCore CoreGraphics
$(APPLICATION_NAME)_CFLAGS = -fobjc-arc
$(APPLICATION_NAME)_LDFLAGS = -Wl,-segalign,4000

$(APPLICATION_NAME)_ARCHS = armv6 armv7 armv7s arm64 arm64e
export ARCHS = armv6 armv7 armv7s arm64 arm64e

include $(THEOS_MAKE_PATH)/application.mk

all::
	
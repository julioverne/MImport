include $(THEOS)/makefiles/common.mk

SUBPROJECTS += mimporthook
SUBPROJECTS += mimportkit
SUBPROJECTS += mimportsb
SUBPROJECTS += mimportsettings
SUBPROJECTS += mimportplugin

include $(THEOS_MAKE_PATH)/aggregate.mk

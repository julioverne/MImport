include theos/makefiles/common.mk

SUBPROJECTS += libMImportWebServer
SUBPROJECTS += mimporthook
SUBPROJECTS += mimportkit
SUBPROJECTS += mimportsb
SUBPROJECTS += mimportsettings
SUBPROJECTS += mimportplugin

include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	

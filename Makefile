include theos/makefiles/common.mk

SUBPROJECTS += mimporthooks
SUBPROJECTS += libMImportWebServer
SUBPROJECTS += mimportkit
SUBPROJECTS += mimportsb
SUBPROJECTS += mimportsettings

include $(THEOS_MAKE_PATH)/aggregate.mk

all::
	@echo "[+] Killing SpringBoard..."
	@killall SpringBoard || true
	@echo "DONE"
	

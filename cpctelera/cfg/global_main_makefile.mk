##-----------------------------LICENSE NOTICE------------------------------------
##  This file is part of CPCtelera: An Amstrad CPC Game Engine 
##  Copyright (C) 2015 ronaldo / Fremos / Cheesetea / ByteRealms (@FranGallegoBR)
##
##  This program is free software: you can redistribute it and/or modify
##  it under the terms of the GNU Lesser General Public License as published by
##  the Free Software Foundation, either version 3 of the License, or
##  (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU Lesser General Public License for more details.
##
##  You should have received a copy of the GNU Lesser General Public License
##  along with this program.  If not, see <http://www.gnu.org/licenses/>.
##------------------------------------------------------------------------------

###########################################################################
##                          CPCTELERA ENGINE                             ##
##                  Main Building Makefile for Projects                  ##
##-----------------------------------------------------------------------##
## This file contains the rules for building a CPCTelera project. These  ##
## These rules work generically for every CPCTelera project.             ##
## Usually, this file should be left unchanged:                          ##
##  * Project's build configuration is to be found in build_config.mk    ##
##  * Global paths and tool configuration is located at $(CPCT_PATH)/cfg/##
###########################################################################
# Logfile where load and run addresses for the generated binary will be logged
BINADDRLOG   := $(OBJDIR)/binaryAddresses.log
PREBUILD_OBJ := $(OBJDIR)/prebuildstep.objectfile

#######
####### ANDROIN HEADER BEGIN
#######

# Create your owen certfication
# Command: keytool -genkey -keystore cert.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias cert
# Remember, use password: "android"

CUSTOM_APP_NAME   := My Custom Name
CUSTOM_APP_ID     := org.cpctelera.customid
CUSTOM_APP_CERT   := cert.keystore

# PATHS
APKRENAME_PATH  := $(CPCT_PATH)tools/apkrename/
APKTOOL_PATH    := $(CPCT_PATH)tools/apktool/
AND_OBJDIR   := $(OBJDIR)/_android/
AND_ASSETS   := assets/android/

# TOOLS
ZIPALIGN  := zipalign
JARSIGNER := jarsigner
RVMENGINE := $(CPCT_PATH)tools/rvmengine/app.apk
APKTOOL   := java -jar $(APKTOOL_PATH)apktool_2.4.0.jar
APKRENAME := $(APKRENAME_PATH)apkRename.sh

#######
####### ANDROIN HEADER END
#######

.PHONY: all clean cleanall

# MAIN TARGET
.DEFAULT_GOAL := all
all: $(OBJSUBDIRS) $(PREBUILD_OBJ) $(TARGET)

## COMPILING SOURCEFILES AND SAVE OBJFILES IN THEIR CORRESPONDENT SUBDIRS
$(foreach OF, $(BIN_OBJFILES), $(eval $(call BINFILE2C, $(OF), $(OF:%.$(C_EXT)=%.$(BIN_EXT)))))
$(foreach OF, $(GENC_OBJFILES), $(eval $(call COMPILECFILE, $(OF), $(patsubst $(OBJDIR)%,$(SRCDIR)%,$(OF:%.$(OBJ_EXT)=%.$(C_EXT))))))
$(foreach OF, $(GENASM_OBJFILES), $(eval $(call COMPILEASMFILE, $(OF), $(patsubst $(OBJDIR)%,$(SRCDIR)%,$(OF:%.$(OBJ_EXT)=%.$(ASM_EXT))))))
$(foreach OF, $(C_OBJFILES), $(eval $(call COMPILECFILE, $(OF), $(patsubst $(OBJDIR)%,$(SRCDIR)%,$(OF:%.$(OBJ_EXT)=%.$(C_EXT))))))
$(foreach OF, $(ASM_OBJFILES), $(eval $(call COMPILEASMFILE, $(OF), $(patsubst $(OBJDIR)%,$(SRCDIR)%,$(OF:%.$(OBJ_EXT)=%.$(ASM_EXT))))))
## Generate an Add-BIN-to-DSK rule for each Binary file in DSKFILESDIR
$(foreach SF, $(DSKINCSRCFILES), $(eval $(call ADDBINFILETODSK, $(DSK), $(SF), $(patsubst $(DSKFILESDIR)/%, $(OBJDSKINCSDIR)/%, $(SF)).$(DSKINC_EXT))))

# Files to be created if they do not exist (for compatibility)
$(TOUCHIFNOTEXIST):
	@$(TOUCH) $(TOUCHIFNOTEXIST)

# PREVIOUS BUILDING STEP (CONVERSION TOOLS NORMALLY)
$(PREBUILD_OBJ): $(IMGCFILES) $(IMGASMFILES) $(IMGBINFILES) $(PREBUILDOBJS)
	@$(call PRINT,$(PROJNAME),"")
	@$(call PRINT,$(PROJNAME),"=== PREBUILD PROCCESSING DONE!")
	@$(call PRINT,$(PROJNAME),"============================================================")
	@$(call PRINT,$(PROJNAME),"")
	@touch $(PREBUILD_OBJ)

# LINK RELOCATABLE MACHINE CODE FILES (.REL) INTO A INTEL HEX BINARY (.IHX)
$(IHXFILE): $(NONLINKGENFILES) $(GENOBJFILES) $(OBJFILES)
	@$(call PRINT,$(PROJNAME),"Linking binary file")
	$(Z80CC) $(Z80CCLINKARGS) $(GENOBJFILES) $(OBJFILES) -o "$@"

# GENERATE BINARY FILE (.BIN) FROM INTEL HEX BINARY (.IHX)
$(BINFILE): $(IHXFILE)
	@$(call PRINT,$(PROJNAME),"Creating Amsdos binary file $@")
	$(HEX2BIN) -p 00 "$<" | $(TEE) $@.log

# CREATE BINARY AND GET LOAD AND RUN ADDRESS FROM LOGFILE AND MAPFILE
$(BINADDRLOG): $(BINFILE)
	@$(call GETALLADDRESSES,$<)
	@echo "Generated Binary File $(BINFILE):" > $(BINADDRLOG)
	@echo "Load Address = $(LOADADDR)"       >> $(BINADDRLOG)
	@echo "Run  Address = $(RUNADDR)"        >> $(BINADDRLOG)

# GENERATE A DISK FILE (.DSK) AND INCLUDE BINARY FILE (.BIN) INTO IT
$(DSK): $(BINFILE) $(BINADDRLOG)
	@$(call GETALLADDRESSES,$<)
	@$(call PRINT,$(PROJNAME),"Creating Disk File '$@'")
	@$(call CREATEEMPTYDSK,$@)
	@$(call ADDCODEFILETODSK,$@,$<,$(LOADADDR),$(RUNADDR),$(<:%=%.$(DSKINC_EXT)))
	@$(call PRINT,$(PROJNAME),"Successfully created '$@'")

# GENERATE A CASSETTE FILE (.CDT) AND INCLUDE BINARY FILE (.BIN) INTO IT
$(CDT): $(BINFILE) $(BINADDRLOG) $(CDTMANOBJS)
	@$(call PRINT,$(PROJNAME),"Creating Cassette file '$@'")
	@$(call CREATECDT,)
	@$(call PRINT,$(PROJNAME),"Successfully created '$@'")

# GENERATE A SNAPSHOP FILE (.SNA) AND INCLUDE BINARY FILE (.BIN) INTO IT
$(SNA): $(BINFILE) $(BINADDRLOG)
	@$(call GETALLADDRESSES,$<)
	@$(call PRINT,$(PROJNAME),"Creating Snapshot File '$@'")
	@$(call CREATESNA,$<,$@,$(LOADADDR),$(RUNADDR))
	@$(call PRINT,$(PROJNAME),"Successfully created '$@'") #######
	@$(call PRINT,$(PROJNAME),"Creating Android APK 'game.apk'")

#######
####### ANDROIN PROCEDURE BEGIN
#######

# DECODE APK
	@$(APKTOOL) decode $(RVMENGINE) -f -o $(AND_OBJDIR)

# REPLACE ASSETS
	@$(CP) game.sna $(AND_OBJDIR)assets/payload.sna
	@$(CP) -R $(AND_ASSETS)* $(AND_OBJDIR)

# REPLACE APPLICATION NAME
	@sed -i -e '/<resources>/,/<\/resources>/ s|<string name="app_name">[0-9a-Z.]\{1,\}</string>|<string name="app_name">$(CUSTOM_APP_NAME)</string>|g' $(AND_OBJDIR)res/values/strings.xml

# BUILD APK
	@$(APKTOOL) build $(AND_OBJDIR) -o game.apk

# REPLACE APPLICATION ID
	@$(APKRENAME) game.apk $(CUSTOM_APP_ID)
	@$(RM) -rf tmpForApkRename

# SIGN APK
	@$(JARSIGNER) -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore cert.keystore -storepass android game.apk cert

# ALIGN APK
	@mv game.apk game.apk.tmp
	@$(ZIPALIGN) -f -p 4 game.apk.tmp game.apk
	@$(RM) game.apk.tmp

	@$(call PRINT,$(PROJNAME),"Successfully created 'game.apk'")
#######
####### ANDROID PROCEDURE END
#######

## Include files in DSKFILESDIR to DSK, print a message and generate a flag file DSKINC
$(DSKINC): $(DSK) $(DSKINCOBJFILES)
	@$(call PRINT,$(PROJNAME),"All files added to $(DSK). Disc ready.")
	@touch $(DSKINC)

# CREATE OBJDIR & SUBDIRS IF THEY DO NOT EXIST
$(OBJSUBDIRS): 
	@$(MKDIR) $@

# CLEANING TARGETS
cleanall: clean
	@$(call PRINT,$(PROJNAME),"Deleting $(TARGET)")
	$(RM) $(TARGET)

clean: 
	@$(call PRINT,$(PROJNAME),"Deleting folder: $(OBJDIR)/")
	$(RM) -r ./$(OBJDIR)
	@$(call PRINT,$(PROJNAME),"Deleting objects to clean: $(OBJS2CLEAN)")
	$(foreach elem, $(OBJS2CLEAN), $(RM) -r ./$(elem))

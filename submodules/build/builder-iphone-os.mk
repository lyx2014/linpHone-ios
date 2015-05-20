############################################################################
# builder-generic.mk
# Copyright (C) 2009  Belledonne Communications,Grenoble France
#
############################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
############################################################################

host?=armv7-apple-darwin.ios
enable_i386?=no
config_site:=iphone-config.site
library_mode:= --disable-shared --enable-static
linphone_configure_controls = \
				--with-readline=none  \
				--enable-gtk_ui=no \
				--enable-console_ui=no \
				--with-gsm=$(prefix) \
				--with-srtp=$(prefix) \
				--with-antlr=$(prefix) \
				--disable-strict \
				--disable-nls \
				--disable-theora \
				--disable-sdl \
				--disable-x11 \
				--disable-tutorials \
				--disable-tools \
				--enable-msg-storage=yes \
				--with-polarssl=$(prefix) \
				--enable-dtls


#path
BUILDER_SRC_DIR?=$(shell pwd)/../
ifeq ($(enable_debug),yes)
BUILDER_BUILD_DIR?=$(shell pwd)/../build-$(host)-debug
linphone_configure_controls += CFLAGS="-g"
prefix?=$(BUILDER_SRC_DIR)/../liblinphone-sdk/$(host)-debug
else
BUILDER_BUILD_DIR?=$(shell pwd)/../build-$(host)
prefix?=$(BUILDER_SRC_DIR)/../liblinphone-sdk/$(host)
endif

LINPHONE_SRC_DIR=$(BUILDER_SRC_DIR)/linphone
LINPHONE_BUILD_DIR=$(BUILDER_BUILD_DIR)/linphone
LINPHONE_IPHONE_VERSION=$(shell git describe --always)

# list of the submodules to build, the order is important
MEDIASTREAMER_PLUGINS := msilbc \
						libilbc-rfc3951 \
						msamr \
						mssilk \
						msx264 \
						msopenh264 \
						msbcg729
# TODO: add mswebrtc when it is commatible again


SUBMODULES_LIST := polarssl

ifeq ($(enable_tunnel),yes)
SUBMODULES_LIST += tunnel
endif

SUBMODULES_LIST +=	antlr3 \
					cunit \
					belle-sip \
					srtp \
					speex \
					libgsm \
					libvpx \
					libxml2 \
					bzrtp \
					ffmpeg \
					opus

# build linphone (which depends on submodules) and then the plugins
all: build-linphone $(addprefix build-,$(MEDIASTREAMER_PLUGINS))



####################################################################
# setup the switches that might trigger a linphone recompilation
####################################################################

enable_gpl_third_parties?=yes
enable_ffmpeg?=yes
enable_zrtp?=yes

SWITCHES:=

ifeq ($(enable_zrtp), yes)
                linphone_configure_controls+= --enable-zrtp
                SWITCHES += enable_zrtp
else
                linphone_configure_controls+= --disable-zrtp
                SWITCHES += disable_zrtp
endif

ifeq ($(enable_tunnel), yes)
                linphone_configure_controls+= --enable-tunnel
                SWITCHES += enable_tunnel
else
                linphone_configure_controls+= --disable-tunnel
                SWITCHES += disable_tunnel
endif

ifeq ($(enable_gpl_third_parties),yes)
	SWITCHES+= enable_gpl_third_parties

	ifeq ($(enable_ffmpeg), yes)
		linphone_configure_controls+= --enable-ffmpeg
		SWITCHES += enable_ffmpeg
	else
		linphone_configure_controls+= --disable-ffmpeg
		SWITCHES += disable_ffmpeg
	endif

else # !enable gpl
	linphone_configure_controls+= --disable-ffmpeg
	SWITCHES += disable_gpl_third_parties disable_ffmpeg
endif

SWITCHES := $(addprefix $(LINPHONE_BUILD_DIR)/,$(SWITCHES))

mode_switch_check: $(SWITCHES)
#generic rule to force recompilation of linphone if some options require it
$(LINPHONE_BUILD_DIR)/enable_% $(LINPHONE_BUILD_DIR)/disable_%:
	mkdir -p $(LINPHONE_BUILD_DIR)
	cd $(LINPHONE_BUILD_DIR) && rm -f *able_$*
	touch $@
	cd $(LINPHONE_BUILD_DIR) && rm -f Makefile && rm -f oRTP/Makefile && rm -f mediastreamer2/Makefile

####################################################################
# Base rules:
####################################################################


clean-makefile: clean-makefile-linphone
clean: clean-linphone
init:
	mkdir -p $(prefix)/include
	mkdir -p $(prefix)/lib/pkgconfig

veryclean: veryclean-linphone
	rm -rf $(BUILDER_BUILD_DIR)

list-packages:
	@echo "Submodules:"
	@echo "$(addprefix \nbuild-,$(SUBMODULES_LIST))"
	@echo "\nPlugins: "
	@echo "$(addprefix \nbuild-,$(MEDIASTREAMER_PLUGINS))"

####################################################################
# Linphone compilation
####################################################################

build-submodules: $(addprefix build-,$(SUBMODULES_LIST))

.NOTPARALLEL build-linphone: init build-submodules mode_switch_check $(LINPHONE_BUILD_DIR)/Makefile
	cd $(LINPHONE_BUILD_DIR) && \
	export PKG_CONFIG_LIBDIR=$(prefix)/lib/pkgconfig && \
	export CONFIG_SITE=$(BUILDER_SRC_DIR)/build/$(config_site) && \
	make newdate && make all && make install
	mkdir -p $(prefix)/share/linphone/tutorials && cp -f $(LINPHONE_SRC_DIR)/coreapi/help/*.c $(prefix)/share/linphone/tutorials/

clean-linphone: $(addprefix clean-,$(SUBMODULES_LIST)) $(addprefix clean-,$(MEDIASTREAMER_PLUGINS))
	cd  $(LINPHONE_BUILD_DIR) && make clean

veryclean-linphone: $(addprefix veryclean-,$(SUBMODULES_LIST)) $(addprefix veryclean-,$(MEDIASTREAMER_PLUGINS))
#-cd $(LINPHONE_BUILD_DIR) && make distclean
	-cd $(LINPHONE_SRC_DIR) && rm -f configure

clean-makefile-linphone: $(addprefix clean-makefile-,$(SUBMODULES_LIST)) $(addprefix clean-makefile-,$(MEDIASTREAMER_PLUGINS))
	cd $(LINPHONE_BUILD_DIR) && rm -f Makefile && rm -f oRTP/Makefile && rm -f mediastreamer2/Makefile


$(LINPHONE_SRC_DIR)/configure:
	cd $(LINPHONE_SRC_DIR) && ./autogen.sh

$(LINPHONE_BUILD_DIR)/Makefile: $(LINPHONE_SRC_DIR)/configure
	mkdir -p $(LINPHONE_BUILD_DIR)
	@echo -e "\033[1mPKG_CONFIG_LIBDIR=$(prefix)/lib/pkgconfig CONFIG_SITE=$(BUILDER_SRC_DIR)/build/$(config_site) \
        $(LINPHONE_SRC_DIR)/configure -prefix=$(prefix) --host=$(host) ${library_mode} \
        ${linphone_configure_controls}\033[0m"
	cd $(LINPHONE_BUILD_DIR) && \
	PKG_CONFIG_LIBDIR=$(prefix)/lib/pkgconfig CONFIG_SITE=$(BUILDER_SRC_DIR)/build/$(config_site) \
	$(LINPHONE_SRC_DIR)/configure -prefix=$(prefix) --host=$(host) ${library_mode} \
	${linphone_configure_controls}


#libphone only (asume dependencies are met)
build-liblinphone: $(LINPHONE_BUILD_DIR)/Makefile
	cd $(LINPHONE_BUILD_DIR)  && export PKG_CONFIG_LIBDIR=$(prefix)/lib/pkgconfig export CONFIG_SITE=$(BUILDER_SRC_DIR)/build/$(config_site) make newdate &&  make  && make install

clean-makefile-liblinphone:
	 cd $(LINPHONE_BUILD_DIR) && rm -f Makefile && rm -f oRTP/Makefile && rm -f mediastreamer2/Makefile

clean-liblinphone:
	 cd  $(LINPHONE_BUILD_DIR) && make clean


include builders.d/*.mk

####################################################################
# sdk generation and distribution
####################################################################

multi-arch:
	@arm_archives=`find $(prefix) -name *.a` ;\
	mkdir -p $(prefix)/../apple-darwin; \
	cp -rf $(prefix)/include  $(prefix)/../apple-darwin/. ; \
	cp -rf $(prefix)/share  $(prefix)/../apple-darwin/. ; \
	for archive in $$arm_archives ; do \
		i386_path=`echo $$archive | sed -e "s/armv7/i386/"` ;\
		arm64_path=`echo $$archive | sed -e "s/armv7/aarch64/"` ;\
		x64_path=`echo $$archive | sed -e "s/armv7/x86_64/"` ;\
		destpath=`echo $$archive | sed -e "s/-debug//" | sed -e "s/armv7-//" | sed -e "s/\.ios//"` ;\
		all_paths=`echo $$archive $$arm64_path`; \
		all_archs="armv7,aarch64"; \
		mkdir -p `dirname $$destpath` ; \
		if test $(enable_i386) = yes ; then \
			if test -f "$$i386_path"; then \
				all_paths=`echo $$all_paths $$i386_path`; \
				all_archs="$$all_archs,i386" ; \
			else \
				echo "WARNING: archive `basename $$archive` exists in arm tree but does not exists in i386 tree: $$i386_path."; \
			fi; \
		fi; \
		if test -f "$$x64_path"; then \
			all_paths=`echo $$all_paths $$x64_path`; \
			all_archs="$$all_archs,x86_64" ; \
		else \
			echo "WARNING: archive `basename $$archive` exists in arm tree but does not exists in x86_64 tree: $$x64_path."; \
		fi; \
		echo "[$$all_archs] Mixing `basename $$archive` in $$destpath"; \
		lipo -create $$all_paths -output $$destpath; \
	done
	if ! test -f $(prefix)/../apple-darwin/lib/libtunnel.a ; then \
		cp -f $(BUILDER_SRC_DIR)/../submodules/binaries/libdummy.a $(prefix)/../apple-darwin/lib/libtunnel.a ; \
	fi


delivery-sdk: multi-arch
	echo "Generating SDK zip file for version $(LINPHONE_IPHONE_VERSION)"
	cd $(BUILDER_SRC_DIR)/../ \
	&& zip -r $(BUILDER_SRC_DIR)/liblinphone-iphone-sdk-$(LINPHONE_IPHONE_VERSION).zip \
	liblinphone-sdk/apple-darwin \
	liblinphone-tutorials \
	-x liblinphone-tutorials/hello-world/build\* \
	-x liblinphone-tutorials/hello-world/hello-world.xcodeproj/*.pbxuser \
	-x liblinphone-tutorials/hello-world/hello-world.xcodeproj/*.mode1v3

download-sdk:
	@echo "Downloading the latest binary SDK"
	cd $(BUILDER_SRC_DIR)/../
	rm -fr liblinphone-iphone-sdk-latest*
	wget http://linphone.org/snapshots/ios/liblinphone-iphone-sdk-latest.zip
	unzip -o -q liblinphone-iphone-sdk-latest.zip
	rm -fr ../../liblinphone-sdk/
	mv liblinphone-sdk ../..

.PHONY delivery:
	cd $(BUILDER_SRC_DIR)/../../ \
	&& zip  -r   $(BUILDER_SRC_DIR)/linphone-iphone.zip \
	linphone-iphone  \
	-x linphone-iphone/build\* \
	--exclude linphone-iphone/.git\* --exclude \*.[od] --exclude \*.so.\* --exclude \*.a  --exclude linphone-iphone/liblinphone-sdk/apple-darwin/\* --exclude \*.lo

ipa:
	cd $(BUILDER_SRC_DIR)/../ \
	&& xcodebuild  -configuration Release \
	&& xcrun -sdk iphoneos PackageApplication -v build/Release-iphoneos/linphone.app -o $(BUILDER_SRC_DIR)/../linphone-iphone.ipa


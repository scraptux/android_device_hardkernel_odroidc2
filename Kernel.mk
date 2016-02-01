#if use probuilt kernel or build kernel from source code
-include device/hardkernel/common/gpu64.mk

INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel

KERNEL_ARCH := arm64
KERNEL_DEVICETREE := meson64_odroidc2
KERNEL_DEFCONFIG := odroidc2_defconfig

KERNEL_ROOTDIR := kernel
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
KERNEL_IMAGE := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image.lzo
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
BOARD_MKBOOTIMG_ARGS := --second $(PRODUCT_OUT)/$(KERNEL_DEVICETREE).dtb

PREFIX_CROSS_COMPILE=$(CROSS_COMPILE)

define cp-modules
	mkdir -p $(PRODUCT_OUT)/root/boot

	cp $(MALI_OUT)/mali.ko $(PRODUCT_OUT)/root/boot
	cp $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/dts/$(KERNEL_DEVICETREE).dtb $(PRODUCT_OUT)/
endef

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
	if [ "$$mdpath" != "" ]; then \
	mpath=`dirname $$mdpath`;\
	ko=`find $$mpath/kernel $$mpath/hardware -type f -name *.ko`;\
	for i in $$ko; do echo $$i; mv $$i $(KERNEL_MODULES_OUT)/; done;\
	fi;\
	ko=`find hardware/amlogic/thermal -type f -name *.ko`;\
	for i in $$ko; do echo $$i; mv $$i $(KERNEL_MODULES_OUT)/; done;
	ko=`find hardware/backports -type f -name *.ko`;\
	mkdir -p $(KERNEL_MODULES_OUT)/backports; \
	for i in $$ko; do echo $$i; mv $$i $(KERNEL_MODULES_OUT)/backports/; done;
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.dep`;\
       if [ "$$mdpath" != "" ];then\
       mpath=`dirname $$mdpath`; rm -rf $$mpath;\
       fi
endef

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C $(KERNEL_ROOTDIR) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) $(KERNEL_DEFCONFIG)

$(KERNEL_IMAGE): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(KERNEL_ROOTDIR) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE)
	$(MAKE) -C $(KERNEL_ROOTDIR) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) \
		INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP=1 \
		modules_install
	$(MAKE) -C $(shell pwd)/$(PRODUCT_OUT)/obj/KERNEL_OBJ \
		M=$(shell pwd)/hardware/amlogic/thermal/ ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) modules
	$(MAKE) -C hardware/backports O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) KLIB_BUILD=../../$(KERNEL_OUT) \
		defconfig-odroidc
	$(MAKE) -C hardware/backports O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) KLIB_BUILD=../../$(KERNEL_OUT)
	$(gpu-modules)
	$(cp-modules)
	$(mv-modules)
	$(clean-module-folder)

.PHONY: kernelconfig
kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
		$(MAKE) -C $(KERNEL_ROOTDIR) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) menuconfig

.PHONY: savekernelconfig
savekernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
		$(MAKE) -C $(KERNEL_ROOTDIR) O=../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) \
		CROSS_COMPILE=$(PREFIX_CROSS_COMPILE) savedefconfig
	@echo
	@echo Saved to $(KERNEL_OUT)/defconfig
	@echo
	@echo handly merge to "$(KERNEL_ROOTDIR)/arch/$(KERNEL_ARCH)/configs/$(KERNEL_DEFCONFIG)" if need
	@echo

$(INSTALLED_KERNEL_TARGET): $(KERNEL_IMAGE) | $(ACP)
	@echo "Kernel installed"
	$(transform-prebuilt-to-target)

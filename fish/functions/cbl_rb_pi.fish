#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_rb_pi -d "Rebase Raspberry Pi kernel on latest linux-next"
    in_container_msg -c; or return

    set pi_src $CBL_BLD/rpi

    for arg in $argv
        switch $arg
            case -s --skip-mainline
                set skip_mainline true
        end
    end

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20221003193759.1141709-1-nathan@kernel.org/ # arm64: alternatives: Use vdso/bits.h instead of linux/bits.h
    for patch in $patches
        b4 am -l -o - -P _ -s $patch | git am; or return
    end

    # Regenerate defconfigs
    for arch in arm arm64
        switch $arch
            case arm
                set config multi_v7_defconfig
            case arm64
                set config defconfig
        end
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=.build/$arch $config savedefconfig; or return
        mv -v .build/$arch/defconfig arch/$arch/configs/$config
    end
    git ac -m "ARM: configs: savedefconfig"

    # Tailscale configs
    for cfg_file in arch/arm/configs/multi_v7_defconfig arch/arm64/configs/defconfig
        scripts/config \
            --file $cfg_file \
            -e IP_NF_IPTABLES \
            -e NETFILTER \
            -e NETFILTER_NETLINK \
            -e NETFILTER_XTABLES \
            -e NETFILTER_XT_MATCH_COMMENT \
            -e NETFILTER_XT_MARK \
            -e NETFILTER_XT_TARGET_MASQUERADE \
            -e NF_CONNTRACK \
            -e NF_NAT \
            -e NF_TABLES \
            -e NF_TABLES_IPV4 \
            -e NF_TABLES_IPV6 \
            -e NFT_COMPAT \
            -e NFT_NAT \
            -e TUN
    end

    # arm64 hardening
    scripts/config \
        --file arch/arm64/configs/defconfig \
        -d LTO_NONE \
        -e CFI_CLANG \
        -e LTO_CLANG_THIN \
        -e SHADOW_CALL_STACK

    # Disable DEBUG_INFO for smaller builds
    if grep -q "config DEBUG_INFO_NONE" lib/Kconfig.debug
        set sc_args -e DEBUG_INFO_NONE
    else
        set sc_args -d DEBUG_INFO
    end
    # Always enable -Werror
    set -a sc_args -e WERROR
    # Shut up -Wframe-larger-than
    set -a sc_args --set-val FRAME_WARN 0
    for cfg in arch/arm/configs/multi_v7_defconfig arch/arm64/configs/defconfig
        scripts/config --file $cfg $sc_args
    end

    # Ensure configs are run through savedefconfig before committing
    for arch in arm arm64
        switch $arch
            case arm
                set config multi_v7_defconfig
            case arm64
                set config defconfig
        end
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=.build/$arch $config savedefconfig; or return
        mv -v .build/$arch/defconfig arch/$arch/configs/$config
    end
    git ac -m "ARM: configs: Update defconfigs"

    echo 'From f16e7af3d188d6aa9d45d7502ba3fcebc441f22a Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Wed, 28 Jul 2021 12:14:27 -0700
Subject: [PATCH] ARM: dts: bcm2{711,837}: Disable the display pipeline

Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 arch/arm/boot/dts/bcm2711-rpi-4-b.dts      | 16 ++++++++--------
 arch/arm/boot/dts/bcm2837-rpi-3-b-plus.dts |  2 +-
 arch/arm/boot/dts/bcm2837-rpi-3-b.dts      |  2 +-
 3 files changed, 10 insertions(+), 10 deletions(-)

diff --git a/arch/arm/boot/dts/bcm2711-rpi-4-b.dts b/arch/arm/boot/dts/bcm2711-rpi-4-b.dts
index f24bdd0870a5..66cfc5d057ce 100644
--- a/arch/arm/boot/dts/bcm2711-rpi-4-b.dts
+++ b/arch/arm/boot/dts/bcm2711-rpi-4-b.dts
@@ -57,11 +57,11 @@ sd_vcc_reg: sd_vcc_reg {
 };
 
 &ddc0 {
-	status = "okay";
+	status = "disabled";
 };
 
 &ddc1 {
-	status = "okay";
+	status = "disabled";
 };
 
 &expgpio {
@@ -149,27 +149,27 @@ &gpio {
 };
 
 &hdmi0 {
-	status = "okay";
+	status = "disabled";
 };
 
 &hdmi1 {
-	status = "okay";
+	status = "disabled";
 };
 
 &pixelvalve0 {
-	status = "okay";
+	status = "disabled";
 };
 
 &pixelvalve1 {
-	status = "okay";
+	status = "disabled";
 };
 
 &pixelvalve2 {
-	status = "okay";
+	status = "disabled";
 };
 
 &pixelvalve4 {
-	status = "okay";
+	status = "disabled";
 };
 
 &pwm1 {
diff --git a/arch/arm/boot/dts/bcm2837-rpi-3-b-plus.dts b/arch/arm/boot/dts/bcm2837-rpi-3-b-plus.dts
index 61010266ca9a..e1a6c95f65f9 100644
--- a/arch/arm/boot/dts/bcm2837-rpi-3-b-plus.dts
+++ b/arch/arm/boot/dts/bcm2837-rpi-3-b-plus.dts
@@ -128,7 +128,7 @@ &gpio {
 &hdmi {
 	hpd-gpios = <&gpio 28 GPIO_ACTIVE_LOW>;
 	power-domains = <&power RPI_POWER_DOMAIN_HDMI>;
-	status = "okay";
+	status = "disabled";
 };
 
 &pwm {
diff --git a/arch/arm/boot/dts/bcm2837-rpi-3-b.dts b/arch/arm/boot/dts/bcm2837-rpi-3-b.dts
index dd4a48604097..ab2173e3951b 100644
--- a/arch/arm/boot/dts/bcm2837-rpi-3-b.dts
+++ b/arch/arm/boot/dts/bcm2837-rpi-3-b.dts
@@ -127,7 +127,7 @@ &pwm {
 &hdmi {
 	hpd-gpios = <&expgpio 4 GPIO_ACTIVE_LOW>;
 	power-domains = <&power RPI_POWER_DOMAIN_HDMI>;
-	status = "okay";
+	status = "disabled";
 };
 
 /* uart0 communicates with the BT module */
-- 
2.32.0.264.g75ae10bc75

' | git ams; or return

    for arch in arm arm64
        ../pi-scripts/build.fish $arch; or return
    end

    if test "$skip_mainline" != true
        if not git pll --no-edit mainline master
            rg "<<<<<<< HEAD"; and return
            for arch in arm arm64
                ../pi-scripts/build.fish $arch; or return
            end
            git aa
            git c --no-edit; or return
        end

        for arch in arm arm64
            ../pi-scripts/build.fish $arch; or return
        end
    end

    popd
end

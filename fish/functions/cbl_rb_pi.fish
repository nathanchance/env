#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_rb_pi -d "Rebase Raspberry Pi kernel on latest linux-next"
    set pi_src $CBL_BLD/rpi

    for arg in $argv
        switch $arg
            case -s --skip-mainline
                set skip_mainline true
        end
    end

    set fish_trace 1

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    echo 'From 9e4b305c284a64530ca8f6c81c7d7d5006d94139 Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Mon, 27 Dec 2021 10:30:20 -0700
Subject: [PATCH] scsi: hisi_sas: Fix -Wuninitialized in
 hisi_sas_send_ata_reset_each_phy()

Link: https://lore.kernel.org/r/Ycn3FoW9eOZNFMiL@archlinux-ax161/
Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 drivers/scsi/hisi_sas/hisi_sas_main.c | 3 +--
 1 file changed, 1 insertion(+), 2 deletions(-)

diff --git a/drivers/scsi/hisi_sas/hisi_sas_main.c b/drivers/scsi/hisi_sas/hisi_sas_main.c
index f46f679fe825..8cf607f63220 100644
--- a/drivers/scsi/hisi_sas/hisi_sas_main.c
+++ b/drivers/scsi/hisi_sas/hisi_sas_main.c
@@ -1525,7 +1525,6 @@ static void hisi_sas_send_ata_reset_each_phy(struct hisi_hba *hisi_hba,
 	struct device *dev = hisi_hba->dev;
 	int s = sizeof(struct host_to_dev_fis);
 	int rc = TMF_RESP_FUNC_FAILED;
-	struct asd_sas_phy *sas_phy;
 	struct ata_link *link;
 	u8 fis[20] = {0};
 	u32 state;
@@ -1533,7 +1532,7 @@ static void hisi_sas_send_ata_reset_each_phy(struct hisi_hba *hisi_hba,
 
 	state = hisi_hba->hw->get_phys_state(hisi_hba);
 	for (i = 0; i < hisi_hba->n_phy; i++) {
-		if (!(state & BIT(sas_phy->id)))
+		if (!(state & BIT(i)))
 			continue;
 		if (!(sas_port->phy_mask & BIT(i)))
 			continue;
-- 
2.34.1

' | git ams; or return

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
        podcmd ../pi-scripts/build.fish $arch; or return
    end

    if test "$skip_mainline" != true
        if not git pll --no-edit mainline master
            rg "<<<<<<< HEAD"; and return
            for arch in arm arm64
                podcmd ../pi-scripts/build.fish $arch; or return
            end
            git aa
            git c --no-edit; or return
        end

        for arch in arm arm64
            podcmd ../pi-scripts/build.fish $arch; or return
        end
    end

    popd
end

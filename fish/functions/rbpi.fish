#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function rbpi -d "Rebase Raspberry Pi kernel on latest linux-next"
    set pi_src $CBL_BLD/rpi

    set fish_trace 1

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    set -a patches 20210628124257.140453-2-maxime@cerno.tech # [PATCH v5 01/10] drm/vc4: hdmi: Remove the DDC probing for status detection
    set -a patches 20210715164018.62712-1-colin.king@canonical.com # [PATCH][next] smpboot: remove inline from __always_inline'd function idle_init
    for patch in $patches
        git b4 ams -P _ $patch; or return
    end

    git fp -1 --stdout d936eb23874433caa3e3d841cfa16f5434b85dcf | git ams; or return # Revert "Makefile: Enable -Wimplicit-fallthrough for Clang"

    echo 'From a15dde63a894a2159b0ab7dec98edbfaabb7750a Mon Sep 17 00:00:00 2001
From: Maxime Ripard <maxime@cerno.tech>
Date: Mon, 28 Jun 2021 14:42:49 +0200
Subject: [PATCH] drm/vc4: hdmi: Fix HPD GPIO detection

Prior to commit 6800234ceee0 ("drm/vc4: hdmi: Convert to gpiod"), in the
detect hook, if we had an HPD GPIO we would only rely on it and return
whatever state it was in.

However, that commit changed that by mistake to only consider the case
where we have a GPIO and it returns a logical high, and would fall back
to the other methods otherwise.

Since we can read the EDIDs when the HPD signal is low on some displays,
we changed the detection status from disconnected to connected, and we
would ignore an HPD pulse.

Fixes: 6800234ceee0 ("drm/vc4: hdmi: Convert to gpiod")
Signed-off-by: Maxime Ripard <maxime@cerno.tech>
Link: https://lore.kernel.org/r/20210628124257.140453-3-maxime@cerno.tech
Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 drivers/gpu/drm/vc4/vc4_hdmi.c | 6 +++---
 1 file changed, 3 insertions(+), 3 deletions(-)

diff --git a/drivers/gpu/drm/vc4/vc4_hdmi.c b/drivers/gpu/drm/vc4/vc4_hdmi.c
index 5c576a0d0d46..00df4834cf76 100644
--- a/drivers/gpu/drm/vc4/vc4_hdmi.c
+++ b/drivers/gpu/drm/vc4/vc4_hdmi.c
@@ -168,9 +168,9 @@ vc4_hdmi_connector_detect(struct drm_connector *connector, bool force)
 
 	WARN_ON(pm_runtime_resume_and_get(&vc4_hdmi->pdev->dev));
 
-	if (vc4_hdmi->hpd_gpio &&
-	    gpiod_get_value_cansleep(vc4_hdmi->hpd_gpio)) {
-		connected = true;
+	if (vc4_hdmi->hpd_gpio) {
+		if (gpiod_get_value_cansleep(vc4_hdmi->hpd_gpio))
+			connected = true;
 	} else if (HDMI_READ(HDMI_HOTPLUG) & VC4_HDMI_HOTPLUG_CONNECTED) {
 		connected = true;
 	}
-- 
2.32.0.93.g670b81a890

' | git ams; or return

    echo 'From 26af5261cf08f10513e72439a82b3eafa7e44732 Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Wed, 9 Jun 2021 10:44:20 -0700
Subject: [PATCH] ARM: dts: bcm2711: Disable the display pipeline

Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 arch/arm/boot/dts/bcm2711-rpi-4-b.dts | 16 ++++++++--------
 1 file changed, 8 insertions(+), 8 deletions(-)

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
-- 
2.32.0

' | git ams; or return

    for arch in arm arm64
        ../pi-scripts/build.fish $arch; or return
    end

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

    popd
end

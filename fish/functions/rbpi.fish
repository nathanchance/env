#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function rbpi -d "Rebase Raspberry Pi kernel on latest linux-next"
    set pi_src $CBL_BLD/rpi

    set fish_trace 1

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    set -a patches 20210514213032.575161-1-arnd@kernel.org # [PATCH] drm/msm/dsi: fix 32-bit clang warning
    set -a patches 20210618000358.2402567-1-nathan@kernel.org # [PATCH net-next] net/mlx5: Use cpumask_available() in mlx5_eq_create_generic()
    for patch in $patches
        git b4 ams $patch; or return
    end

    echo 'From e59cc1c7bd40b7d5ca8d0a520f1c144b450544c0 Mon Sep 17 00:00:00 2001
From: Mark Rutland <mark.rutland@arm.com>
Date: Fri, 18 Jun 2021 16:11:22 +0100
Subject: [PATCH] arm64: insn: avoid circular include dependency

Nathan reports that when building with CONFIG_LTO_CLANG_THIN=y, the
build fails due to BUILD_BUG_ON() not being defined before its uss in
<asm/insn.h>.

The problem is that with LTO, we patch READ_ONCE(), and <asm/rwonce.h>
includes <asm/insn.h>, creating a circular include chain:

        <linux/build_bug.h>
        <linux/compiler.h>
        <asm/rwonce.h>
        <asm/alternative-macros.h>
        <asm/insn.h>
        <linux/build-bug.h>

... and so when <asm/insn.h> includes <linux/build_bug.h>, none of the
BUILD_BUG* definitions have happened yet.

To avoid this, let\'s move AARCH64_INSN_SIZE into a header without any
dependencies, such that it can always be safely included. At the same
time, avoid including <asm/alternative.h> in <asm/insn.h>, which should
no longer be necessary (and doesn\'t make sense when insn.h is consumed
by userspace).

Reported-by: Nathan Chancellor <nathan@kernel.org>
Signed-off-by: Mark Rutland <mark.rutland@arm.com>
Tested-by: Nathan Chancellor <nathan@kernel.org>
Cc: Catalin Marinas <catalin.marinas@arm.com>
Cc: Will Deacon <will@kernel.org>
Link: https://lore.kernel.org/r/20210618151835.GC8318@C02TD0UTHF1T.local/
Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 arch/arm64/include/asm/alternative-macros.h | 2 +-
 arch/arm64/include/asm/insn-def.h           | 8 ++++++++
 arch/arm64/include/asm/insn.h               | 5 +----
 3 files changed, 10 insertions(+), 5 deletions(-)
 create mode 100644 arch/arm64/include/asm/insn-def.h

diff --git a/arch/arm64/include/asm/alternative-macros.h b/arch/arm64/include/asm/alternative-macros.h
index d1c7139fead6..7e157ab6cd50 100644
--- a/arch/arm64/include/asm/alternative-macros.h
+++ b/arch/arm64/include/asm/alternative-macros.h
@@ -3,7 +3,7 @@
 #define __ASM_ALTERNATIVE_MACROS_H
 
 #include <asm/cpucaps.h>
-#include <asm/insn.h>
+#include <asm/insn-def.h>
 
 #define ARM64_CB_PATCH ARM64_NCAPS
 
diff --git a/arch/arm64/include/asm/insn-def.h b/arch/arm64/include/asm/insn-def.h
new file mode 100644
index 000000000000..64c6f5ac7ff5
--- /dev/null
+++ b/arch/arm64/include/asm/insn-def.h
@@ -0,0 +1,8 @@
+/* SPDX-License-Identifier: GPL-2.0-only */
+#ifndef __ASM_INSN_DEF_H
+#define __ASM_INSN_DEF_H
+
+/* A64 instructions are always 32 bits. */
+#define	AARCH64_INSN_SIZE		4
+
+#endif  /* __ASM_INSN_DEF_H */
diff --git a/arch/arm64/include/asm/insn.h b/arch/arm64/include/asm/insn.h
index 1430b4973039..6b776c8667b2 100644
--- a/arch/arm64/include/asm/insn.h
+++ b/arch/arm64/include/asm/insn.h
@@ -10,10 +10,7 @@
 #include <linux/build_bug.h>
 #include <linux/types.h>
 
-#include <asm/alternative.h>
-
-/* A64 instructions are always 32 bits. */
-#define	AARCH64_INSN_SIZE		4
+#include <asm/insn-def.h>
 
 #ifndef __ASSEMBLY__
 /*
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

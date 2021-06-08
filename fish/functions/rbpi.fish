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
    set -a patches 20210603174311.1008645-1-nathan@kernel.org # [PATCH] btrfs: Remove total_data_size variable in btrfs_batch_insert_items()
    set -a patches 20210607041529.392451-1-david@fromorbit.com # [PATCH] xfs: drop the AGI being passed to xfs_check_agi_freecount
    for patch in $patches
        git b4 ams $patch; or return
    end

    echo 'From 7b81a2b3cd00ea55f9ace4da51fcf56d5b3ffc4b Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Tue, 8 Jun 2021 10:55:28 -0700
Subject: [PATCH] scsi: ufs: Fix uninitialized use of lrbp

Link: https://lore.kernel.org/r/YL+umjDMd4Rao%2FNs@Ryzen-9-3900X/
Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 drivers/scsi/ufs/ufshcd.c | 3 +--
 1 file changed, 1 insertion(+), 2 deletions(-)

diff --git a/drivers/scsi/ufs/ufshcd.c b/drivers/scsi/ufs/ufshcd.c
index f066ffa8914b..66ea7de8c88b 100644
--- a/drivers/scsi/ufs/ufshcd.c
+++ b/drivers/scsi/ufs/ufshcd.c
@@ -2975,7 +2975,7 @@ static int ufshcd_exec_dev_cmd(struct ufs_hba *hba,
 
 	if (unlikely(test_bit(tag, &hba->outstanding_reqs))) {
 		err = -EBUSY;
-		goto out;
+		goto out_put_tag;
 	}
 
 	init_completion(&wait);
@@ -2993,7 +2993,6 @@ static int ufshcd_exec_dev_cmd(struct ufs_hba *hba,
 
 	ufshcd_send_command(hba, tag);
 	err = ufshcd_wait_for_dev_cmd(hba, lrbp, timeout);
-out:
 	ufshcd_add_query_upiu_trace(hba, err ? UFS_QUERY_ERR : UFS_QUERY_COMP,
 				    (struct utp_upiu_req *)lrbp->ucd_rsp_ptr);
 
-- 
2.32.0.rc3

' | git ams; or return

    for hash in 358afb8b746d4a7ebaeeeaab7a1523895a8572c2 4564363351e2680e55edc23c7953aebd2acb4ab7
        git fp -1 --stdout $hash arch/arm/boot/dts/bcm2711-rpi-4-b.dts | git ap -R; or return
    end
    git ac -m "ARM: dts: bcm2711: Disable the display pipeline"

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

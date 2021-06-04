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
    set -a patches 20210603173410.310362-1-nathan@kernel.org # [PATCH net-next] net: ethernet: rmnet: Restructure if checks to avoid uninitialized warning
    set -a patches 20210603174311.1008645-1-nathan@kernel.org # [PATCH] btrfs: Remove total_data_size variable in btrfs_batch_insert_items()
    for patch in $patches
        git b4 ams $patch; or return
    end

    echo 'From 63e60e529ad7ae8f27f2e85d4804bd58695c2927 Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <nathan@kernel.org>
Date: Thu, 3 Jun 2021 13:25:06 -0700
Subject: [PATCH] dm: Fix uninitialized use of bio

Fixes: 2c243153d1d4 ("dm: Forbid requeue of writes to zones")
Link: https://lore.kernel.org/r/DM6PR04MB70816EEC41ADCB7C4B18F9B5E73C9@DM6PR04MB7081.namprd04.prod.outlook.com/
Signed-off-by: Nathan Chancellor <nathan@kernel.org>
---
 drivers/md/dm.c | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)

diff --git a/drivers/md/dm.c b/drivers/md/dm.c
index 9d71dc6fe000..9903214bc8d6 100644
--- a/drivers/md/dm.c
+++ b/drivers/md/dm.c
@@ -841,6 +841,7 @@ static void dec_pending(struct dm_io *io, blk_status_t error)
 	}
 
 	if (atomic_dec_and_test(&io->io_count)) {
+		bio = io->orig_bio;
 		if (io->status == BLK_STS_DM_REQUEUE) {
 			/*
 			 * Target requested pushing back the I/O.
@@ -849,7 +850,7 @@ static void dec_pending(struct dm_io *io, blk_status_t error)
 			if (__noflush_suspending(md) &&
 			    !WARN_ON_ONCE(dm_is_zone_write(md, bio)))
 				/* NOTE early return due to BLK_STS_DM_REQUEUE below */
-				bio_list_add_head(&md->deferred, io->orig_bio);
+				bio_list_add_head(&md->deferred, bio);
 			else
 				/*
 				 * noflush suspend was interrupted or this is
@@ -860,7 +861,6 @@ static void dec_pending(struct dm_io *io, blk_status_t error)
 		}
 
 		io_error = io->status;
-		bio = io->orig_bio;
 		end_io_acct(io);
 		free_io(md, io);
 
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

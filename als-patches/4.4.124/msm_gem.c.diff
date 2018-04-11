From cab687a5e912729e418a4e0173d1e3f151b0e407 Mon Sep 17 00:00:00 2001
From: Prakash Kamliya <pkamliya@codeaurora.org>
Date: Mon, 4 Dec 2017 19:10:15 +0530
Subject: [PATCH] drm/msm: fix leak in failed get_pages

[ Upstream commit 62e3a3e342af3c313ab38603811ecdb1fcc79edb ]

get_pages doesn't keep a reference of the pages allocated
when it fails later in the code path. This can lead to
a memory leak. Keep reference of the allocated pages so
that it can be freed when msm_gem_free_object gets called
later during cleanup.

Signed-off-by: Prakash Kamliya <pkamliya@codeaurora.org>
Signed-off-by: Sharat Masetty <smasetty@codeaurora.org>
Signed-off-by: Rob Clark <robdclark@gmail.com>
Signed-off-by: Sasha Levin <alexander.levin@microsoft.com>
Signed-off-by: Greg Kroah-Hartman <gregkh@linuxfoundation.org>
Signed-off-by: Nathan Chancellor <natechancellor@gmail.com>
---
 drivers/gpu/drm/msm/msm_gem.c | 13 +++++++++----
 1 file changed, 9 insertions(+), 4 deletions(-)

diff --git a/drivers/gpu/drm/msm/msm_gem.c b/drivers/gpu/drm/msm/msm_gem.c
index d1455fbc980e..d49c67e44587 100644
--- a/drivers/gpu/drm/msm/msm_gem.c
+++ b/drivers/gpu/drm/msm/msm_gem.c
@@ -94,14 +94,17 @@ static struct page **get_pages(struct drm_gem_object *obj)
 			return p;
 		}
 
+		msm_obj->pages = p;
+
 		msm_obj->sgt = drm_prime_pages_to_sg(p, npages);
 		if (IS_ERR(msm_obj->sgt)) {
+			void *ptr = ERR_CAST(msm_obj->sgt);
+
 			dev_err(dev->dev, "failed to allocate sgt\n");
-			return ERR_CAST(msm_obj->sgt);
+			msm_obj->sgt = NULL;
+			return ptr;
 		}
 
-		msm_obj->pages = p;
-
 		/*
 		 * Make sure to flush the CPU cache for newly allocated memory
 		 * so we don't get ourselves into trouble with a dirty cache
@@ -119,7 +122,9 @@ static void put_pages(struct drm_gem_object *obj)
 	struct msm_gem_object *msm_obj = to_msm_bo(obj);
 
 	if (msm_obj->pages) {
-		sg_free_table(msm_obj->sgt);
+		if (msm_obj->sgt)
+			sg_free_table(msm_obj->sgt);
+
 		kfree(msm_obj->sgt);
 
 		if (use_pages(obj))
-- 
2.16.2


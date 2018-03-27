From 3eed9222abd0fce16ec185fba476181d36dbafbc Mon Sep 17 00:00:00 2001
From: Nathan Chancellor <natechancellor@gmail.com>
Date: Thu, 15 Feb 2018 17:39:24 -0700
Subject: [PATCH] media: v4l2-compat-ioctl32: Reapply
 be489cec86ea28e968993718b6f2a5e04733e79d

This has been updated for the 4.4.116 changes to this entire file.

Signed-off-by: Nathan Chancellor <natechancellor@gmail.com>
---
 drivers/media/v4l2-core/v4l2-compat-ioctl32.c | 17 ++++++++++++++---
 1 file changed, 14 insertions(+), 3 deletions(-)

diff --git a/drivers/media/v4l2-core/v4l2-compat-ioctl32.c b/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
index 943f90e392a7..fa0026027d93 100644
--- a/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
+++ b/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
@@ -391,7 +391,11 @@ static int get_v4l2_plane32(struct v4l2_plane __user *up,
 
 	if (copy_in_user(up, up32, 2 * sizeof(__u32)) ||
 	    copy_in_user(&up->data_offset, &up32->data_offset,
-			 sizeof(up->data_offset)))
+			 sizeof(up->data_offset)) ||
+	    copy_in_user(up->reserved, up32->reserved,
+			 sizeof(up->reserved)) ||
+	    copy_in_user(&up->length, &up32->length,
+			 sizeof(up->length)))
 		return -EFAULT;
 
 	switch (memory) {
@@ -422,6 +426,8 @@ static int put_v4l2_plane32(struct v4l2_plane __user *up,
 	unsigned long p;
 
 	if (copy_in_user(up32, up, 2 * sizeof(__u32)) ||
+	    copy_in_user(up32->reserved, up->reserved,
+			 sizeof(up->reserved)) ||
 	    copy_in_user(&up32->data_offset, &up->data_offset,
 			 sizeof(up->data_offset)))
 		return -EFAULT;
@@ -901,8 +907,13 @@ static int put_v4l2_ext_controls32(struct file *file,
 struct v4l2_event32 {
 	__u32				type;
 	union {
-		compat_s64		value64;
-		__u8			data[64];
+		struct v4l2_event_vsync		vsync;
+		struct v4l2_event_ctrl		ctrl;
+		struct v4l2_event_frame_sync	frame_sync;
+		struct v4l2_event_src_change	src_change;
+		struct v4l2_event_motion_det	motion_det;
+		 compat_s64                     value64;
+		__u8			        data[64];
 	} u;
 	__u32				pending;
 	__u32				sequence;

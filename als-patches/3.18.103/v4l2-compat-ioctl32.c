diff --git a/drivers/media/v4l2-core/v4l2-compat-ioctl32.c b/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
index ca0a43ad4ec8..2b0b820fb573 100644
--- a/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
+++ b/drivers/media/v4l2-core/v4l2-compat-ioctl32.c
@@ -383,7 +383,11 @@ static int get_v4l2_plane32(struct v4l2_plane __user *up,
 
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
@@ -414,6 +418,8 @@ static int put_v4l2_plane32(struct v4l2_plane __user *up,
 	unsigned long p;
 
 	if (copy_in_user(up32, up, 2 * sizeof(__u32)) ||
+	    copy_in_user(up32->reserved, up->reserved,
+			 sizeof(up->reserved)) ||
 	    copy_in_user(&up32->data_offset, &up->data_offset,
 			 sizeof(up->data_offset)))
 		return -EFAULT;
@@ -893,6 +899,9 @@ static int put_v4l2_ext_controls32(struct file *file,
 struct v4l2_event32 {
 	__u32				type;
 	union {
+		struct v4l2_event_vsync		vsync;
+		struct v4l2_event_ctrl		ctrl;
+		struct v4l2_event_frame_sync	frame_sync;
 		__u8			data[64];
 	} u;
 	__u32				pending;

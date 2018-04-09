diff --git a/include/linux/usb/gadget.h b/include/linux/usb/gadget.h
index cf8db11d31b9..5a59c3875d84 100644
--- a/include/linux/usb/gadget.h
+++ b/include/linux/usb/gadget.h
@@ -700,9 +700,21 @@ static inline struct usb_gadget *dev_to_usb_gadget(struct device *dev)
 	list_for_each_entry(tmp, &(gadget)->ep_list, ep_list)
 
 
+/**
+ * usb_ep_align - returns @len aligned to ep's maxpacketsize.
+ * @ep: the endpoint whose maxpacketsize is used to align @len
+ * @len: buffer size's length to align to @ep's maxpacketsize
+ *
+ * This helper is used to align buffer's size to an ep's maxpacketsize.
+ */
+static inline size_t usb_ep_align(struct usb_ep *ep, size_t len)
+{
+	return round_up(len, (size_t)le16_to_cpu(ep->desc->wMaxPacketSize));
+}
+
 /**
  * usb_ep_align_maybe - returns @len aligned to ep's maxpacketsize if gadget
- *	requires quirk_ep_out_aligned_size, otherwise reguens len.
+ *	requires quirk_ep_out_aligned_size, otherwise returns len.
  * @g: controller to check for quirk
  * @ep: the endpoint whose maxpacketsize is used to align @len
  * @len: buffer size's length to align to @ep's maxpacketsize
@@ -713,9 +725,7 @@ static inline struct usb_gadget *dev_to_usb_gadget(struct device *dev)
 static inline size_t
 usb_ep_align_maybe(struct usb_gadget *g, struct usb_ep *ep, size_t len)
 {
-	return !g->quirk_ep_out_aligned_size ? len :
-			max_t(size_t, 512,
-			round_up(len, (size_t)ep->desc->wMaxPacketSize));
+	return g->quirk_ep_out_aligned_size ? usb_ep_align(ep, len) : len;
 }
 
 /**

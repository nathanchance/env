diff --git a/drivers/usb/gadget/function/f_midi.c b/drivers/usb/gadget/function/f_midi.c
index 457142912857..9d9b4f87fcd9 100644
--- a/drivers/usb/gadget/function/f_midi.c
+++ b/drivers/usb/gadget/function/f_midi.c
@@ -221,12 +221,6 @@ static inline struct usb_request *midi_alloc_ep_req(struct usb_ep *ep,
 	return alloc_ep_req(ep, length, length);
 }
 
-static void midi_free_ep_req(struct usb_ep *ep, struct usb_request *req)
-{
-	kfree(req->buf);
-	usb_ep_free_request(ep, req);
-}
-
 static const uint8_t f_midi_cin_length[] = {
 	0, 0, 2, 3, 3, 1, 2, 3, 3, 3, 3, 3, 2, 2, 3, 1
 };
@@ -292,7 +286,7 @@ f_midi_complete(struct usb_ep *ep, struct usb_request *req)
 		if (ep == midi->out_ep)
 			f_midi_handle_out_data(ep, req);
 
-		midi_free_ep_req(ep, req);
+		free_ep_req(ep, req);
 		return;
 
 	case -EOVERFLOW:	/* buffer overrun on read means that
@@ -586,7 +580,7 @@ static void f_midi_transmit(struct f_midi *midi, struct usb_request *req)
 		req = midi_alloc_ep_req(ep, midi->buflen + extra_buf_alloc);
 
 	if (!req) {
-		ERROR(midi, "gmidi_transmit: midi_alloc_ep_request failed\n");
+		ERROR(midi, "gmidi_transmit: alloc_ep_request failed\n");
 		return;
 	}
 	req->length = 0;
@@ -612,7 +606,7 @@ static void f_midi_transmit(struct f_midi *midi, struct usb_request *req)
 	if (req->length > 0)
 		usb_ep_queue(ep, req, GFP_ATOMIC);
 	else
-		midi_free_ep_req(ep, req);
+		free_ep_req(ep, req);
 }

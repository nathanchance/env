diff --git a/net/ipv4/netfilter/nf_nat_h323.c b/net/ipv4/netfilter/nf_nat_h323.c
index d8fb251fa6e3..ac8342dcb55e 100644
--- a/net/ipv4/netfilter/nf_nat_h323.c
+++ b/net/ipv4/netfilter/nf_nat_h323.c
@@ -252,16 +252,16 @@ static int nat_rtp_rtcp(struct sk_buff *skb, struct nf_conn *ct,
 	if (set_h245_addr(skb, protoff, data, dataoff, taddr,
 			  &ct->tuplehash[!dir].tuple.dst.u3,
 			  htons((port & htons(1)) ? nated_port + 1 :
-						    nated_port)) == 0) {
-		/* Save ports */
-		info->rtp_port[i][dir] = rtp_port;
-		info->rtp_port[i][!dir] = htons(nated_port);
-	} else {
+						    nated_port))) {
 		nf_ct_unexpect_related(rtp_exp);
 		nf_ct_unexpect_related(rtcp_exp);
 		return -1;
 	}
 
+	/* Save ports */
+	info->rtp_port[i][dir] = rtp_port;
+	info->rtp_port[i][!dir] = htons(nated_port);
+
 	/* Success */
 	pr_debug("nf_nat_h323: expect RTP %pI4:%hu->%pI4:%hu\n",
 		 &rtp_exp->tuple.src.u3.ip,
@@ -370,15 +370,15 @@ static int nat_h245(struct sk_buff *skb, struct nf_conn *ct,
 	/* Modify signal */
 	if (set_h225_addr(skb, protoff, data, dataoff, taddr,
 			  &ct->tuplehash[!dir].tuple.dst.u3,
-			  htons(nated_port)) == 0) {
-		/* Save ports */
-		info->sig_port[dir] = port;
-		info->sig_port[!dir] = htons(nated_port);
-	} else {
+			  htons(nated_port))) {
 		nf_ct_unexpect_related(exp);
 		return -1;
 	}
 
+	/* Save ports */
+	info->sig_port[dir] = port;
+	info->sig_port[!dir] = htons(nated_port);
+
 	pr_debug("nf_nat_q931: expect H.245 %pI4:%hu->%pI4:%hu\n",
 		 &exp->tuple.src.u3.ip,
 		 ntohs(exp->tuple.src.u.tcp.port),
@@ -462,24 +462,27 @@ static int nat_q931(struct sk_buff *skb, struct nf_conn *ct,
 	/* Modify signal */
 	if (set_h225_addr(skb, protoff, data, 0, &taddr[idx],
 			  &ct->tuplehash[!dir].tuple.dst.u3,
-			  htons(nated_port)) == 0) {
-		/* Save ports */
-		info->sig_port[dir] = port;
-		info->sig_port[!dir] = htons(nated_port);
-
-		/* Fix for Gnomemeeting */
-		if (idx > 0 &&
-		    get_h225_addr(ct, *data, &taddr[0], &addr, &port) &&
-		    (ntohl(addr.ip) & 0xff000000) == 0x7f000000) {
-			set_h225_addr(skb, protoff, data, 0, &taddr[0],
-				      &ct->tuplehash[!dir].tuple.dst.u3,
-				      info->sig_port[!dir]);
-		}
-	} else {
+			  htons(nated_port))) {
 		nf_ct_unexpect_related(exp);
 		return -1;
 	}
 
+	/* Save ports */
+	info->sig_port[dir] = port;
+	info->sig_port[!dir] = htons(nated_port);
+
+	/* Fix for Gnomemeeting */
+	if (idx > 0 &&
+	    get_h225_addr(ct, *data, &taddr[0], &addr, &port) &&
+	    (ntohl(addr.ip) & 0xff000000) == 0x7f000000) {
+		if (set_h225_addr(skb, protoff, data, 0, &taddr[0],
+				  &ct->tuplehash[!dir].tuple.dst.u3,
+				  info->sig_port[!dir])) {
+			nf_ct_unexpect_related(exp);
+			return -1;
+		}
+	}
+
 	/* Success */
 	pr_debug("nf_nat_ras: expect Q.931 %pI4:%hu->%pI4:%hu\n",
 		 &exp->tuple.src.u3.ip,
@@ -552,7 +555,7 @@ static int nat_callforwarding(struct sk_buff *skb, struct nf_conn *ct,
 	/* Modify signal */
 	if (set_h225_addr(skb, protoff, data, dataoff, taddr,
 			  &ct->tuplehash[!dir].tuple.dst.u3,
-			  htons(nated_port)) != 0) {
+			  htons(nated_port))) {
 		nf_ct_unexpect_related(exp);
 		return -1;
 	}

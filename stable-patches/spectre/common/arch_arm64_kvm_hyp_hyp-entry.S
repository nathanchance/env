diff --git a/arch/arm64/kvm/hyp/hyp-entry.S b/arch/arm64/kvm/hyp/hyp-entry.S
index 44c79fd81ad1..d7ed9a0f5605 100644
--- a/arch/arm64/kvm/hyp/hyp-entry.S
+++ b/arch/arm64/kvm/hyp/hyp-entry.S
@@ -15,6 +15,7 @@
  * along with this program.  If not, see <http://www.gnu.org/licenses/>.
  */
 
+#include <linux/arm-smccc.h>
 #include <linux/linkage.h>
 
 #include <asm/alternative.h>
@@ -71,10 +72,11 @@ el1_sync:				// Guest trapped into EL2
 	lsr	x2, x1, #ESR_ELx_EC_SHIFT
 
 	cmp	x2, #ESR_ELx_EC_HVC64
+	ccmp	x2, #ESR_ELx_EC_HVC32, #4, ne
 	b.ne	el1_trap
 
-	mrs	x3, vttbr_el2		// If vttbr is valid, the 64bit guest
-	cbnz	x3, el1_trap		// called HVC
+	mrs	x3, vttbr_el2		// If vttbr is valid, the guest
+	cbnz	x3, el1_hvc_guest	// called HVC
 
 	/* Here, we're pretty sure the host called HVC. */
 	restore_x0_to_x3
@@ -93,6 +95,20 @@ el1_sync:				// Guest trapped into EL2
 
 2:	eret
 
+el1_hvc_guest:
+	/*
+	 * Fastest possible path for ARM_SMCCC_ARCH_WORKAROUND_1.
+	 * The workaround has already been applied on the host,
+	 * so let's quickly get back to the guest. We don't bother
+	 * restoring x1, as it can be clobbered anyway.
+	 */
+	ldr	x3, [sp]				// Guest's x0
+	eor	w3, w3, #ARM_SMCCC_ARCH_WORKAROUND_1
+	cbnz	w3, el1_trap
+	mov	x0, x3
+	add	sp, sp, #16
+	eret
+
 el1_trap:
 	/*
 	 * x1: ESR

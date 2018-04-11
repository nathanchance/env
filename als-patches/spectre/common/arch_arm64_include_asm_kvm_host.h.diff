diff --git a/arch/arm64/include/asm/kvm_host.h b/arch/arm64/include/asm/kvm_host.h
index 3be7a7b52d80..7ee72f6d5d22 100644
--- a/arch/arm64/include/asm/kvm_host.h
+++ b/arch/arm64/include/asm/kvm_host.h
@@ -354,4 +354,9 @@ void kvm_arm_reset_debug_ptr(struct kvm_vcpu *vcpu);
 
 #define kvm_call_hyp(f, ...) __kvm_call_hyp(kvm_ksym_ref(f), ##__VA_ARGS__)
 
+static inline bool kvm_arm_harden_branch_predictor(void)
+{
+	return cpus_have_cap(ARM64_HARDEN_BRANCH_PREDICTOR);
+}
+
 #endif /* __ARM64_KVM_HOST_H__ */

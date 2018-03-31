diff --git a/arch/arm/include/asm/kvm_mmu.h b/arch/arm/include/asm/kvm_mmu.h
index ebf866a3a8c8..e8056d9b60a8 100644
--- a/arch/arm/include/asm/kvm_mmu.h
+++ b/arch/arm/include/asm/kvm_mmu.h
@@ -278,6 +278,16 @@ static inline unsigned int kvm_get_vmid_bits(void)
 	return 8;
 }
 
+static inline void *kvm_get_hyp_vector(void)
+{
+	return __kvm_hyp_vector;
+}
+
+static inline int kvm_map_vectors(void)
+{
+	return 0;
+}
+
 #endif	/* !__ASSEMBLY__ */
 
 #endif /* __ARM_KVM_MMU_H__ */

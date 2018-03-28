diff --git a/arch/arm64/mm/mmu.c b/arch/arm64/mm/mmu.c
index 049ca3916fd0..1369b6079fbc 100644
--- a/arch/arm64/mm/mmu.c
+++ b/arch/arm64/mm/mmu.c
@@ -929,3 +929,15 @@ int pmd_clear_huge(pmd_t *pmd)
 	pmd_clear(pmd);
 	return 1;
 }
+
+#ifdef CONFIG_HAVE_ARCH_HUGE_VMAP
+int pud_free_pmd_page(pud_t *pud)
+{
+	return pud_none(*pud);
+}
+
+int pmd_free_pte_page(pmd_t *pmd)
+{
+	return pmd_none(*pmd);
+}
+#endif

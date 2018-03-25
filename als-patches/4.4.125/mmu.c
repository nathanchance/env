diff --git a/arch/arm64/mm/mmu.c b/arch/arm64/mm/mmu.c
index 6c444d968323..fb1da07803d2 100644
--- a/arch/arm64/mm/mmu.c
+++ b/arch/arm64/mm/mmu.c
@@ -884,3 +884,13 @@ int pmd_clear_huge(pmd_t *pmd)
 	pmd_clear(pmd);
 	return 1;
 }
+
+int pud_free_pmd_page(pud_t *pud)
+{
+	return pud_none(*pud);
+}
+
+int pmd_free_pte_page(pmd_t *pmd)
+{
+	return pmd_none(*pmd);
+}

diff --git a/arch/arm64/include/asm/memory.h b/arch/arm64/include/asm/memory.h
index ae11e8fdbfd2..074abff24231 100644
--- a/arch/arm64/include/asm/memory.h
+++ b/arch/arm64/include/asm/memory.h
@@ -48,8 +48,10 @@
  * TASK_UNMAPPED_BASE - the lower boundary of the mmap VM area.
  */
 #define VA_BITS			(CONFIG_ARM64_VA_BITS)
-#define VA_START		(UL(0xffffffffffffffff) << VA_BITS)
-#define PAGE_OFFSET		(UL(0xffffffffffffffff) << (VA_BITS - 1))
+#define VA_START		(UL(0xffffffffffffffff) - \
+	(UL(1) << VA_BITS) + 1)
+#define PAGE_OFFSET		(UL(0xffffffffffffffff) - \
+	(UL(1) << (VA_BITS - 1)) + 1)
 #define KIMAGE_VADDR		(MODULES_END)
 #define MODULES_END		(MODULES_VADDR + MODULES_VSIZE)
 #define MODULES_VADDR		(VA_START + KASAN_SHADOW_SIZE)

diff --git a/include/linux/jiffies.h b/include/linux/jiffies.h
index 11ff414b4139..2fb10601febe 100644
--- a/include/linux/jiffies.h
+++ b/include/linux/jiffies.h
@@ -64,13 +64,17 @@ extern int register_refined_jiffies(long clock_tick_rate);
 /* TICK_USEC is the time between ticks in usec assuming fake USER_HZ */
 #define TICK_USEC ((1000000UL + USER_HZ/2) / USER_HZ)
 
+#ifndef __jiffy_arch_data
+#define __jiffy_arch_data
+#endif
+
 /*
  * The 64-bit value is not atomic - you MUST NOT read it
  * without sampling the sequence number in jiffies_lock.
  * get_jiffies_64() will do this for you as appropriate.
  */
 extern u64 __cacheline_aligned_in_smp jiffies_64;
-extern unsigned long volatile __cacheline_aligned_in_smp jiffies;
+extern unsigned long volatile __cacheline_aligned_in_smp __jiffy_arch_data jiffies;
 
 #if (BITS_PER_LONG < 64)
 u64 get_jiffies_64(void);

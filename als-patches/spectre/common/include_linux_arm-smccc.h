diff --git a/include/linux/arm-smccc.h b/include/linux/arm-smccc.h
index 0989e6b5c64c..65c9020eb76c 100644
--- a/include/linux/arm-smccc.h
+++ b/include/linux/arm-smccc.h
@@ -14,8 +14,7 @@
 #ifndef __LINUX_ARM_SMCCC_H
 #define __LINUX_ARM_SMCCC_H
 
-#include <linux/linkage.h>
-#include <linux/types.h>
+#include <uapi/linux/const.h>
 
 /*
  * This file provides common defines for ARM SMC Calling Convention as
@@ -23,8 +22,8 @@
  * http://infocenter.arm.com/help/topic/com.arm.doc.den0028a/index.html
  */
 
-#define ARM_SMCCC_STD_CALL		0
-#define ARM_SMCCC_FAST_CALL		1
+#define ARM_SMCCC_STD_CALL	        _AC(0,U)
+#define ARM_SMCCC_FAST_CALL	        _AC(1,U)
 #define ARM_SMCCC_TYPE_SHIFT		31
 
 #define ARM_SMCCC_SMC_32		0
@@ -60,6 +59,30 @@
 #define ARM_SMCCC_OWNER_TRUSTED_OS	50
 #define ARM_SMCCC_OWNER_TRUSTED_OS_END	63
 
+#define ARM_SMCCC_QUIRK_NONE		0
+#define ARM_SMCCC_QUIRK_QCOM_A6		1 /* Save/restore register a6 */
+
+#define ARM_SMCCC_VERSION_1_0		0x10000
+#define ARM_SMCCC_VERSION_1_1		0x10001
+
+#define ARM_SMCCC_VERSION_FUNC_ID					\
+	ARM_SMCCC_CALL_VAL(ARM_SMCCC_FAST_CALL,				\
+			   ARM_SMCCC_SMC_32,				\
+			   0, 0)
+
+#define ARM_SMCCC_ARCH_FEATURES_FUNC_ID					\
+	ARM_SMCCC_CALL_VAL(ARM_SMCCC_FAST_CALL,				\
+			   ARM_SMCCC_SMC_32,				\
+			   0, 1)
+
+#define ARM_SMCCC_ARCH_WORKAROUND_1					\
+	ARM_SMCCC_CALL_VAL(ARM_SMCCC_FAST_CALL,				\
+			   ARM_SMCCC_SMC_32,				\
+			   0, 0x8000)
+
+#ifndef __ASSEMBLY__
+#include <linux/linkage.h>
+#include <linux/types.h>
 /**
  * struct arm_smccc_res - Result from SMC/HVC call
  * @a0-a3 result values from registers 0 to 3
@@ -101,7 +124,6 @@ asmlinkage void arm_smccc_hvc(unsigned long a0, unsigned long a1,
 			unsigned long a5, unsigned long a6, unsigned long a7,
 			struct arm_smccc_res *res);
 
-
 static inline unsigned long __invoke_psci_fn_hvc(unsigned long function_id,
 			unsigned long arg0, unsigned long arg1,
 			unsigned long arg2)
@@ -122,4 +144,146 @@ static inline unsigned long __invoke_psci_fn_smc(unsigned long function_id,
 	return res.a0;
 }
 
+/* SMCCC v1.1 implementation madness follows */
+#ifdef CONFIG_ARM64
+
+#define SMCCC_SMC_INST	"smc	#0"
+#define SMCCC_HVC_INST	"hvc	#0"
+
+#elif defined(CONFIG_ARM)
+#include <asm/opcodes-sec.h>
+#include <asm/opcodes-virt.h>
+
+#define SMCCC_SMC_INST	__SMC(0)
+#define SMCCC_HVC_INST	__HVC(0)
+
+#endif
+
+#define ___count_args(_0, _1, _2, _3, _4, _5, _6, _7, _8, x, ...) x
+
+#define __count_args(...)						\
+	___count_args(__VA_ARGS__, 7, 6, 5, 4, 3, 2, 1, 0)
+
+#define __constraint_write_0						\
+	"+r" (r0), "=&r" (r1), "=&r" (r2), "=&r" (r3)
+#define __constraint_write_1						\
+	"+r" (r0), "+r" (r1), "=&r" (r2), "=&r" (r3)
+#define __constraint_write_2						\
+	"+r" (r0), "+r" (r1), "+r" (r2), "=&r" (r3)
+#define __constraint_write_3						\
+	"+r" (r0), "+r" (r1), "+r" (r2), "+r" (r3)
+#define __constraint_write_4	__constraint_write_3
+#define __constraint_write_5	__constraint_write_4
+#define __constraint_write_6	__constraint_write_5
+#define __constraint_write_7	__constraint_write_6
+
+#define __constraint_read_0
+#define __constraint_read_1
+#define __constraint_read_2
+#define __constraint_read_3
+#define __constraint_read_4	"r" (r4)
+#define __constraint_read_5	__constraint_read_4, "r" (r5)
+#define __constraint_read_6	__constraint_read_5, "r" (r6)
+#define __constraint_read_7	__constraint_read_6, "r" (r7)
+
+#define __declare_arg_0(a0, res)					\
+	struct arm_smccc_res   *___res = res;				\
+	register u32           r0 asm("r0") = a0;			\
+	register unsigned long r1 asm("r1");				\
+	register unsigned long r2 asm("r2");				\
+	register unsigned long r3 asm("r3")
+
+#define __declare_arg_1(a0, a1, res)					\
+	struct arm_smccc_res   *___res = res;				\
+	register u32           r0 asm("r0") = a0;			\
+	register typeof(a1)    r1 asm("r1") = a1;			\
+	register unsigned long r2 asm("r2");				\
+	register unsigned long r3 asm("r3")
+
+#define __declare_arg_2(a0, a1, a2, res)				\
+	struct arm_smccc_res   *___res = res;				\
+	register u32           r0 asm("r0") = a0;			\
+	register typeof(a1)    r1 asm("r1") = a1;			\
+	register typeof(a2)    r2 asm("r2") = a2;			\
+	register unsigned long r3 asm("r3")
+
+#define __declare_arg_3(a0, a1, a2, a3, res)				\
+	struct arm_smccc_res   *___res = res;				\
+	register u32           r0 asm("r0") = a0;			\
+	register typeof(a1)    r1 asm("r1") = a1;			\
+	register typeof(a2)    r2 asm("r2") = a2;			\
+	register typeof(a3)    r3 asm("r3") = a3
+
+#define __declare_arg_4(a0, a1, a2, a3, a4, res)			\
+	__declare_arg_3(a0, a1, a2, a3, res);				\
+	register typeof(a4) r4 asm("r4") = a4
+
+#define __declare_arg_5(a0, a1, a2, a3, a4, a5, res)			\
+	__declare_arg_4(a0, a1, a2, a3, a4, res);			\
+	register typeof(a5) r5 asm("r5") = a5
+
+#define __declare_arg_6(a0, a1, a2, a3, a4, a5, a6, res)		\
+	__declare_arg_5(a0, a1, a2, a3, a4, a5, res);			\
+	register typeof(a6) r6 asm("r6") = a6
+
+#define __declare_arg_7(a0, a1, a2, a3, a4, a5, a6, a7, res)		\
+	__declare_arg_6(a0, a1, a2, a3, a4, a5, a6, res);		\
+	register typeof(a7) r7 asm("r7") = a7
+
+#define ___declare_args(count, ...) __declare_arg_ ## count(__VA_ARGS__)
+#define __declare_args(count, ...)  ___declare_args(count, __VA_ARGS__)
+
+#define ___constraints(count)						\
+	: __constraint_write_ ## count					\
+	: __constraint_read_ ## count					\
+	: "memory"
+#define __constraints(count)	___constraints(count)
+
+/*
+ * We have an output list that is not necessarily used, and GCC feels
+ * entitled to optimise the whole sequence away. "volatile" is what
+ * makes it stick.
+ */
+#define __arm_smccc_1_1(inst, ...)					\
+	do {								\
+		__declare_args(__count_args(__VA_ARGS__), __VA_ARGS__);	\
+		asm volatile(inst "\n"					\
+			     __constraints(__count_args(__VA_ARGS__)));	\
+		if (___res)						\
+			*___res = (typeof(*___res)){r0, r1, r2, r3};	\
+	} while (0)
+
+/*
+ * arm_smccc_1_1_smc() - make an SMCCC v1.1 compliant SMC call
+ *
+ * This is a variadic macro taking one to eight source arguments, and
+ * an optional return structure.
+ *
+ * @a0-a7: arguments passed in registers 0 to 7
+ * @res: result values from registers 0 to 3
+ *
+ * This macro is used to make SMC calls following SMC Calling Convention v1.1.
+ * The content of the supplied param are copied to registers 0 to 7 prior
+ * to the SMC instruction. The return values are updated with the content
+ * from register 0 to 3 on return from the SMC instruction if not NULL.
+ */
+#define arm_smccc_1_1_smc(...)	__arm_smccc_1_1(SMCCC_SMC_INST, __VA_ARGS__)
+
+/*
+ * arm_smccc_1_1_hvc() - make an SMCCC v1.1 compliant HVC call
+ *
+ * This is a variadic macro taking one to eight source arguments, and
+ * an optional return structure.
+ *
+ * @a0-a7: arguments passed in registers 0 to 7
+ * @res: result values from registers 0 to 3
+ *
+ * This macro is used to make HVC calls following SMC Calling Convention v1.1.
+ * The content of the supplied param are copied to registers 0 to 7 prior
+ * to the HVC instruction. The return values are updated with the content
+ * from register 0 to 3 on return from the HVC instruction if not NULL.
+ */
+#define arm_smccc_1_1_hvc(...)	__arm_smccc_1_1(SMCCC_HVC_INST, __VA_ARGS__)
+
+#endif /*__ASSEMBLY__*/
 #endif /*__LINUX_ARM_SMCCC_H*/

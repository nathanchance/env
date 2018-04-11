diff --git a/arch/arm64/mm/fault.c b/arch/arm64/mm/fault.c
index 5cc29354a345..ab41fea0c522 100644
--- a/arch/arm64/mm/fault.c
+++ b/arch/arm64/mm/fault.c
@@ -609,6 +609,12 @@ asmlinkage void __exception do_mem_abort(unsigned long addr, unsigned int esr,
 	arm64_notify_die("", regs, &info, esr);
 }
 
+asmlinkage void __exception do_el0_irq_bp_hardening(void)
+{
+	/* PC has already been checked in entry.S */
+	arm64_apply_bp_hardening();
+}
+
 asmlinkage void __exception do_el0_ia_bp_hardening(unsigned long addr,
 						   unsigned int esr,
 						   struct pt_regs *regs)
@@ -625,6 +631,7 @@ asmlinkage void __exception do_el0_ia_bp_hardening(unsigned long addr,
 	do_mem_abort(addr, esr, regs);
 }
 
+
 /*
  * Handle stack alignment exceptions.
  */
@@ -635,6 +642,12 @@ asmlinkage void __exception do_sp_pc_abort(unsigned long addr,
 	struct siginfo info;
 	struct task_struct *tsk = current;
 
+	if (user_mode(regs)) {
+		if (instruction_pointer(regs) > TASK_SIZE)
+			arm64_apply_bp_hardening();
+		local_irq_enable();
+	}
+
 	if (show_unhandled_signals && unhandled_signal(tsk, SIGBUS))
 		pr_info_ratelimited("%s[%d]: %s exception: pc=%p sp=%p\n",
 				    tsk->comm, task_pid_nr(tsk),
@@ -686,6 +699,9 @@ asmlinkage int __exception do_debug_exception(unsigned long addr,
 	const struct fault_info *inf = debug_fault_info + DBG_ESR_EVT(esr);
 	struct siginfo info;
 
+	if (user_mode(regs) && instruction_pointer(regs) > TASK_SIZE)
+		arm64_apply_bp_hardening();
+
 	if (!inf->fn(addr, esr, regs))
 		return 1;
 

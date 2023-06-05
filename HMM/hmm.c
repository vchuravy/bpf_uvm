#include <uapi/linux/ptrace.h>
#include <linux/hmm.h>
#include <linux/migrate.h>

// See https://docs.kernel.org/mm/hmm.html

int bpf_hmm_range_fault(struct pt_regs *ctx, struct hmm_range *range) {
    return 0;
}

int bpf_migrate_vma_setup(struct pt_regs *ctx, struct migrate_vma *migrate) {
    return 0;
}

int bpf_migrate_vma_pages(struct pt_regs *ctx, struct migrate_vma *migrate) {
    return 0;
}

int bpf_migrate_vma_finalize(struct pt_regs *ctx, struct migrate_vma *migrate) {
    return 0;
}

// migrate_device_range
// migrate_device_pages
// migrate_device_finalize

TRACEPOINT_PROBE(exceptions, page_fault_user) {
    // args is from /sys/kernel/debug/tracing/events/exceptions/page_fault_user/format
    bpf_trace_printk("address=%lx \\n", args->address);
    return 0;
}
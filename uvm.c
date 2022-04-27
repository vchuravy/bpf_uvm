#include <uapi/linux/ptrace.h>
#include <nvidia-uvm/uvm_ioctl.h>

struct migration_t {
    u64 base;
    u64 length;
    u64 ts;
    u32 pid;
};

BPF_PERF_OUTPUT(migrations);

int uvm_api_migrate(struct pt_regs *ctx, UVM_MIGRATE_PARAMS *params, struct file *filp)
{
    struct migration_t migration = {};

    migration.base = params->base;
    migration.length = params->length;
    migration.pid = bpf_get_current_pid_tgid();
    migration.ts = bpf_ktime_get_ns();

    migrations.perf_submit(ctx, &migration, sizeof(migrations));

    return 0;
}
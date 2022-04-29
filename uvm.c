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

    migrations.perf_submit(ctx, &migration, sizeof(migration));

    return 0;
}


struct registration_t {
    s32 rmCtrlFd;
    u32 hClient;
    u32 hSmcPartRef;
};

BPF_PERF_OUTPUT(registrations);
int uvm_register_gpu(struct pt_regs *ctx, UVM_REGISTER_GPU_PARAMS *params, struct file *filp)
{
    struct registration_t r = {};
    r.rmCtrlFd = params->rmCtrlFd;
    r.hClient = params->hClient;
    r.hSmcPartRef = params->hSmcPartRef;

    registrations.perf_submit(ctx, &r, sizeof(r));
    return 0;
}
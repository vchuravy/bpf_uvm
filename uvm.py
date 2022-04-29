#!/usr/bin/python

from bcc import BPF
from bcc.utils import printb

# Adjust to your liking
nvidia_dkms = "/usr/src/nvidia-510.54"

# load BPF program
b = BPF(src_file="uvm.c", cflags=[f"-I{nvidia_dkms}/common/inc", f"-I{nvidia_dkms}"])

# b.attach_kprobe(event="uvm_api_migrate", fn_name="uvm_api_migrate")
b.attach_kprobe(event="uvm_api_register_gpu", fn_name="uvm_register_gpu")

# header
# header
print("Tracing... Hit Ctrl-C to end.")
# print("%-18s %-6s %-6s %-6s" % ("TIME(s)","PID", "BASE", "LENGTH"))

# process event
start = 0

def print_migration(cpu, data, size):
    global start
    migration = b["migrations"].event(data)
    if start == 0:
        start = migration.ts
    time_s = (float(migration.ts - start)) / 1000000000
    printb(
        b"%-18.9f %-6d %-6d %-6d"
        % (time_s, migration.pid, migration.base, migration.length)
    )

def print_registration(cpu, data, size):
    r = b["registrations"].event(data)
    printb(
        b"%d %d %d"
        % (r.rmCtrlFd, r.hClient, r.hSmcPartRef)
    )


# loop with callback to print_event
# b["migrations"].open_perf_buffer(print_migration)
b["registrations"].open_perf_buffer(print_registration)
while 1:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()

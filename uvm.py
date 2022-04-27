#!/usr/bin/python

from bcc import BPF
from bcc.utils import printb

# load BPF program
b = BPF(src_file="uvm.c", cflags=["-I/usr/src/nvidia-510.54/common/inc", "-I/usr/src/nvidia-510.54/"])

b.attach_kprobe(event="uvm_api_migrate", fn_name="uvm_api_migrate")

# header
# header
print("Tracing... Hit Ctrl-C to end.")
print("%-18s %-6s %-6s %-6s" % ("TIME(s)","PID", "BASE", "LENGTH"))

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


# loop with callback to print_event
b["migrations"].open_perf_buffer(print_migration)
while 1:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()

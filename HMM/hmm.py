#!/usr/bin/python

from bcc import BPF
from bcc.utils import printb
import ctypes as ct

# load BPF program
b = BPF(src_file="hmm.c", cflags=[])

b.attach_kprobe(event="hmm_range_fault",      fn_name="bpf_hmm_range_fault")
b.attach_kprobe(event="migrate_vma_setup",    fn_name="bpf_migrate_vma_setup")
b.attach_kprobe(event="migrate_vma_pages",    fn_name="bpf_migrate_vma_pages")
b.attach_kprobe(event="migrate_vma_finalize", fn_name="bpf_migrate_vma_finalize")

print("Tracing... Hit Ctrl-C to end.")
while 1:
    try:
        # print("poll")
        # b.perf_buffer_poll()
        try:
            (task, pid, cpu, flags, ts, msg) = b.trace_fields()
        except ValueError:
            continue
        print("%-18.9f %-16s %-6d %s" % (ts, task, pid, msg))
    except KeyboardInterrupt:
        exit()

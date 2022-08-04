#!/usr/bin/python

from bcc import BPF
from bcc.utils import printb
import ctypes as ct

# Adjust to your liking
nvidia_dkms = "/usr/src/nvidia-510.54"

# load BPF program
b = BPF(src_file="uvm.c", cflags=[f"-I{nvidia_dkms}/common/inc", f"-I{nvidia_dkms}"])

b.attach_kprobe(event="uvm_perf_event_notify", fn_name="uvm_perf_event_notify")

def transfer_mode(m):
    if m == 1:
        return "Move"
    elif m == 2:
        return "Copy"
    else:
        return "Unknown"


def cause(c):
    if c == 0:
        return "Replayable Fault"
    elif c == 1:
        return "Non Replayable Fault"
    elif c == 2:
        return "Access Counter"
    elif c == 3:
        return "Prefetch"
    elif c == 4:
        return "Eviction"
    elif c == 5:
        return "API Tools"
    elif c == 6:
        return "API Migrate"
    elif c == 7:
        return "API Set Range Group"
    elif c == 8:
        return "API Hint"
    else:
        return "Unknown"

# define output data structure in Python
class Migration(ct.Structure):
    _fields_ = [
        ("dst", ct.c_uint32),
        ("src", ct.c_uint32),
        ("address", ct.c_uint64),
        ("bytes", ct.c_uint64),
        ("transfer_mode", ct.c_int),
        ("cause", ct.c_int)]


def print_migration(cpu, data, size):
    m = ct.cast(data, ct.POINTER(Migration)).contents
    printb(
        b"Migration from proc %-6d to %-6d (va: 0x%x, %d bytes, mode: %b, cause: %b)"
        % (m.src, m.dst, m.address, m.bytes, transfer_mode(m.transfer_mode).encode(), cause(m.cause).encode())
    )

def print_gpu_fault(cpu, data, size):
    fault = b["gpu_faults"].event(data)
    if fault.is_duplicated or fault.filtered:
        printb(
            b"Duplicated GPU fault on proc %-6d (va: 0x%x)"
            % (fault.proc_id, fault.fault_va)
        )
    else:
        printb(
            b"GPU fault on proc %-6d (va: 0x%x)"
            % (fault.proc_id, fault.fault_va)
        )

def print_cpu_fault(cpu, data, size):
    fault = b["cpu_faults"].event(data)
    printb(
        b"CPU fault on proc %-6d (write: %r, va: 0x%x, pc: 0x%x)"
        % (fault.proc_id, bool(fault.is_write), fault.fault_va, fault.pc)
    )

print("Tracing... Hit Ctrl-C to end.")
# loop with callback to print_event
b["migrations"].open_perf_buffer(print_migration)
b["gpu_faults"].open_perf_buffer(print_gpu_fault)
b["cpu_faults"].open_perf_buffer(print_cpu_fault)
# b["revocations"].open_perf_buffer(print_revocations)
while 1:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()

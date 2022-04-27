# Using eBPF to study CUDA UVM

## Example 1: Observing manual prefetch

Studying `usr/src/nvidia-*/nvidia-uvm` we find the header: `uvm_ioctl.h`.

It describes the various driver calls. Using `strace` we can observer
that the ioctl coresponding to a manual prefetch is:

```
...
ioctl(22, _IOC(_IOC_NONE, 0, 0x33, 0), 0x7ffd810f0400) = 0
...
```

Note that `0x33` corresponds to:

```c
#define UVM_MIGRATE                                                   UVM_IOCTL_BASE(51)
```

Running `uvm.py` as root, and `julia --project=. test-uvm.jl` as a normal user you should observe something like.

```bash
[root@odin bpf_uvm]# ./uvm.py
Tracing... Hit Ctrl-C to end.
TIME(s)            PID    BASE   LENGTH
0.000000000        133385 139744310722560 4096  
```
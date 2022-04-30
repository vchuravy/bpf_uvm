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

## fault stats through procfs

If you restart the uvm driver with procfs fault statistics can be requested through procfs, they are
only available while a process has the `nvidia_uvm` opened and initialized.


```
sudo rmmod nvidia_uvm ; sudo modprobe nvidia_uvm uvm_enable_debug_procfs=1
```

```
vchuravy@odin /u/s/nvidia-510.54> cat /proc/driver/nvidia-uvm/gpus/UVM-GPU-d9b28d2d-828e-cae5-626b-dc354d9af00f/fault_stats
replayable_faults      446
duplicates             0
faults_by_access_type:
  prefetch             0
  read                 0
  write                446
  atomic               0
migrations:
  num_pages_in         1024 (4 MB)
  num_pages_out        1024 (4 MB)
replays:
  start                22
  start_ack_all        0
non_replayable_faults  0
faults_by_access_type:
  read                 0
  write                0
  atomic               0
faults_by_addressing:
  virtual              0
  physical             0
migrations:
  num_pages_in         0 (0 MB)
  num_pages_out        0 (0 MB)
```

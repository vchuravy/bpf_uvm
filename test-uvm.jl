# sudo rmmod nvidia_uvm ; sudo modprobe nvidia_uvm uvm_debug_prints=1
# ls /sys/module/nvidia_uvm/parameters/ for more interesting parameters

# To make debug prints visible
# sudo dmesg -n 7 

using CUDA

const PAGE_SIZE = 4096
const N = 1

buf = CuArray{UInt8, 1, CUDA.Mem.Unified}(undef, (N*PAGE_SIZE,))

# # CUDA.Mem.prefetch(buf.storage.buffer)

function fetch_page(buf)
    buf[threadIdx().x * PAGE_SIZE]
    return
end

@cuda threads=N fetch_page(buf)


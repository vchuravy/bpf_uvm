# sudo rmmod nvidia_uvm ; sudo modprobe nvidia_uvm uvm_debug_prints=1
# ls /sys/module/nvidia_uvm/parameters/ for more interesting parameters

# To make debug prints visible
# sudo dmesg -n 7 

using CUDA

const PAGE_SIZE = 4096
const N = 1024

buf = CuArray{UInt8, 1, CUDA.Mem.Unified}(undef, (N*PAGE_SIZE,))
cpu_buf = Base.unsafe_wrap(Array{UInt8}, Base.unsafe_convert(Ptr{UInt8}, buf.storage.buffer), (N*PAGE_SIZE,), own=false)

function prefetch_pages(buf)
    CUDA.Mem.prefetch(buf.storage.buffer)
end

function fetch_pages_cpu(buf)
    for i in eachindex(buf)
        buf[i] += 1
    end
end

function fetch_pages(buf)
    buf[threadIdx().x * PAGE_SIZE] += 1
    return
end

function fetch_pages_gpu(buf)
    @cuda threads=N fetch_pages(buf)
    synchronize()
end

fetch_pages_cpu(cpu_buf)
prefetch_pages(buf)
fetch_pages_cpu(cpu_buf)
fetch_pages_gpu(buf)
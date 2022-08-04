using CUDA

N = 10 * div(4096, sizeof(Float32))

A = CuArray{Float32, 1, CUDA.Mem.Unified}(undef, (N,));
B = CuArray{Float32, 1, CUDA.Mem.Unified}(undef, (N,));

cpu_B = Base.unsafe_wrap(Array{Float32}, Base.unsafe_convert(Ptr{Float32}, B.storage.buffer), (N,), own=false)
cpu_A = Base.unsafe_wrap(Array{Float32}, Base.unsafe_convert(Ptr{Float32}, A.storage.buffer), (N,), own=false)

function prefetch(buf::CuArray; stream = CUDA.stream())
    CUDA.Mem.prefetch(buf.storage.buffer; stream)
end

function copy_kernel(A, B)
    i = (blockIdx().x-Int32(1)) * blockDim().x + threadIdx().x
    if i <= length(A)
        @inbounds A[i] = B[i]
    end
    return
end

@noinline escape(val) = nothing

const PAGE_SIZE = 4096
function fetch_kernel(buf,stride)
    idx = (blockIdx().x-Int32(1)) * blockDim().x + threadIdx().x
    i = idx * stride
    if i <= length(buf)
        # TODO: Do read without compiler deleting it
        # escape(buf[i])
        buf[i] += 1
    end
    return
end

function fetch_pages(A)
    stride = div(PAGE_SIZE, sizeof(eltype(A)))
    len = div(length(A), stride)
    
    threads = 128
    blocks = max(div(len, threads), 1)

    @cuda threads=threads blocks=blocks fetch_kernel(A, stride)
    return nothing
end

function bench(A, B, cpu_B)
    prefetch(A)
    prefetch(B)
    for _ in 1:10
        CUDA.@time begin
            # A .= B
            @cuda threads=128 blocks=div(length(A), 128) copy_kernel(A, B)
            CUDA.synchronize()
            fill!(cpu_B, 0)
            prefetch(B)
        end
    end
end    


function bench_prefetch(cpu_A, A)
    fill!(cpu_A, 1)
    for _ in 1:10
        CUDA.@time prefetch(A)
    end
end

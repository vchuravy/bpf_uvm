using CUDA

buf = CUDA.alloc(CUDA.Mem.Unified, 4096)
CUDA.Mem.prefetch(buf)

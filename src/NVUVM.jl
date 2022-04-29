module NVUVM
    export UVM, UVMTools
    export initialize, api_tools_get_processor_uuid_table, register_gpu, api_pageable_mem_access
    export init_event_tracker, tools_enable_counters, tools_disable_counters 
    
    const O_RDONLY = Cint(0)
    const O_WRONLY = Cint(1)
    const O_RDWR = Cint(3)
    const O_NONBLOCK = Cint(4000)
    const O_CLOEXEC = Cint(2000000)

    function UVM(dev = "/dev/nvidia-uvm")
        fd = ccall(:open, Cint, (Cstring, Cint), dev, O_RDWR | O_CLOEXEC)
        systemerror("open", fd == -1)
        return fd
    end

    function UVMTools(dev = "/dev/nvidia-uvm-tools")
        fd = ccall(:open, Cint, (Cstring, Cint), dev, O_RDWR | O_CLOEXEC)
        systemerror("open", fd == -1)
        return fd
    end

    include("ioctl.jl")
    include("nverror.jl")

    const PAGE_SIZE = parse(Int, split(read(`getconf PAGE_SIZE`, String))[end])
    
    @inline function nvioctl(fd, number, params)
        r_params = Ref(params)

        GC.@preserve r_params begin
            ptr = Base.unsafe_convert(Ptr{Cvoid}, r_params)
            ret = IOCTL.ioctl(fd, IOCTL.Io(0, number), reinterpret(Clong, ptr))
            systemerror("ioctl", ret == -1)
        end
        @nvcheck(r_params[].rmStatus)
        return r_params[]
    end

    ##
    # Notes:
    # UVM_INITIALIZE is to big for the IOCTL number restriction
    # Nvidia: Does a direct case match on the ioctl param and thus
    # you can't provide direction or size information...

    const UVM_INITIALIZE = Culong(0x30000001)

    struct UVM_INITIALIZE_PARAMS
        flags::UInt64
        rmStatus::UInt32 # out
    end

    # On /dev/nvidia-uvm
    function initialize(fd, flags=0)
        nvioctl(fd, UVM_INITIALIZE, UVM_INITIALIZE_PARAMS(flags, 0))
        return nothing
    end

    const NV_UUID_LEN = 16
    struct nv_uuid
        uuid::NTuple{NV_UUID_LEN, UInt8}
    end

    nv_uuid() = nv_uuid(ntuple(_->UInt8(0), NV_UUID_LEN))

    const NvProcessorUuid = nv_uuid

    # Produced via uuidgen(1): 73772a14-2c41-4750-a27b-d4d74e0f5ea6:
    const NV_PROCESSOR_UUID_CPU_DEFAULT = NvProcessorUuid((
       0xa6, 0x5e, 0x0f, 0x4e, 0xd7, 0xd4, 0x7b, 0xa2,
       0x50, 0x47, 0x41, 0x2c, 0x14, 0x2a, 0x77, 0x73))

    const UVM_REGISTER_GPU = 37
    struct UVM_REGISTER_GPU_PARAMS
        gpu_uuid::NvProcessorUuid # In
        numaEnabled::UInt8        # Out
        numaNodeId::Int32         # Out
        rmCtrlFd::Int32           # In
        hClient::UInt32           # IN
        hSmcPartRef::UInt32       # IN
        rmStatus::UInt32          # Out
    end

    function register_gpu(fd, uuid, rmCtrlFd)
        params = UVM_REGISTER_GPU_PARAMS(uuid, 0, 0, rmCtrlFd, 0, 0, 0)
        params = nvioctl(fd, UVM_REGISTER_GPU, params)
        return(; numaEnabled=params.numaEnabled, numaNodeId=params.numaNodeId)
    end

    const UVM_UNREGISTER_GPU = 38
    struct UVM_UNREGISTER_GPU_PARAMS
        gpu_uuid::NvProcessorUuid # In
        rmStatus::UInt32          # Out
    end
    

    const UVM_PAGEABLE_MEM_ACCESS = 39
    struct UVM_PAGEABLE_MEM_ACCESS_PARAMS
        pageableMemAccess::UInt8 # In
        rmStatus::UInt32          # Out
    end

    function api_pageable_mem_access(fd)
        params = UVM_PAGEABLE_MEM_ACCESS_PARAMS(0, 0)
        params = nvioctl(fd, UVM_PAGEABLE_MEM_ACCESS, params)
        return params.pageableMemAccess != 0
    end

    const UVM_TOOLS_GET_PROCESSOR_UUID_TABLE = Culong(64)
    struct UVM_TOOLS_GET_PROCESSOR_UUID_TABLE_PARAMS
        tablePtr::UInt64
        count::UInt32
        rmStatus::UInt32
    end

    const UVM_MAX_GPUS = 32
    const UVM_MAX_PROCESSORS = (UVM_MAX_GPUS + 1)    

    function api_tools_get_processor_uuid_table(fd)
        table = Ref{NTuple{UVM_MAX_PROCESSORS, NvProcessorUuid}}()
        GC.@preserve table begin
            table_ptr = Base.unsafe_convert(Ptr{Cvoid}, table)
            params = UVM_TOOLS_GET_PROCESSOR_UUID_TABLE_PARAMS(reinterpret(UInt64, table_ptr), UVM_MAX_PROCESSORS, 0)
            params = nvioctl(fd, UVM_TOOLS_GET_PROCESSOR_UUID_TABLE, params)
        end
        count = params.count
        return ntuple(i->table[][i], count)
    end

    # nvidia-uvm-tools
    const UVM_TOOLS_INIT_EVENT_TRACKER = Culong(56)

    struct UVM_TOOLS_INIT_EVENT_TRACKER_PARAMS
        queueBuffer::UInt64
        queueBufferSize::UInt64
        controlBuffer::UInt64
        processor::NvProcessorUuid
        allProcessors::UInt32
        uvmFd::UInt32
        rmStatus::UInt32 # out
    end

    function memalign(align, size)
        r_ptr = Ref{Ptr{Cvoid}}()
        ret = ccall(:posix_memalign, Cint, (Ptr{Ptr{Cvoid}}, Csize_t, Csize_t), r_ptr, align, size)
        systemerror("posix_memalign", ret != 0)
        return r_ptr[]
    end

    const UVM_TOTAL_COUNTERS = 10

    function init_event_tracker(fd, uvm_fd, uuid; all_processors=true)
        # Needs to be at least 1 page
        controlBuffer = Base.unsafe_convert(Ptr{UInt64}, memalign(PAGE_SIZE, sizeof(UInt64) * UVM_TOTAL_COUNTERS))
        # zero controlBuffer
        buf = Base.unsafe_wrap(Array, controlBuffer, UVM_TOTAL_COUNTERS, own=false)
        buf .= 0
        try
            params = UVM_TOOLS_INIT_EVENT_TRACKER_PARAMS(0, 0, reinterpret(UInt64, controlBuffer), uuid, UInt32(all_processors), uvm_fd, 0)
            nvioctl(fd, UVM_TOOLS_INIT_EVENT_TRACKER, params)
        catch
            Libc.free(controlBuffer)
            rethrow()
        end

        return controlBuffer
    end

    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_SET_NOTIFICATION_THRESHOLD, uvm_api_tools_set_notification_threshold);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_EVENT_QUEUE_ENABLE_EVENTS,  uvm_api_tools_event_queue_enable_events);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_EVENT_QUEUE_DISABLE_EVENTS, uvm_api_tools_event_queue_disable_events);

    # Host to Device
    const UVM_COUNTER_NAME_FLAG_BYTES_XFER_HTD = 0x1
    # Device to Host
    const UVM_COUNTER_NAME_FLAG_BYTES_XFER_DTH = 0x2
    const UVM_COUNTER_NAME_FLAG_CPU_PAGE_FAULT_COUNT = 0x4
    # const UVM_COUNTER_NAME_FLAG_WDDM_BYTES_XFER_BTH = 0x8
    # const UVM_COUNTER_NAME_FLAG_WDDM_BYTES_XFER_HTB = 0x10
    # const UVM_COUNTER_NAME_FLAG_BYTES_XFER_DTB = 0x20
    # const UVM_COUNTER_NAME_FLAG_BYTES_XFER_BTD = 0x40
    # bytes prefetched host to device.
    # These bytes are also counted in
    # UvmCounterNameBytesXferHtD
    const UVM_COUNTER_NAME_FLAG_PREFETCH_BYTES_XFER_HTD = 0x80
    # bytes prefetched device to host.
    # These bytes are also counted in
    # UvmCounterNameBytesXferDtH
    const UVM_COUNTER_NAME_FLAG_PREFETCH_BYTES_XFER_DTH = 0x100
    # number of faults reported on the GPU
    const UVM_COUNTER_NAME_FLAG_GPU_PAGE_FAULT_COUNT = 0x200


    const UVM_TOOLS_ENABLE_COUNTERS = Culong(60)
    struct UVM_TOOLS_ENABLE_COUNTERS_PARAMS
        counterTypeFlags::UInt64
        rmStatus::UInt32
    end

    function tools_enable_counters(fd, flags)
        nvioctl(fd, UVM_TOOLS_ENABLE_COUNTERS, UVM_TOOLS_ENABLE_COUNTERS_PARAMS(flags, 0))        
        return nothing
    end

    const UVM_TOOLS_DISABLE_COUNTERS = Culong(61)
    struct UVM_TOOLS_DISABLE_COUNTERS_PARAMS
        counterTypeFlags::UInt64
        rmStatus::UInt32
    end

    function tools_disable_counters(fd, flags)
        nvioctl(fd, UVM_TOOLS_DISABLE_COUNTERS, UVM_TOOLS_DISABLE_COUNTERS_PARAMS(flags, 0))        
        return nothing
    end
end

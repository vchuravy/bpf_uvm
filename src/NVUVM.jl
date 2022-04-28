module NVUVM
    export UVM, UVMTools
    export initialize, get_gpu_uuid_table
    export init_event_tracker, add_session
    
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
    
    ##
    # Notes:
    # UVM_INITIALIZE is to big for the IOCTL number restriction
    # Nvidia: Does a direct case match on the ioctl param and thus
    # you can't provide direction or size information...

    const UVM_INITIALIZE = Culong(0x30000001)

    struct UVM_INITIALIZE_PARAMS
        flags::UInt64
        rmStatus::UInt32
    end

    # On /dev/nvidia-uvm
    function initialize(fd, flags=0)
        params = Ref(UVM_INITIALIZE_PARAMS(flags, 0))

        GC.@preserve params begin
            ptr = Base.unsafe_convert(Ptr{Cvoid}, params)
            ret = IOCTL.ioctl(fd, IOCTL.Io(0, UVM_INITIALIZE), reinterpret(Clong, ptr))
            systemerror("uvm_initialize", ret == -1)
        end

        @nvcheck(params[].rmStatus)
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

    const UVM_MAX_GPUS = 32
    const UVM_MAX_PROCESSORS = (UVM_MAX_GPUS + 1)

    # Seemingly not implemented
    #=
    const UVM_GET_GPU_UUID_TABLE = Culong(20)
    struct UVM_GET_GPU_UUID_TABLE_PARAMS
        gpuUuidArray::NTuple{UVM_MAX_GPUS, NvProcessorUuid}
        validCount::UInt32
        rmStatus::UInt32
    end

    function get_gpu_uuid_table(fd)
        params = Ref{UVM_GET_GPU_UUID_TABLE_PARAMS}()
        GC.@preserve params begin
            ptr = Base.unsafe_convert(Ptr{Cvoid}, params)

            ret = IOCTL.ioctl(fd, IOCTL.Io(0, UVM_GET_GPU_UUID_TABLE), reinterpret(Clong, ptr))
            systemerror("uvm_get_gpu_uuid_table", ret == -1)
        end

        gpus = params[].gpuUuidArray[1:params[].validCount]
        return (; rmStatus = params[].rmStatus, gpus)
    end
    =#

    # nvidia-uvm-tools
    const UVM_TOOLS_INIT_EVENT_TRACKER = Culong(56)

    struct UVM_TOOLS_INIT_EVENT_TRACKER_PARAMS
        queueBuffer::UInt64
        queueBufferSize::UInt64
        controlBuffer::UInt64
        processor::NvProcessorUuid
        allProcessors::UInt32
        uvmFd::UInt32
        rmStatus::UInt32
    end

    function memalign(align, size)
        r_ptr = Ref{Ptr{Cvoid}}()
        ret = ccall(:posix_memalign, Cint, (Ptr{Ptr{Cvoid}}, Csize_t, Csize_t), r_ptr, align, size)
        systemerror("posix_memalign", ret != 0)
        return r_ptr[]
    end

    const UVM_TOTAL_COUNTERS = 10

    function init_event_tracker(fd, uvm_fd, uuid)
        # Needs to be at least 1 page
        controlBuffer = memalign(PAGE_SIZE, sizeof(UInt64) * UVM_TOTAL_COUNTERS)
        try
            params = Ref(UVM_TOOLS_INIT_EVENT_TRACKER_PARAMS(0, 0, reinterpret(UInt64, controlBuffer), uuid, 0, uvm_fd, 0))
            GC.@preserve params begin
                ptr = Base.unsafe_convert(Ptr{Cvoid}, params)

                cmd = IOCTL.Io(0, UVM_TOOLS_INIT_EVENT_TRACKER)
                # cmd = IOCTL.IoRW(0, UVM_TOOLS_INIT_EVENT_TRACKER, sizeof(UVM_TOOLS_INIT_EVENT_TRACKER_PARAMS))
                ret = IOCTL.ioctl(fd, cmd, reinterpret(Clong, ptr))
                systemerror("uvm_init_event_tracker", ret == -1)
            end
            @nvcheck(params[].rmStatus)
        catch
            Libc.free(controlBuffer)
            rethrow()
        end

        return controlBuffer
    end

    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_SET_NOTIFICATION_THRESHOLD, uvm_api_tools_set_notification_threshold);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_EVENT_QUEUE_ENABLE_EVENTS,  uvm_api_tools_event_queue_enable_events);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_EVENT_QUEUE_DISABLE_EVENTS, uvm_api_tools_event_queue_disable_events);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_ENABLE_COUNTERS,            uvm_api_tools_enable_counters);
    # UVM_ROUTE_CMD_STACK_NO_INIT_CHECK(UVM_TOOLS_DISABLE_COUNTERS,           uvm_api_tools_disable_counters);

    # Seemingly not implemented
    #=
    const UVM_ADD_SESSION = Culong(10)
    struct UVM_ADD_SESSION_PARAMS
        pidTarget::UInt32
        padding::UInt32 # next value is aligned
        countersBaseAddress::Ptr{Cvoid}
        sessionIndex::Int32
        rmStatus::UInt32
    end
    UVM_ADD_SESSION_PARAMS(pidTarget, countersBaseAddress) = UVM_ADD_SESSION_PARAMS(pidTarget, 0, countersBaseAddress, 0, 0)

    function add_session(fd, pidTarget, countersBaseAddress)
        params = Ref(UVM_ADD_SESSION_PARAMS(pidTarget, countersBaseAddress))

        GC.@preserve params begin
            ptr = Base.unsafe_convert(Ptr{Cvoid}, params)

            ret = IOCTL.ioctl(fd, IOCTL.IoRW(IOCTL_APP_TYPE, UVM_ADD_SESSION, sizeof(UVM_ADD_SESSION_PARAMS)), reinterpret(Clong, ptr))
            systemerror("uvm_add_session", ret == -1)
        end

        return (; sessionIndex = params[].sessionIndex, rmStatus = params[].rmStatus)
    end

    const UVM_REMOVE_SESSION = Culong(10)
    struct UVM_REMOVE_SESSION_PARAMS
        sessionIndex::Int32
        rmStatus::UInt32
    end
    =#

    const UVM_MAX_COUNTERS_PER_IOCTL_CALL = 32

    struct UvmCounterConfig
        scope::UInt32
        name::UInt32
        gpuid::NvProcessorUuid
        state::UInt32
    end

    const UVM_ENABLE_COUNTERS = Culong(12)
    struct UVM_ENABLE_COUNTERS_PARAMS
        sessionIndex::Int32
        config::NTuple{UVM_MAX_COUNTERS_PER_IOCTL_CALL, UvmCounterConfig}
        count::UInt32
        rmStatus::UInt32
    end

    function enable_counters(uvm)
        IOCTL.ioctl(uvm, IOCTL.Io(0, UVM_ENABLE_COUNTERS), args...)
    end
end

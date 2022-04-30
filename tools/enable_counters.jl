#!/bin/env julia
push!(Base.LOAD_PATH, joinpath(@__DIR__, ".."))
using NVUVM

const uvm = UVM()
const uvm_tools = UVMTools()

# Important! We need to open the device we care about
# Otherwise we get EPERM on registration
const device_fd = UVM("/dev/nvidia0")

# 1. Initialize UVM driver on this process
initialize(uvm)
api_pageable_mem_access(uvm)

function uuid_to_device(uuid)
    NVUVM.NvProcessorUuid((reverse(reinterpret(UInt8, [uuid]))...,))
end

# Produced via nvidia-smi -L: d9b28d2d-828e-cae5-626b-dc354d9af00f:
# Or CUDA.uuid(device())
let device_uuid = uuid_to_device(Base.UUID("d9b28d2d-828e-cae5-626b-dc354d9af00f"))
    register_gpu(uvm, device_uuid, #=rmCtrlFd=#-1)
end

# 2. Enumerate device uuids
uuids = api_tools_get_processor_uuid_table(uvm)
if length(uuids) == 1
    error("No GPU available")
end

const device_uuid = last(uuids)

# 2. Setup uvm_tools, for now we are setting up counters and not events
control_buffer = init_event_tracker(uvm_tools, uvm, device_uuid)

# const counters = NVUVM.UVM_COUNTER_NAME_FLAG_GPU_PAGE_FAULT_COUNT | NVUVM.UVM_COUNTER_NAME_FLAG_CPU_PAGE_FAULT_COUNT 

const counters = NVUVM.UVM_COUNTER_NAME_FLAG_BYTES_XFER_HTD | NVUVM.UVM_COUNTER_NAME_FLAG_BYTES_XFER_DTH |
                 NVUVM.UVM_COUNTER_NAME_FLAG_CPU_PAGE_FAULT_COUNT | NVUVM.UVM_COUNTER_NAME_FLAG_PREFETCH_BYTES_XFER_HTD |
                 NVUVM.UVM_COUNTER_NAME_FLAG_PREFETCH_BYTES_XFER_DTH | NVUVM.UVM_COUNTER_NAME_FLAG_GPU_PAGE_FAULT_COUNT
tools_enable_counters(uvm_tools, counters)


# test
# for counter in (0, 1, 2, 7, 8, 9)
#     NVUVM.test_increment_tools_counter(uvm, 1, counter, device_uuid, 1+counter)
# end

# TODO poll?

println("Press enter to exit...")
try
    readline()
catch err
    if !(err isa InterruptException)
        rethrow(err)
    end
end

function read_counters(control_buffer)
    copy(Base.unsafe_wrap(Array{UInt64}, control_buffer, NVUVM.UVM_TOTAL_COUNTERS, own=false))
end

@show read_counters(control_buffer)

tools_disable_counters(uvm_tools, counters)

# TODO deinitialize uvm_tools & uvm
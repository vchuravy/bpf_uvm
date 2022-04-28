#!/bin/env julia
push!(Base.LOAD_PATH, joinpath(@__DIR__, ".."))
using NVUVM

const uvm = UVM()
const uvm_tools = UVMTools()

# 1. Initialize UVM driver on this process
initialize(uvm)

# TODO: Figure out target device id

# Produced via nvidia-smi -L: d9b28d2d-828e-cae5-626b-dc354d9af00f:
const device_uuid = NVUVM.NvProcessorUuid((
    0x0f, 0xf0, 0x9a, 0x4d, 0x35, 0xdc, 0x6b, 0x62,
    0xe5, 0xca, 0x8e, 0x82, 0x2d, 0x8d, 0xb2, 0xd9))


# 2. Setup uvm_tools
control_buffer = init_event_tracker(uvm_tools, uvm, device_uuid)

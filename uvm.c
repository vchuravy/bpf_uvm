#include <uapi/linux/ptrace.h>
// #include <nvidia-uvm/uvm_common.h>

// See nvidia-uvm/uvm_perf_events.h
// We inline the headers, because there are some pieces missing

typedef unsigned __INT32_TYPE__ NvU32; /* 0 to 4294967295                       */
typedef   signed __INT32_TYPE__ NvS32; /* -2147483648 to 2147483647             */
typedef unsigned long long NvU64; /* 0 to 18446744073709551615                      */
typedef          long long NvS64; /* -9223372036854775808 to 9223372036854775807    */
typedef void*              NvP64; /* 64 bit void pointer                     */
typedef NvU64             NvUPtr; /* pointer sized unsigned int              */
typedef NvS64             NvSPtr; /* pointer sized signed int                */
typedef NvU64           NvLength; /* length to agree with sizeof             */

typedef enum
{
    // Locking: uvm_va_space: at least in read mode, uvm_va_block: exclusive / nobody is referencing the block anymore
    UVM_PERF_EVENT_BLOCK_DESTROY = 0,

    // Locking: uvm_va_space: write
    UVM_PERF_EVENT_BLOCK_SHRINK,

    // Locking: uvm_va_space: write
    UVM_PERF_EVENT_RANGE_DESTROY,

    // Locking: uvm_va_space: write
    UVM_PERF_EVENT_RANGE_SHRINK,

    // Locking: uvm_va_space: write
    UVM_PERF_EVENT_MODULE_UNLOAD,

    // Locking: uvm_va_space: at least in read mode, uvm_va_block: exclusive (if uvm_va_block is not NULL)
    UVM_PERF_EVENT_FAULT,

    // Locking: uvm_va_block: exclusive. Notably the uvm_va_space lock may not be held on eviction.
    UVM_PERF_EVENT_MIGRATION,

    // Locking: uvm_va_space: at least in read mode, uvm_va_block: exclusive
    UVM_PERF_EVENT_REVOCATION,

    UVM_PERF_EVENT_COUNT,
} uvm_perf_event_t;

typedef struct
{
    NvU32 val;
} uvm_processor_id_t;

static bool uvm_id_equal(uvm_processor_id_t id1, uvm_processor_id_t id2)
{
    // UVM_ID_CHECK_BOUNDS(id1);
    // UVM_ID_CHECK_BOUNDS(id2);

    return id1.val == id2.val;
}

#define NV_MAX_DEVICES          32
#define UVM_MAX_GPUS         NV_MAX_DEVICES
#define UVM_MAX_PROCESSORS   (UVM_MAX_GPUS + 1)
#define UVM_ID_MAX_PROCESSORS UVM_MAX_PROCESSORS

#define UVM_ID_CPU_VALUE      0
#define UVM_ID_CPU            ((uvm_processor_id_t) { .val = UVM_ID_CPU_VALUE })
#define UVM_ID_INVALID        ((uvm_processor_id_t) { .val = UVM_ID_MAX_PROCESSORS })
#define UVM_ID_IS_CPU(id)     uvm_id_equal(id, UVM_ID_CPU)
#define UVM_ID_IS_INVALID(id) uvm_id_equal(id, UVM_ID_INVALID)
#define UVM_ID_IS_VALID(id)   (!UVM_ID_IS_INVALID(id))
#define UVM_ID_IS_GPU(id)     (!UVM_ID_IS_CPU(id) && !UVM_ID_IS_INVALID(id))

typedef enum
{
    UVM_VA_BLOCK_TRANSFER_MODE_MOVE = 1,
    UVM_VA_BLOCK_TRANSFER_MODE_COPY = 2
} uvm_va_block_transfer_mode_t;

typedef enum
{
    UVM_MAKE_RESIDENT_CAUSE_REPLAYABLE_FAULT,
    UVM_MAKE_RESIDENT_CAUSE_NON_REPLAYABLE_FAULT,
    UVM_MAKE_RESIDENT_CAUSE_ACCESS_COUNTER,
    UVM_MAKE_RESIDENT_CAUSE_PREFETCH,
    UVM_MAKE_RESIDENT_CAUSE_EVICTION,
    UVM_MAKE_RESIDENT_CAUSE_API_TOOLS,
    UVM_MAKE_RESIDENT_CAUSE_API_MIGRATE,
    UVM_MAKE_RESIDENT_CAUSE_API_SET_RANGE_GROUP,
    UVM_MAKE_RESIDENT_CAUSE_API_HINT,

    UVM_MAKE_RESIDENT_CAUSE_MAX
} uvm_make_resident_cause_t;

// struct uvm_fault_buffer_entry_struct
// {
//     //
//     // The next fields are filled by the fault buffer parsing code
//     //

//     // Virtual address of the faulting request aligned to CPU page size
//     NvU64                                fault_address;

//     // GPU timestamp in (nanoseconds) when the fault was inserted in the fault
//     // buffer
//     NvU64                                    timestamp;

//     uvm_gpu_phys_address_t                instance_ptr;

//     uvm_fault_source_t                    fault_source;

//     uvm_fault_type_t                        fault_type : order_base_2(UVM_FAULT_TYPE_COUNT) + 1;

//     uvm_fault_access_type_t          fault_access_type : order_base_2(UVM_FAULT_ACCESS_TYPE_COUNT) + 1;

//     //
//     // The next fields are managed by the fault handling code
//     //

//     uvm_va_space_t                           *va_space;

//     // This is set to true when some fault could not be serviced and a
//     // cancel command needs to be issued
//     bool                                      is_fatal : 1;

//     // This is set to true for all GPU faults on a page that is thrashing
//     bool                                  is_throttled : 1;

//     // This is set to true if the fault has prefetch access type and the
//     // address or the access privileges are not valid
//     bool                           is_invalid_prefetch : 1;

//     bool                                 is_replayable : 1;

//     bool                                    is_virtual : 1;

//     bool                             in_protected_mode : 1;

//     bool                                      filtered : 1;

//     // Reason for the fault to be fatal
//     UvmEventFatalReason                   fatal_reason : order_base_2(UvmEventNumFatalReasons) + 1;

//     // Mode to be used to cancel faults. This must be set according to the
//     // fatal fault reason and the fault access types of the merged fault
//     // instances.
//     union
//     {
//         struct
//         {
//             uvm_fault_cancel_va_mode_t  cancel_va_mode : order_base_2(UVM_FAULT_CANCEL_VA_MODE_COUNT) + 1;
//         } replayable;

//         struct
//         {
//             NvU32                         buffer_index;
//         } non_replayable;
//     };

//     // List of duplicate fault buffer entries that have been merged into this
//     // one
//     struct list_head        merged_instances_list;

//     // Access types to this page for all accesses that have been coalesced at
//     // fetch time. It must include, at least, fault_access_type
//     NvU32                        access_type_mask;

//     // Number of faults with the same properties that have been coalesced at
//     // fetch time
//     NvU16                           num_instances;
// };

typedef union
{
    // struct
    // {
    //     uvm_va_block_t *block;
    // } block_destroy;

    // struct
    // {
    //     uvm_va_block_t *block;
    // } block_shrink;

    // struct
    // {
    //     uvm_va_range_t *range;
    // } range_destroy;

    // struct
    // {
    //     uvm_va_range_t *range;
    // } range_shrink;

    // struct
    // {
    //     uvm_perf_module_t *module;

    //     // Only one of these two can be set. The other one must be NULL
    //     uvm_va_block_t *block;
    //     uvm_va_range_t *range;
    // } module_unload;

    struct
    {
        // This field contains the VA space where this fault was reported.
        // If block is not NULL, this field must match
        // uvm_va_block_get_va_space(block).
        void *space;

        // VA block for the page where the fault was triggered if it exists,
        // NULL otherwise (this can happen if the fault is fatal or the
        // VA block could not be created).
        void *block;

        uvm_processor_id_t proc_id;

        // Fault descriptor
        union
        {
            struct
            {
                // uvm_fault_buffer_entry_t *buffer_entry;
                void *buffer_entry;

                NvU32 batch_id;

                bool is_duplicate;
            } gpu;

            struct
            {
                NvU64 fault_va;

                bool is_write;

                NvU64 pc;
            } cpu;
        };
    } fault;

    // This event is emitted during migration and the residency bits may be
    // stale. Do not rely on them in the callbacks.
    struct
    {
        void *push;
        void *block;

        // ID of the destination processor of the migration
        uvm_processor_id_t dst;

        // ID of the source processor of the migration
        uvm_processor_id_t src;

        // Start address of the memory range being migrated
        NvU64 address;

        // Number of bytes being migrated
        NvU64 bytes;

        // Whether the page has been copied or moved
        uvm_va_block_transfer_mode_t transfer_mode;

        // Event that performed the call to make_resident
        uvm_make_resident_cause_t cause;

        // Pointer to the make_resident context from the va_block_context
        // struct used by the operation that triggered the make_resident call.
        void *make_resident_context;
    } migration;

    // struct
    // {
    //     uvm_va_block_t *block;

    //     // ID of the processor whose access permissions have been revoked
    //     uvm_processor_id_t proc_id;

    //     // Start address of the memory range being revoked
    //     NvU64 address;

    //     // Number of bytes of the memory range being revoked
    //     NvU64 bytes;

    //     // Old access permission
    //     uvm_prot_t old_prot;

    //     // New access permission
    //     uvm_prot_t new_prot;
    // } revocation;
} uvm_perf_event_data_t;


BPF_PERF_OUTPUT(migrations);
BPF_PERF_OUTPUT(gpu_faults);
BPF_PERF_OUTPUT(cpu_faults);
BPF_PERF_OUTPUT(revocations);

struct migration_t {
    u64 bytes;
    uvm_va_block_transfer_mode_t transfer_mode;
    uvm_make_resident_cause_t cause;
};

struct gpu_fault_t {
    u32 proc_id;
};

struct cpu_fault_t {
    u32 proc_id;
};

int uvm_perf_event_notify(struct pt_regs *ctx, void *va_space_events, uvm_perf_event_t event_id,
                          uvm_perf_event_data_t *event_data)
{
    if (event_id == UVM_PERF_EVENT_MIGRATION) {
        struct migration_t m = {};
        m.bytes = event_data->migration.bytes;
        m.transfer_mode = event_data->migration.transfer_mode;
        m.cause = event_data->migration.cause;

        migrations.perf_submit(ctx, &m, sizeof(m));
    } else if (event_id == UVM_PERF_EVENT_FAULT) {
        uvm_processor_id_t proc_id = event_data->fault.proc_id;
        if (UVM_ID_IS_CPU(proc_id)) {
            struct cpu_fault_t f = {};
            f.proc_id = proc_id.val;

            cpu_faults.perf_submit(ctx, &f, sizeof(f));
        } else if (UVM_ID_IS_GPU(proc_id)) {
            struct gpu_fault_t f = {};
            f.proc_id = proc_id.val;

            gpu_faults.perf_submit(ctx, &f, sizeof(f));
        }
    } else if (event_id == UVM_PERF_EVENT_REVOCATION) {

    }
    return 0;
}

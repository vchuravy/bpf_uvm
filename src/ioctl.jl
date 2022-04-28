module IOCTL
    const TypeBits      = 8
    const NumberBits    = 8
    const SizeBits      = 14
    const DirectionBits = 2

    const TypeMask      = (Culong(1) << TypeBits) - 1
    const NumberMask    = (Culong(1) << NumberBits) - 1
    const SizeMask      = (Culong(1) << SizeBits) - 1
    const DirectionMask = (Culong(1) << DirectionBits) - 1

    const DirectionNone  = 0
    const DirectionWrite = 1
    const DirectionRead  = 2

    const NumberShift    = 0
    const TypeShift      = NumberShift + NumberBits
    const SizeShift      = TypeShift + TypeBits
    const DirectionShift = SizeShift + SizeBits

    function ioc(dir, type, nr, size)::Culong
        # return ((Culong(dir) & DirectionMask) << DirectionShift) |
        #        ((Culong(type) & TypeMask) << TypeShift) |
        #        ((Culong(nr) & NumberMask) << NumberShift) |
        #        ((Culong(size) & SizeMask) << SizeShift)
        # uvm_initialize ignores the size restriction on the type
        return (Culong(dir) << DirectionShift) |
               (Culong(type) << TypeShift) |
               (Culong(nr) << NumberShift) |
               (Culong(size) << SizeShift)
    end

    # Io used for a simple ioctl that sends nothing but the type and number, and receives back nothing but an (integer) retval.
    function Io(type, nr)
     return ioc(DirectionNone, type, nr, 0)
    end

    # IoR used for an ioctl that reads data from the device driver. The driver will be allowed to return sizeof(data_type) bytes to the user.
    function IoR(type, nr, size)
     return ioc(DirectionRead, type, nr, size)
    end

    # IoW used for an ioctl that writes data to the device driver.
    function IoW(type, nr, size)
     return ioc(DirectionWrite, type, nr, size)
    end

    # IoRW a combination of IoR and IoW. That is, data is both written to the driver and then read back from the driver by the client.
    function IoRW(type, nr, size)
     return ioc(DirectionRead|DirectionWrite, type, nr, size)
    end

    function ioctl(fd, ioctl_number, args...)
        ccall(:ioctl, Cint, (Cint, Culong, Culong...), fd, ioctl_number, args...)
    end
end

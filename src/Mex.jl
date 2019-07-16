module Mex

using MATLAB, Libdl

export jl_mex, input, call_matlab, is_interrupt_pending, check_for_interrupt

# --- Initialization --- #

# MATLAB mex interface
const libmex = Ref{Ptr{Cvoid}}()
const mex_call_matlab_with_trap = Ref{Ptr{Cvoid}}()

# MATLAB interrupt handling (from undocumented MATLAB)
const libut = Ref{Ptr{Cvoid}}()
const ut_is_interrupt_pending = Ref{Ptr{Cvoid}}()

function __init__()
    libmex[] = Libdl.dlopen(joinpath(MATLAB.matlab_libpath(), "libmex"), Libdl.RTLD_GLOBAL)
    mex_call_matlab_with_trap[] = Libdl.dlsym(libmex[], :mexCallMATLABWithTrap)

    libut[]  = Libdl.dlopen(joinpath(MATLAB.matlab_libpath(), "libut"), Libdl.RTLD_GLOBAL)
    ut_is_interrupt_pending[] = Libdl.dlsym(libut[], :utIsInterruptPending)
end

include("exceptions.jl")
include("juliatomatlab.jl")
include("matlabtojulia.jl")

end # module

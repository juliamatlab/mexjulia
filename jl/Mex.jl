module Mex

using MxArrays

export jl_mex, call_matlab, mexfn, redirect_output

# the libmex library
const libmex = open_matlab_library("libmex")

# return pointer to the appropriate libmex function
mexfn(s::Symbol) = Libdl.dlsym(libmex, s)

# some libmex functions used internally
const _call_matlab_with_trap = mexfn(:mexCallMATLABWithTrap)
const _err_msg_txt = mexfn(:mexErrMsgTxt)

# Call a matlab function specified by name
function call_matlab(fn::String, args::Vector{MxArray}, nout::Integer = 1)
    ins = Ptr{Void}[arg.ptr for arg in args]
    nin = length(ins)
    outs = Vector{Ptr{Void}}(nout)

    ptr = ccall(_call_matlab_with_trap, Ptr{Void},
        (Int32, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Void}}, Ptr{UInt8}),
        nout, outs, nin, ins, fn)
    if ptr != C_NULL
        # pass MATLAB exception to Julia
        msg = jstring(call_matlab("getReport", [MxArray(ptr), MxArray("basic")], 1)[1])
        error(msg)
    end

    MxArray[MxArray(o) for o in outs]
end

# Make MxArray callable. Works for strings or function handles.
# This version allows full control over data marshaling.
function (mx::MxArray)(args::Vector{MxArray}, nout::Integer = 1)
    _args = MxArray[mx]
    append!(_args, args)
    return call_matlab("feval", _args, nout)
end

# This version uses default data marshaling
function (mx::MxArray)(args...)
    jvals = MxArray[MxArray(arg) for arg in args]
    Any(mx(jvals)[1])
end

# Pass Julia exception up to MATLAB
function mex_throw(e, bt)
    buf = IOBuffer()
    showerror(buf, e, bt)
    seek(buf, 0)
    errmsg = readstring(buf)
    ccall(_err_msg_txt, Void, (Ptr{UInt8},), errmsg)
end

# safe, convenient wrapper for mex-like Julia functions
function jl_mex(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
    try
        args = [MxArray(arg, false) for arg in ins]
        vals = eval(parse(Any(args[1])))(args[2:end])
        nouts = length(outs)
        outix = 1
        for val in vals
            if outix > nouts
                break
            end
            mx = MxArray(val)
            mx.own = false
            outs[outix] = mx.ptr
            outix += 1
        end
    catch e
        mex_throw(e, catch_backtrace())
    end
end

# a fancier eval
jl_eval(exprs::Vector{MxArray}) = [eval(parse(Any(e))) for e in exprs]

# call an arbitrary julia function (or other callable)
function jl_call(args::Vector{MxArray})
    vals = map(Any, args)
    [eval(parse(vals[1]))(vals[2:end]...)]
end


# *** stuff for redirecting output

function fwrite(fid::Float64, str::String)
    call_matlab("fwrite", MxArray[MxArray(fid), MxArray(str), MxArray("char")], 0)
    nothing
end

function readloop(fid, s)
    try
        while(isopen(s))
            fwrite(fid, String(readavailable(s)))
        end
    catch e
        mex_throw(e, catch_backtrace())
    end
end

global mexstdout = nothing
global mexstderr = nothing

function redirect_output()
    global mexstdout
    global mexstderr

    if mexstdout == nothing || !isopen(mexstdout)
        mexstdout = redirect_stdout()[1]
        @schedule readloop(1.0, mexstdout)
    end
    if mexstderr == nothing || !isopen(mexstderr)
        mexstderr = redirect_stderr()[1]
        @schedule readloop(2.0, mexstderr)
    end

    nothing
end

end # module

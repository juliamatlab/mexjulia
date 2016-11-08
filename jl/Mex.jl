module Mex

using MxArrays

export jl_mex, call_matlab, redirect_output

# the libmex library
const libmex = open_matlab_library("libmex")
const _call_matlab_with_trap = Libdl.dlsym(libmex, :mexCallMATLABWithTrap)

# Call a matlab function specified by name
# This version allows full control over data marshaling.
function call_matlab(fn::String, args::Vector{MxArray}, nout::Integer = 1)
    ins = Ptr{Void}[arg.ptr for arg in args]
    nin = length(ins)
    outs = Vector{Ptr{Void}}(nout)

    ptr = ccall(_call_matlab_with_trap, Ptr{Void},
        (Int32, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Void}}, Ptr{UInt8}),
        nout, outs, nin, ins, fn)
    if ptr != C_NULL
        # pass MATLAB exception to Julia
        msg = jstring(call_matlab("getReport", [MxArray(ptr), mxarray("basic")], 1)[1])
        error(msg)
    end

    MxArray[MxArray(o) for o in outs]
end

# This version uses default data marshaling.
function call_matlab(fn, args...)
    mxs = MxArray[mxarray(arg) for arg in args]
    jvalue(call_matlab(fn, mxs, 1)[1])
end

# Make MxArray callable. Works for strings or function handles.
# This version allows full control over data marshaling.
function (mx::MxArray)(args::Vector{MxArray}, nout::Integer = 1)
    _args = MxArray[mx]
    append!(_args, args)
    return call_matlab("feval", _args, nout)
end

# This version uses default data marshaling.
function (mx::MxArray)(args...)
    mxs = MxArray[mxarray(arg) for arg in args]
    jvalue(mx(mxs)[1])
end

# Encode Julia error as string
function error_string(e, bt)
    buf = IOBuffer()
    showerror(buf, e, bt)
    seek(buf, 0)
    readstring(buf)
end

# safe, convenient wrapper for mex-like Julia functions
function jl_mex(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
    nouts = length(outs)
    none = mxarray(false)
    none.own = false
    for ix in 1:nouts
        outs[ix] = none.ptr
    end
    try
        args = [MxArray(arg, false) for arg in ins]
        vals = eval(Main, parse(jvalue(args[1])))(args[2:end])
        outix = 2
        for val in vals
            if outix > nouts
                break
            end
            mx = mxarray(val)
            mx.own = false
            outs[outix] = mx.ptr
            outix += 1
        end
    catch e
        msg = mxarray(error_string(e, catch_backtrace()))
        msg.own = false
        outs[1] = msg.ptr
    end
    flush(STDOUT)
    flush(STDERR)
    gc()
end

# a fancier eval
jl_eval(exprs::Vector{MxArray}) = [eval(Main, parse(jvalue(e))) for e in exprs]

# call an arbitrary julia function (or other callable)
function jl_call(args::Vector{MxArray})
    vals = map(jvalue, args)
    [eval(Main, parse(vals[1]))(vals[2:end]...)]
end

# call a julia function with keyword arguments
# the first value is an integer, n,  representing the number of positional arguments
# the second value represents a function to call
# the next n arguments are assumed to be positional
# all following arguments are assumed to be grouped in pairs, the first is the
# name of the keyword argument, the second its value
function jl_call_kw(args::Vector{MxArray})
    vals = map(jvalue, args)
    npos = vals[1]
    expr = Expr(:call, parse(vals[2]))
    for ix in 3:(2+npos)
        push!(expr.args, vals[ix])
    end
    for ix in (3+npos):2:length(vals)
        push!(expr.args, Expr(:kw, parse(vals[ix]), vals[ix+1]))
    end
    [eval(Main, expr)]
end


# *** stuff for redirecting output

function fwrite(fid, msg)
    call_matlab("fwrite", convert(Float64, fid), msg, "char")
    nothing
end

function readloop(fid, s)
    try
        while(isopen(s))
            fwrite(fid, String(readavailable(s)))
        end
    catch e
        fwrite(2, error_string(e, catch_backtrace()))
    end
end

global mexstdout = nothing
global mexstderr = nothing

function redirect_output()
    global mexstdout
    global mexstderr

    if mexstdout == nothing || !isopen(mexstdout)
        mexstdout = redirect_stdout()[1]
        @schedule readloop(1, mexstdout)
    end
    if mexstderr == nothing || !isopen(mexstderr)
        mexstderr = redirect_stderr()[1]
        @schedule readloop(2, mexstderr)
    end

    nothing
end

end # module

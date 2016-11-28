module Mex

using MxArrays

export jl_mex, call_matlab, redirect_output, is_interrupt_pending, check_for_interrupt


# *** ccall stuff ***

const libmex = open_matlab_library("libmex")
const _call_matlab_with_trap = Libdl.dlsym(libmex, :mexCallMATLABWithTrap)
const libut = open_matlab_library("libut")
const _is_interrupt_pending = Libdl.dlsym(libut, :utIsInterruptPending)


# *** interrupt handling ***

is_interrupt_pending() = ccall(_is_interrupt_pending, UInt8, ()) != 0

function check_for_interrupt()
    if is_interrupt_pending()
        throw(InterruptException())
    end
end


# *** exception handling ***

type MatlabException <: Exception
    ptr::Ptr{Void}
    MatlabException(ptr::Ptr{Void}) = new(ptr)
end

function MatlabException(id::String, msg::String)
    mxid = "jl:"*replace(id, r"[^\w\s]", "_")
    mx = call_matlab(1, "MException", MxArray[MxArray(mxid), MxArray(msg)])[1]
    return MatlabException(mx.ptr)
end

MatlabException(mexn::MatlabException) = mexn

function MatlabException(exn)
    buf = IOBuffer()
    showerror(buf, exn)
    seek(buf, 0)
    msg = replace(readstring(buf), "\\", "\\\\")
    return MatlabException(string(typeof(exn)), msg)
end

function add_cause(mexn::MatlabException, cause::MatlabException)
    args = MxArray[MxArray(x.ptr) for x in [mexn, cause]]
    mx = call_matlab(1, "addCause", args)[1]
    return MatlabException(mx.ptr)
end

function add_backtrace(exn, bt)
    buf = IOBuffer()
    print(buf, "Julia backtrace:")
    Base.show_backtrace(buf, bt)
    seek(buf, 0)
    msg = replace(readstring(buf), "\\", "\\\\")
    cause = MatlabException("backtrace", msg)
    return add_cause(MatlabException(exn), cause)
end


# *** calling into MATLAB ***

# Call a matlab function specified by name
# This version allows full control over data marshaling.
function call_matlab(nout::Integer, fn::String, args::Vector{MxArray})
    ins = Ptr{Void}[arg.ptr for arg in args]
    nin = length(ins)
    outs = Vector{Ptr{Void}}(nout)

    ptr = ccall(_call_matlab_with_trap, Ptr{Void},
        (Int32, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Void}}, Ptr{UInt8}),
        nout, outs, nin, ins, fn)
    if ptr != C_NULL
        throw(MatlabException(ptr))
    end

    return MxArray[MxArray(o) for o in outs]
end

# This version uses default data marshaling.
function call_matlab(nout, fn, args...)
    mxin = MxArray[MxArray(arg) for arg in args]
    return map(jvalue, call_matlab(nout, fn, mxin))
end

# Make MxArray callable. Works for strings or function handles.
# This version allows full control over data marshaling.
function (mx::MxArray)(nout::Integer, args::Vector{MxArray})
    _args = MxArray[mx]
    append!(_args, args)
    return call_matlab(nout, "feval", _args)
end

# This version uses default data marshaling and assumes exactly one return value.
function (mx::MxArray)(args...)
    mxs = MxArray[MxArray(arg) for arg in args]
    return jvalue(mx(1, mxs)[1])
end


# *** stdout/stderr redirection

function fwrite(fid, msg)
    call_matlab(0, "fwrite", convert(Float64, fid), msg, "char")
    return
end

function readloop(stream, fid)
    try
        while isopen(stream)
            fwrite(fid, readavailable(stream))
        end
    end
end

const mexstdout = redirect_stdout()[1]
const mexstderr = redirect_stderr()[1]
@schedule readloop(mexstdout, 1)
@schedule readloop(mexstderr, 2)


# the entry point for calling into julia from matlab
global jl_mex_call_depth = 0
function jl_mex(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
    global jl_mex_call_depth += 1
    try
        if jl_mex_call_depth == 1
            jl_mex_outer(outs, ins)
        else
            jl_mex_inner(outs, ins)
        end
    finally
        jl_mex_call_depth -= 1
    end
end

function jl_mex_outer(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
    @sync begin
        # do the desired computation
        main_task = @async jl_mex_inner(outs, ins)

        # check for interrupt
        @async while(!istaskdone(main_task))
            if is_interrupt_pending()
                Base.throwto(main_task, InterruptException())
            end
            yield()
        end
    end
end

function jl_mex_inner(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
    nouts = length(outs)
    none = MxArray(false)
    for ix in 1:nouts
        outs[ix] = none.ptr
    end
    try
        args = [MxArray(arg) for arg in ins]
        vals = eval(Main, parse(jvalue(args[1])))(args[2:end])
        outix = 2
        for val in vals
            if outix > nouts
                break
            end
            mx = MxArray(val)
            outs[outix] = mx.ptr
            outix += 1
        end
    catch exn
        outs[1] = add_backtrace(exn, catch_backtrace()).ptr
    end
end

# evaluate Julia expressions
jl_eval(exprs::Vector{MxArray}) = [eval(Main, parse(jvalue(e))) for e in exprs]

# Call a julia function, possibly with keyword arguments.
#
# The values in the args array are interpreted as follows:
#      Index = Meaning
# -----------------------------------------------------------
#          1 = the function to call
#          2 = an integer, npos, the number of positional arguments
#   3:2+npos = positional arguments
# 3+npos:end = keyword arguments, in keyword/value pairs
#
# If npos < 0, all arguments are assumed positional.
function jl_call_kw(args::Vector{MxArray})
    vals = map(jvalue, args)
    nvals = length(vals)
    expr = Expr(:call, parse(vals[1]))
    npos = vals[2]
    if npos < 0
        npos = nvals - 2
    end
    for ix in 3:(2+npos)
        push!(expr.args, vals[ix])
    end
    for ix in (3+npos):2:nvals
        push!(expr.args, Expr(:kw, parse(vals[ix]), vals[ix+1]))
    end
    return [eval(Main, expr)]
end

end # module

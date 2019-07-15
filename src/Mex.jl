module Mex

using MATLAB, Libdl

export jl_mex, input, call_matlab, is_interrupt_pending, check_for_interrupt

# --- Initialization --- #

# libraries

const libmex = Ref{Ptr{Cvoid}}()
const libut = Ref{Ptr{Cvoid}}()

# mex functions

const mex_call_matlab_with_trap = Ref{Ptr{Cvoid}}()

# ut functions

const ut_is_interrupt_pending = Ref{Ptr{Cvoid}}()

function __init__()
    libmex[] = Libdl.dlopen(joinpath(MATLAB.matlab_libpath(), "libmex"), Libdl.RTLD_GLOBAL)
    libut[]  = Libdl.dlopen(joinpath(MATLAB.matlab_libpath(), "libut"), Libdl.RTLD_GLOBAL)

    mex_call_matlab_with_trap[] = Libdl.dlsym(libmex[], :mexCallMATLABWithTrap)
    ut_is_interrupt_pending[] = Libdl.dlsym(libut[], :utIsInterruptPending)

end

# --- Interrupt Handling --- #

is_interrupt_pending() = ccall(ut_is_interrupt_pending[], UInt8, ()) != 0

function check_for_interrupt()
    if is_interrupt_pending()
        throw(InterruptException())
    end
end

# --- Exception Handling --- #

# MatlabException is basically identical to MxArray, but is an exception
# MATLAB is responsible for both creating and modifying the exception data
# so no garbage collection should be performed on the Julia side
mutable struct MatlabException <: Exception
    ptr::Ptr{Cvoid}
    MatlabException(ptr::Ptr{Cvoid}) = new(ptr)
end

# creates a MatlabException from an id and a message
function MatlabException(id::String, msg::String)

    # create error ID and message text
    msgID = MATLAB.mxarray("jl:"*replace(id, r"[^\w\s]"=>"_"))
    msgtext = MATLAB.mxarray(msg)

    # call MException to generate a MATLAB exception
    args = [MATLAB.mxarray(msgID), MATLAB.mxarray(msg)]
    mx = call_matlab(1, "MException", args)[1]

    # wrap as a MatlabException and return
    return MatlabException(mx.ptr)
end

# creates a MATLABException from an exception
function MatlabException(exn::Exception)

    # print formatted error message to buffer
    buf = IOBuffer()
    showerror(buf, exn)

    # move to beginning of buffer
    seek(buf, 0)

    # set id as the exception type
    id = string(typeof(exn))

    # convert to string and format for use with MATLAB
    msg = replace(read(buf, String), "\\"=>"\\\\")

    return MatlabException(id, msg)
end

# don't create a new MATLABException from a MATLABException
MatlabException(mexn::MatlabException) = mexn

# adds a cause to a MatlabException
function MatlabException(mexn::MatlabException, cause::MatlabException)

    # wrap MATLAB exceptions as MxArrays
    baseException = MATLAB.MxArray(mexn.ptr, false)
    causeException = MATLAB.MxArray(cause.ptr, false)

    # call addCause to append causeException to baseException
    args = [MATLAB.MxArray(mexn.ptr), MATLAB.MxArray(cause.ptr)]
    newException = call_matlab(1, "addCause", args)[1]

    # wrap result as an exception
    return MatlabException(newException.ptr)
end

# creates a MATLABException from an exception and a backtrace
function MatlabException(exn::Exception, bt::Array{Union{Ptr{Nothing}, Base.InterpreterIP},1})

    # create MATLABException from exception
    mexn = MatlabException(exn)

    # print formatted backtrace to buffer
    buf = IOBuffer()
    print(buf, "Julia backtrace:")
    Base.show_backtrace(buf, bt)

    # move to beginning of buffer
    seek(buf, 0)

    # convert to string and format for use with MATLAB
    msg = replace(read(buf, String), "\\"=>"\\\\")

    # create cause MatlabException
    cause = MatlabException("backtrace", msg)

    # add cause to the MatlabException and return the result
    return MatlabException(mexn, cause)
end

# --- Calling Into MATLAB from embedded Julia --- #

# Call a matlab function specified by name
function call_matlab(nout::Integer, fn::String, args::Vector{MATLAB.MxArray})

    # initialize outputs
    outs = fill(C_NULL, nout)

    # call matlab
    ptr = ccall(mex_call_matlab_with_trap[], Ptr{Cvoid},
        (Int32, Ptr{Ptr{Cvoid}}, Int32, Ptr{Ptr{Cvoid}}, Ptr{UInt8}),
        nout, outs, length(args), args, fn)

    # check for errors
    if ptr != C_NULL
        throw(MatlabException(ptr))
    end

    # return dressed up outputs
    return MATLAB.MxArray.(outs, false)
end

# this version handles argument conversions to and from MATLAB
call_matlab(nout::Integer, fn::String, args...) = MATLAB.jvalue.(call_matlab(nout, fn, MATLAB.mxarray.(collect(args))))

# Make MxArray callable. Works for strings or function handles.
(mx::MATLAB.MxArray)(nout::Integer, args::Vector{MATLAB.MxArray}) = call_matlab(nout, "feval", vcat(mx, args))
(mx::MATLAB.MxArray)(args...) = jvalue(mx(1, MATLAB.mxarray.(args))[1])

# --- stdout/stderr redirection --- #

function fwrite(fid, msg)
    call_matlab(0, "fwrite", convert(Float64, fid), msg, "char")
    return nothing
end

#TODO: MATLAB currently crashes if too much is printed at one time. Use better IO.

function readloop(stream, fid)
    try
        while isopen(stream)
            fwrite(fid, readavailable(stream))
        end
    finally
    end
end

# --- stdin --- #

input(prompt::String="julia> ") = call_matlab(1, "input", prompt, "s")[1]

# --- Calling Embedded Julia from MATLAB --- #

# entry point for mex function that calls Julia
const jl_mex_call_depth = Ref{Int}(0)
function jl_mex(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})

    # TODO: manually turn stdout and stderr redirection on/off?

    # # get stdout and stderr before changing them
    # stdout = Base.stdout
    # stderr = Base.stderr
    #
    # # redirect stdout and stderr to matlab terminal
    # mexstdout_rd, mexstdout_wr = redirect_stdout()
    # mexerrout_rd, mexerrout_wr = redirect_stderr()
    #
    # # start printing stdout and stderr to matlab console
    # t1 = @async readloop(mexstdout_rd, 1)
    # t2 = @async readloop(mexstderr_rd, 2)

    jl_mex_call_depth[] += 1
    try
        if jl_mex_call_depth[] == 1
            # call with interrupt handling
            jl_mex_outer(plhs, prhs)
        else
            # call without interrupt handling
            jl_mex_inner(plhs, prhs)
        end
    finally
        jl_mex_call_depth[] -= 1
    end

    # # stop printing stdout and stderr to matlab console
    # @async Base.throwto(t1, InterruptException())
    # @async Base.throwto(t2, InterruptException())
    #
    # # restore stdout and stderr
    # redirect_stdout(stdout)
    # redirect_stderr(stderr)

    # TODO: when called from the MATLAB engine, Julia will overwrite the last line
    # of terminal output. fix this.

end

# calls jl_mex_inner, after setting up interrupt handling
function jl_mex_outer(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})
    @sync begin
        # do the desired computation
        main_task = @async jl_mex_inner(plhs, prhs)

        # check for interrupt
        @async while(!istaskdone(main_task))
            if is_interrupt_pending()
                Base.throwto(main_task, InterruptException())
            end
            yield()
        end
    end
end

# runs julia function with mex function inputs, catching errors if they occur
function jl_mex_inner(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})

    # get number of outputs
    nlhs = length(plhs)

    # default output is boolean false
    none = MATLAB.mxarray(false);
    # transfer ownership to MATLAB
    none.own = false
    for i = 1:nlhs
        # give pointer to MATLAB
        plhs[i] = none.ptr
    end

    try

        # extract function and arguments (function in first slot, arguments in remaining slots)
        fun = Core.eval(Main, Meta.parse(MATLAB.jvalue(MATLAB.MxArray(prhs[1], false))))
        args = MATLAB.MxArray.(prhs[2:end], false)

        # call Julia function
        vals = fun(args)

        # convert outputs to MxArray type
        for i = 1:length(vals)
            # stop early if max number of outputs is reached
            if i > nlhs-1
                break
            end
            # create MATLAB array for output
            mx = MATLAB.mxarray(vals[i])
            # transfer ownership to MATLAB
            mx.own = false
            # give pointer to MATLAB
            plhs[1+i] = mx.ptr
        end

    catch exn

        # get backtrace
        bt = catch_backtrace()

        # create MATLABException from exception and backtrace
        mexn = MatlabException(exn, bt)

        # return MATLABexception in first output slot
        plhs[1] = mexn.ptr

    end

end

# --- Auxiliary Functions Used by MATLAB when calling embedded Julia --- #

# evaluate Julia expressions
jl_eval(exprs::Vector{MATLAB.MxArray}) = [Core.eval(Main, Meta.parse(MATLAB.jvalue(e))) for e in exprs]

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
function jl_call_kw(args::Vector{MATLAB.MxArray})

    # convert arguments to Julia objects
    vals = MATLAB.jvalue.(args)
    nvals = length(args)

    # first argument is the function
    func = Symbol(vals[1])

    # second argument is the number of positional arguments
    npos = vals[2]

    # if npos is negative, all arguments are positional
    if npos < 0
        npos = nvals - 2
    end

    # get number of keyword arguments
    nkw = div(nvals - 2 - npos, 2)

    # initialize arguments to julia expression
    expr_args = Array{Any, 1}(undef, npos+nkw)

    # add positional arguments
    for i = 1:npos
        expr_args[i] = vals[2+i]
    end

    # add keyword arguments
    for i = 1:nkw
        # assemble the key-value pair
        kw = Symbol(vals[2+npos+(2*i-1)])
        val = vals[2+npos+(2*i)]
        expr_args[npos+i] = Expr(:kw, kw, val)
    end

    # construct the expression
    expr = Expr(:call, func, expr_args...)

    # return the evaluated expression
    return [Core.eval(Main, expr)]
end

end # module

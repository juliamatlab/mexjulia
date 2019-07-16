# --- Calling Embedded Julia from MATLAB --- #

# entry point for MATLAB calling Julia
jl_mex(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}}) = jl_mex_inner(plhs, prhs)

# runs julia function with mex function inputs, catching errors if they occur
function jl_mex_inner(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})

    # get number of outputs
    nlhs = length(plhs)

    for i = 1:nlhs
        # default output is boolean false
        none = MATLAB.mxarray(false);
        # transfer ownership to MATLAB
        none.own = false
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

# --- Functions Used by MATLAB when calling embedded Julia --- #

# evaluates a Julia expressions
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

# used for mimicing a basic Julia repl from the MATLAB console
input(prompt::String="julia> ") = call_matlab(1, "input", prompt, "s")[1]

# -------------- #

# The functions below this point are for interrupt handling and stdout/stderr
# redirection.  These features have various issues that need to be resolved
# before being incorporated with the rest of the code.

# the following function was the original entry point for calling Julia
# from MATLAB which enables interrupt handling and stdout/stderr redirection

# const jl_mex_call_depth = Ref{Int}(0)
# function jl_mex(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})
#
#     # TODO: manually turn stdout and stderr redirection on/off?
#
#     # get stdout and stderr before changing them
#     stdout = Base.stdout
#     stderr = Base.stderr
#
#     # redirect stdout and stderr to matlab terminal
#     mexstdout_rd, mexstdout_wr = redirect_stdout()
#     mexerrout_rd, mexerrout_wr = redirect_stderr()
#
#     # start printing stdout and stderr to matlab console
#     t1 = @async readloop(mexstdout_rd, 1)
#     t2 = @async readloop(mexstderr_rd, 2)
#
#     jl_mex_call_depth[] += 1
#     try
#         if jl_mex_call_depth[] == 1
#             # call with interrupt handling
#             jl_mex_outer(plhs, prhs)
#         else
#             # call without interrupt handling
#             jl_mex_inner(plhs, prhs)
#         end
#     finally
#         jl_mex_call_depth[] -= 1
#     end
#
#     # stop printing stdout and stderr to matlab console
#     @async Base.throwto(t1, InterruptException())
#     @async Base.throwto(t2, InterruptException())
#
#     # restore stdout and stderr
#     redirect_stdout(stdout)
#     redirect_stderr(stderr)
#
#     # TODO: when called from the MATLAB engine, Julia will overwrite the last line
#     # of terminal output. fix this.
#
# end

# this function sets up interrupt handling before calling jl_mex_inner. The
# sync/async loop sometimes causes the output of the MEX function to become
# not be assigned (as least as far as MATLAB can tell).  This is likely due to
# the fact that MATLAB is not thread-safe.  Undocumented matlab references
# claim that the interrupt catching function is thread-safe, so the issue
# therefore likely lies with the use of @async on jl_mex_inner.  I ran into this
# issue while setting up callback functions, but have not taken the time to create
# a MWE which showcases the problem.

# function jl_mex_outer(plhs::Vector{Ptr{Cvoid}}, prhs::Vector{Ptr{Cvoid}})
#     @sync begin
#         # do the desired computation
#         main_task = @async jl_mex_inner(plhs, prhs)
#
#         # check for interrupt
#         @async while(!istaskdone(main_task))
#             if is_interrupt_pending()
#                 Base.throwto(main_task, InterruptException())
#             end
#             yield()
#         end
#     end
# end

# these function is used to poll MATLAB for interrupts, due to the issues
# described above, it is not used in the code

# is_interrupt_pending() = ccall(ut_is_interrupt_pending[], UInt8, ()) != 0
#
# function check_for_interrupt()
#     if is_interrupt_pending()
#         throw(InterruptException())
#     end
# end

# these functions are used for stdout/stderr redirection.  I found that if the
# code tries to print too much to the matlab console in a short period of time
# MATLAB will crash.  Therefore I removed them from the code.  Additionally,
# the redirection is unnecessary (and probably undesirable since it consumes
# some computational resources) if MATLAB is launched from the terminal

# function fwrite(fid, msg)
#     call_matlab(0, "fwrite", convert(Float64, fid), msg, "char")
#     return nothing
# end

# function readloop(stream, fid)
#     try
#         while isopen(stream)
#             fwrite(fid, readavailable(stream))
#         end
#     finally
#     end
# end

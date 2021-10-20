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
        fun = Core.eval(Main, Meta.parse(MATLAB.jstring(MATLAB.MxArray(prhs[1], false))))
        args = MATLAB.MxArray.(prhs[2:end], false)

        # call Julia function
        out = fun(args)

        out = (out isa Tuple ? out : (out,))::Tuple # wrap in tuple to simplify logic below

        # convert output(s) to MxArray type
        for i = 1:length(out)
            # stop early if max number of outputs is reached
            i > nlhs-1 && break
            # create MATLAB array for output
            mx = MATLAB.mxarray(out[i])
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
jl_eval(exprs::Vector{MATLAB.MxArray}) = ntuple(i -> Core.eval(Main, Meta.parse(MATLAB.jstring(exprs[i]))), length(exprs))

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

    # process arguments
    nargs = length(args)

    # first argument is the function
    func = Meta.parse(MATLAB.jstring(args[1]))

    # second argument is the number of positional arguments
    npos = Int(MATLAB.jscalar(args[2]))::Int

    # construct the call expression
    expr = Expr(:call, func)

    # add positional arguments
    npos = npos < 0 ? nargs - 2 : npos # if npos is negative, all arguments are positional
    for i = 1:npos
        push!(expr.args, MATLAB.jvalue(args[2+i]))
    end

    # add keyword arguments
    nkw = div(nargs - 2 - npos, 2)
    for i = 1:nkw
        # assemble the key-value pair
        kw = Symbol(MATLAB.jstring(args[2+npos+(2*i-1)]))
        val = MATLAB.jvalue(args[2+npos+(2*i)])
        push!(expr.args, Expr(:kw, kw, val))
    end

    # return the evaluated expression
    return Core.eval(Main, expr)
end

# used for mimicing a basic Julia repl from the MATLAB console
input(prompt::String="julia> ") = call_matlab(1, "input", prompt, "s")[1]

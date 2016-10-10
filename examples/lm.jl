using Optim

function mex_levenberg_marquardt(args::Vector{MxArray})

    # MxArray strings and function handles are callable. They take an argument of type
    # `Vector{MxArray}` and, optionally, a number of return values (defaulting to 1),
    # returning a value of type `Vector{MxArray}`.
    #
    # This `wrap` function takes an MxArray value, treating it as a callable, marshals
    # the argument to an MxArray, and the result to a Julia value.
    wrap(mx, x) = jvariable(mx(MxArray[mxarray(x)])[1])

    f = x -> wrap(args[1], x)
    jac = x -> wrap(args[2], x)
    x0 = jvariable(args[3])
    [Optim.levenberg_marquardt(f, jac, x0)]
end

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
(mx::MATLAB.MxArray)(args...) = MATLAB.jvalue(mx(1, MATLAB.mxarray.(args))[1])

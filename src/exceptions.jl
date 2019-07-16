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

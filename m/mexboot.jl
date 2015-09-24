# load user init script
haskey(ENV, "HOME") &&
isfile(ENV["HOME"]*"/.juliarc.jl") &&
include(ENV["HOME"]*"/.juliarc.jl");

using MATLAB
# would be great to redirect STD[IN|OUT|ERR]...

# helpers for mexFunction args
function mexargs(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  outs = pointer_to_array(convert(Ptr{Ptr{Void}}, plhs), nlhs, false)
  ins = pointer_to_array(convert(Ptr{Ptr{Void}}, prhs), nrhs, false)

  arys = Vector{MATLAB.MxArray}(nrhs)
  for i in 1:nrhs
    arys[i] = MATLAB.MxArray(ins[i], false)
  end

  (outs, arys)
end

function mex_show_error(e)
  buf = IOBuffer()
  showerror(buf, e)
  seek(buf, 0)
  mex_err_msg_txt(readall(buf))
end

# define a proper eval
function mexeval(nlhs::Int32, plhs::Ptr{Void}, nrhs::Int32, prhs::Ptr{Void})
  try
    (outs, arys) = mexargs(nlhs, plhs, nrhs, prhs)

    for i in 1:length(arys)
      v = eval(parse(jstring(arys[i])))

      # if there is a corresponding output, return the value
      if i <= nlhs
        mx = MATLAB.mxarray(v)
        mx.own = false
        outs[i] = mx.ptr
      end
    end
  catch e
    mex_show_error(e)
  end
end

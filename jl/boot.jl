Base.load_juliarc()

using MATLAB

const libmex = dlopen(MATLAB.matlab_library("libmex"), Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY)
mexfn(fun::Symbol) = dlsym(libmex::Ptr{Void}, fun)

function call_matlab(fn::ASCIIString, nout::Integer, args...)
  mxs = map(mxarray, args)
  ins = Ptr{Void}[mx.ptr for mx in mxs]
  nin = length(ins)

  outs = Vector{Ptr{Void}}(nout)

  @assert 0 == ccall(mexfn(:mexCallMATLAB), Int32,
    (Int32, Ptr{Ptr{Void}}, Int32, Ptr{Ptr{Void}}, Ptr{Uint8}),
     nout,  outs,           nin,   ins,            fn        )

  [jvariable(MxArray(o)) for o in outs]
end

mex_write(fid, bytes) = call_matlab("fwrite", 0, Float64(fid), bytes)

# redirect STDOUT, STDERR -- wish I knew how to do that!
#const pout = redirect_stdout()[1]
#const perr = redirect_stderr()[1]
# pout.readcb = p -> mex_write(1, readavailable(p))
# perr.readcb = p -> mex_write(2, readavailable(p))
# Base.start_reading(pout)
# Base.start_reading(perr)

function mex_args(ins)
  [ jvariable(MxArray(mx, false)) for mx in ins ]
end

function mex_return(outs, vs...)
  nouts = length(outs)
  @assert nouts == length(vs)
  for i in 1:nouts
    mx = mxarray(vs[i])
    mx.own = false
    outs[i] = mx.ptr
  end
end

function mex_showerror(e)
  buf = IOBuffer()
  showerror(buf, e)
  seek(buf, 0)
  ccall(mexfn(:mexErrMsgTxt), Void, (Ptr{Uint8},), readall(buf))
end

# a fancier eval
function mex_eval(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
  try
    @assert length(outs) == length(ins)
    mex_return(outs, [ eval(parse(e)) for e in mex_args(ins) ]...)
  catch e
    mex_showerror(e)
  end
end

# call an arbitrary julia function (or other callable)
function mex_call(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
  try
    @assert length(outs) == 1 && length(ins) >= 1
    args = mex_args(ins)
    mex_return(outs, eval(parse(args[1]))(args[2:end]...))
  catch e
    mex_showerror(e)
  end
end

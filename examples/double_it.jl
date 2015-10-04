function double_it(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
  try
    mex_return(outs, [ 2*v for v in mex_args(ins) ]...)
  catch e
    mex_showerror(e)
  end
end

module MxArrays

using Libdl, SparseArrays

export MxArray, mxarray, jvalue, matlab_homepath, matlab_library_path, open_matlab_library

import Base.eltype, Base.close, Base.size, Base.copy, Base.ndims, Base.convert

Base.include(MxArrays, "mxbase.jl")
Base.include(MxArrays, "mxarray.jl")

end

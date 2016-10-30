module MxArrays

export MxArray, matlab_homepath, matlab_library_path, open_matlab_library

import Base.eltype, Base.close, Base.size, Base.copy, Base.ndims, Base.convert

include("mxbase.jl")
include("mxarray.jl")

end

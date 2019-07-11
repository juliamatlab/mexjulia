# functions to deal with MATLAB arrays

const libmx = open_matlab_library("libmx")
mxfunc(s::Symbol) = Libdl.dlsym(libmx, s)

mutable struct MxArray
    ptr::Ptr{Cvoid}
    MxArray(p::Ptr{Cvoid}) = new(p)
end

# delete & duplicate

function delete(mx::MxArray)
    if !(mx.ptr == C_NULL)
        ccall(mxfunc(:mxDestroyArray), Cvoid, (Ptr{Cvoid},), mx.ptr)
    end
    mx.ptr = C_NULL
end

function copy(mx::MxArray)
    pm::Ptr{Cvoid} = ccall(mxfunc(:mxDuplicateArray), Ptr{Cvoid}, (Ptr{Cvoid},), mx.ptr)
    MxArray(pm)
end

# functions to create mxArray from Julia values/arrays

MxRealNum = Union{Float64,Float32,Int32,UInt32,Int64,UInt64,Int16,UInt16,Int8,UInt8,Bool}
MxComplexNum = Union{ComplexF32, ComplexF64}
MxNum = Union{MxRealNum, MxComplexNum}

###########################################################
#
#  MATLAB types
#
###########################################################

const mwSize = UInt
const mwIndex = Int
const mxChar = UInt16
const mxClassID = Cint
const mxComplexity = Cint

const mxUNKNOWN_CLASS  = convert(mxClassID, 0)
const mxCELL_CLASS     = convert(mxClassID, 1)
const mxSTRUCT_CLASS   = convert(mxClassID, 2)
const mxLOGICAL_CLASS  = convert(mxClassID, 3)
const mxCHAR_CLASS     = convert(mxClassID, 4)
const mxVOID_CLASS     = convert(mxClassID, 5)
const mxDOUBLE_CLASS   = convert(mxClassID, 6)
const mxSINGLE_CLASS   = convert(mxClassID, 7)
const mxINT8_CLASS     = convert(mxClassID, 8)
const mxUINT8_CLASS    = convert(mxClassID, 9)
const mxINT16_CLASS    = convert(mxClassID, 10)
const mxUINT16_CLASS   = convert(mxClassID, 11)
const mxINT32_CLASS    = convert(mxClassID, 12)
const mxUINT32_CLASS   = convert(mxClassID, 13)
const mxINT64_CLASS    = convert(mxClassID, 14)
const mxUINT64_CLASS   = convert(mxClassID, 15)
const mxFUNCTION_CLASS = convert(mxClassID, 16)
const mxOPAQUE_CLASS   = convert(mxClassID, 17)
const mxOBJECT_CLASS   = convert(mxClassID, 18)

const mxREAL    = convert(mxComplexity, 0)
const mxCOMPLEX = convert(mxComplexity, 1)

mxclassid(::Type{Bool})    = mxLOGICAL_CLASS::Cint
mxclassid(::Union{Type{Float64}, Type{ComplexF64}}) = mxDOUBLE_CLASS::Cint
mxclassid(::Union{Type{Float32}, Type{ComplexF32}}) = mxSINGLE_CLASS::Cint
mxclassid(::Type{Int8})    = mxINT8_CLASS::Cint
mxclassid(::Type{UInt8})   = mxUINT8_CLASS::Cint
mxclassid(::Type{Int16})   = mxINT16_CLASS::Cint
mxclassid(::Type{UInt16})  = mxUINT16_CLASS::Cint
mxclassid(::Type{Int32})   = mxINT32_CLASS::Cint
mxclassid(::Type{UInt32})  = mxUINT32_CLASS::Cint
mxclassid(::Type{Int64})   = mxINT64_CLASS::Cint
mxclassid(::Type{UInt64})  = mxUINT64_CLASS::Cint

mxcomplexflag(::Type{T}) where {T<:MxRealNum}   = mxREAL
mxcomplexflag(::Type{T}) where {T<:MxComplexNum} = mxCOMPLEX

const classid_type_map = Dict{mxClassID,Type}(
    mxLOGICAL_CLASS => Bool,
    mxCHAR_CLASS    => mxChar,
    mxDOUBLE_CLASS  => Float64,
    mxSINGLE_CLASS  => Float32,
    mxINT8_CLASS    => Int8,
    mxUINT8_CLASS   => UInt8,
    mxINT16_CLASS   => Int16,
    mxUINT16_CLASS  => UInt16,
    mxINT32_CLASS   => Int32,
    mxUINT32_CLASS  => UInt32,
    mxINT64_CLASS   => Int64,
    mxUINT64_CLASS  => UInt64
)

function mxclassid_to_type(cid::mxClassID)
    ty = get(classid_type_map::Dict{mxClassID, Type}, cid, nothing)
    if ty == nothing
        throw(ArgumentError("The input class id is not a primitive type id."))
    end
    ty
end


###########################################################
#
#  Functions to access mxArray
#
#  Part of the functions (e.g. mxGetNumberOfDimensions)
#  are actually a macro replacement of an internal
#  function name as (xxxx_730)
#
###########################################################

# pre-cached some useful functions

const _mx_free = mxfunc(:mxFree)

const _mx_get_classid = mxfunc(:mxGetClassID)
const _mx_get_m = mxfunc(:mxGetM)
const _mx_get_n = mxfunc(:mxGetN)
const _mx_get_nelems = mxfunc(:mxGetNumberOfElements)
const _mx_get_ndims  = mxfunc(:mxGetNumberOfDimensions_730)
const _mx_get_elemsize = mxfunc(:mxGetElementSize)
const _mx_get_data = mxfunc(:mxGetData)
const _mx_get_dims = mxfunc(:mxGetDimensions_730)
const _mx_get_nfields = mxfunc(:mxGetNumberOfFields)
const _mx_get_pr = mxfunc(:mxGetPr)
const _mx_get_pi = mxfunc(:mxGetPi)
const _mx_get_ir = mxfunc(:mxGetIr_730)
const _mx_get_jc = mxfunc(:mxGetJc_730)

const _mx_is_double = mxfunc(:mxIsDouble)
const _mx_is_single = mxfunc(:mxIsSingle)
const _mx_is_int64  = mxfunc(:mxIsInt64)
const _mx_is_uint64 = mxfunc(:mxIsUint64)
const _mx_is_int32  = mxfunc(:mxIsInt32)
const _mx_is_uint32 = mxfunc(:mxIsUint32)
const _mx_is_int16  = mxfunc(:mxIsInt16)
const _mx_is_uint16 = mxfunc(:mxIsUint16)
const _mx_is_int8   = mxfunc(:mxIsInt8)
const _mx_is_uint8  = mxfunc(:mxIsUint8)
const _mx_is_char   = mxfunc(:mxIsChar)

const _mx_is_numeric = mxfunc(:mxIsNumeric)
const _mx_is_logical = mxfunc(:mxIsLogical)
const _mx_is_complex = mxfunc(:mxIsComplex)
const _mx_is_sparse  = mxfunc(:mxIsSparse)
const _mx_is_empty   = mxfunc(:mxIsEmpty)
const _mx_is_struct  = mxfunc(:mxIsStruct)
const _mx_is_cell    = mxfunc(:mxIsCell)


# getting simple attributes

macro mx_get(name, fun, ret, cnv)
    :($(name)(mx::MxArray) = convert($(cnv), ccall($(fun)::Ptr{Cvoid}, $(ret), (Ptr{Cvoid},), mx.ptr)))
end
@mx_get(classid, _mx_get_classid, mxClassID, mxClassID)
@mx_get(nrows, _mx_get_m, UInt, Int)
@mx_get(ncols, _mx_get_n, UInt, Int)
@mx_get(nelems, _mx_get_nelems, UInt, Int)
@mx_get(ndims, _mx_get_ndims, mwSize, Int)
@mx_get(elsize, _mx_get_elemsize, UInt, Int)
@mx_get(nfields, _mx_get_nfields, Cint, Int)

eltype(mx::MxArray)  = mxclassid_to_type(classid(mx))
macro mx_get_ptr(name, fun)
    :($(name)(mx::MxArray) = convert(Ptr{eltype(mx)}, ccall($(fun)::Ptr{Cvoid}, Ptr{Cvoid}, (Ptr{Cvoid},), mx.ptr)))
end
@mx_get_ptr(data_ptr, _mx_get_data)
@mx_get_ptr(real_ptr, _mx_get_pr)
@mx_get_ptr(imag_ptr, _mx_get_pi)


# validation functions

macro mx_pred(name, fun)
    :($(name)(mx::MxArray) = ccall($(fun)::Ptr{Cvoid}, Bool, (Ptr{Cvoid},), mx.ptr))
end
@mx_pred(is_double, _mx_is_double)
@mx_pred(is_single, _mx_is_single)
@mx_pred(is_int64, _mx_is_int64)
@mx_pred(is_uint64, _mx_is_uint64)
@mx_pred(is_int32, _mx_is_int32)
@mx_pred(is_uint32, _mx_is_uint32)
@mx_pred(is_int16, _mx_is_int16)
@mx_pred(is_uint16, _mx_is_uint16)
@mx_pred(is_int8, _mx_is_int8)
@mx_pred(is_uint8, _mx_is_uint8)
@mx_pred(is_numeric, _mx_is_numeric)
@mx_pred(is_logical, _mx_is_logical)
@mx_pred(is_complex, _mx_is_complex)
@mx_pred(is_sparse, _mx_is_sparse)
@mx_pred(is_struct, _mx_is_struct)
@mx_pred(is_cell, _mx_is_cell)
@mx_pred(is_char, _mx_is_char)
@mx_pred(is_empty, _mx_is_empty)


# size function

function size(mx::MxArray)
    nd = ndims(mx)
    pdims = ccall(_mx_get_dims, Ptr{mwSize}, (Ptr{Cvoid},), mx.ptr)
    _dims = unsafe_wrap(Array, pdims, (nd,))
    dims = Array(Int, nd)
    for i = 1 : nd
        dims[i] = convert(Int, _dims[i])
    end
    tuple(dims...)
end

function size(mx::MxArray, d::Integer)
    nd = ndims(mx)
    if d <= 0
        throw(ArgumentError("The dimension must be a positive integer."))
    end

    if nd == 2
        d == 1 ? nrows(mx) :
        d == 2 ? ncols(mx) : 1
    else
        pdims = ccall(_mx_get_dims, Ptr{mwSize}, (Ptr{Cvoid},), mx.ptr)
        _dims = unsafe_wrap(Array, pdims, (nd,))
        d <= nd ? convert(Int, _dims[d]) : 1
    end
end



###########################################################
#
#  functions to create & delete MATLAB arrays
#
###########################################################

# pre-cached functions

const _mx_create_numeric_mat = mxfunc(:mxCreateNumericMatrix_730)
const _mx_create_numeric_arr = mxfunc(:mxCreateNumericArray_730)

const _mx_create_double_scalar = mxfunc(:mxCreateDoubleScalar)
const _mx_create_logical_scalar = mxfunc(:mxCreateLogicalScalar)

const _mx_create_sparse = mxfunc(:mxCreateSparse_730)
const _mx_create_sparse_logical = mxfunc(:mxCreateSparseLogicalMatrix_730)

const _mx_create_char_array = mxfunc(:mxCreateCharArray_730)

const _mx_create_cell_array = mxfunc(:mxCreateCellArray_730)

const _mx_create_struct_matrix = mxfunc(:mxCreateStructMatrix_730)
const _mx_create_struct_array = mxfunc(:mxCreateStructArray_730)

const _mx_get_cell = mxfunc(:mxGetCell_730)
const _mx_set_cell = mxfunc(:mxSetCell_730)

const _mx_get_field = mxfunc(:mxGetField_730)
const _mx_set_field = mxfunc(:mxSetField_730)
const _mx_get_field_bynum = mxfunc(:mxGetFieldByNumber_730)
const _mx_get_fieldname = mxfunc(:mxGetFieldNameByNumber)

# create zero arrays

mxempty() = MxArray(Float64, 0, 0)

function _dims_to_mwSize(dims::Tuple{Vararg{Int}})
    ndim = length(dims)
    _dims = Array{mwSize}(undef, ndim)
    for i = 1 : ndim
        _dims[i] = convert(mwSize, dims[i])
    end
    _dims
end

function MxArray(ty::Type{T}, dims::Tuple{Vararg{Int}}) where {T<:MxNum}
    pm = ccall(_mx_create_numeric_arr, Ptr{Cvoid},
        (mwSize, Ptr{mwSize}, mxClassID, mxComplexity),
        length(dims), _dims_to_mwSize(dims), mxclassid(ty), mxcomplexflag(ty))

    MxArray(pm)
end
MxArray(ty::Type{T}, dims::Int...) where {T<:MxNum} = MxArray(ty, dims)

# create scalars

function MxArray(x::Float64)
    pm = ccall(_mx_create_double_scalar, Ptr{Cvoid}, (Cdouble,), x)
    MxArray(pm)
end

function MxArray(x::Bool)
    pm = ccall(_mx_create_logical_scalar, Ptr{Cvoid}, (Bool,), x)
    MxArray(pm)
end

function MxArray(x::T) where {T<:MxRealNum}
    pm = ccall(_mx_create_numeric_mat, Ptr{Cvoid},
        (mwSize, mwSize, mxClassID, mxComplexity),
        1, 1, mxclassid(T), mxcomplexflag(T))

    pdat = ccall(_mx_get_data, Ptr{T}, (Ptr{Cvoid},), pm)

    unsafe_wrap(Array, pdat, (1,))[1] = x
    MxArray(pm)
end
MxArray(x::T) where {T<:MxComplexNum} = MxArray([x])

# conversion from Julia variables to MATLAB
# Note: the conversion is deep-copy, as there is no way to let
# mxArray use Julia array's memory

function MxArray(a::Array{T}) where {T<:MxRealNum}
    mx = MxArray(T, size(a))
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt),
        data_ptr(mx), a, length(a) * sizeof(T))
    mx
end

function MxArray(a::Array{T}) where {T<:MxComplexNum}
    mx = MxArray(T, size(a))
    na = length(a)
    rdat = unsafe_wrap(Array, real_ptr(mx), na)
    idat = unsafe_wrap(Array, imag_ptr(mx), na)
    for i = 1:na
        rdat[i] = real(a[i])
        idat[i] = imag(a[i])
    end
    mx
end

MxArray(a::BitArray) = MxArray(convert(Array{Bool}, a))
MxArray(a::AbstractRange) = MxArray([a;])

# sparse matrix

function mxsparse(ty::Type{Float64}, m::Integer, n::Integer, nzmax::Integer)
    pm = ccall(_mx_create_sparse, Ptr{Cvoid},
        (mwSize, mwSize, mwSize, mxComplexity), m, n, nzmax, mxREAL)
    MxArray(pm)
end

function mxsparse(ty::Type{Bool}, m::Integer, n::Integer, nzmax::Integer)
    pm = ccall(_mx_create_sparse_logical, Ptr{Cvoid},
        (mwSize, mwSize, mwSize), m, n, nzmax)
    MxArray(pm)
end

function _copy_sparse_mat(a::SparseMatrixCSC{V,I},
    ir_p::Ptr{mwIndex}, jc_p::Ptr{mwIndex}, pr_p::Ptr{V}) where {V,I}

    colptr::Vector{I} = a.colptr
    rinds::Vector{I} = a.rowval
    v::Vector{V} = a.nzval
    n::Int = a.n
    nnz::Int = length(v)

    # Note: ir and jc contain zero-based indices

    ir = unsafe_wrap(Array, ir_p, (nnz,))
    for i = 1 : nnz
        ir[i] = rinds[i] - 1
    end

    jc = unsafe_wrap(Array, jc_p, (n+1,))
    for i = 1 : n+1
        jc[i] = colptr[i] - 1
    end

    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt), pr_p, v, nnz * sizeof(V))
end

function MxArray(a::SparseMatrixCSC{V,I}) where {V<:Union{Float64,Bool},I}
    m::Int = a.m
    n::Int = a.n
    nnz = length(a.nzval)
    @assert nnz == a.colptr[n+1]-1

    mx = mxsparse(V, m, n, nnz)

    ir_p = ccall(_mx_get_ir, Ptr{mwIndex}, (Ptr{Cvoid},), mx.ptr)
    jc_p = ccall(_mx_get_jc, Ptr{mwIndex}, (Ptr{Cvoid},), mx.ptr)
    pr_p = ccall(_mx_get_pr, Ptr{V}, (Ptr{Cvoid},), mx.ptr)

    _copy_sparse_mat(a, ir_p, jc_p, pr_p)
    mx
end


# char arrays and string

function MxArray(s::String)
    wchars = transcode(UInt16, s)
    len = length(wchars)
    pm = ccall(_mx_create_char_array, Ptr{Cvoid}, (mwSize, Ptr{mwSize}), 2, [1, len])
    mx = MxArray(pm)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt),
        data_ptr(mx), wchars, len * sizeof(mxChar))
    mx
end

# cell arrays

function mxcellarray(dims::Tuple{Vararg{Int}})
    pm = ccall(_mx_create_cell_array, Ptr{Cvoid}, (mwSize, Ptr{mwSize}),
        length(dims), _dims_to_mwSize(dims))
    MxArray(pm)
end
mxcellarray(dims::Int...) = mxcellarray(dims)

function get_cell(mx::MxArray, i::Integer)
    pm = ccall(_mx_get_cell, Ptr{Cvoid}, (Ptr{Cvoid}, mwIndex), mx.ptr, i-1)
    MxArray(pm)
end

function set_cell(mx::MxArray, i::Integer, v::MxArray)
    ccall(_mx_set_cell, Cvoid, (Ptr{Cvoid}, mwIndex, Ptr{Cvoid}),
        mx.ptr, i - 1, v.ptr)
end

function mxcellarray(a::Array)
    pm = mxcellarray(size(a))
    for i = 1 : length(a)
        set_cell(pm, i, MxArray(a[i]))
    end
    pm
end

MxArray(a::Array) = mxcellarray(a)

# struct arrays

function _fieldname_array(fieldnames::String...)
    n = length(fieldnames)
    a = Array{Ptr{UInt8}}(undef, n)
    for i = 1 : n
        a[i] = Base.unsafe_convert(Ptr{UInt8}, fieldnames[i])
    end
    a
end

function mxstruct(fns::Vector{String})
    a = _fieldname_array(fns...)
    pm = ccall(_mx_create_struct_matrix, Ptr{Cvoid},
        (mwSize, mwSize, Cint, Ptr{Ptr{UInt8}}),
        1, 1, length(a), a)
    MxArray(pm)
end

function mxstruct(fn1::String, fnr::String...)
    a = _fieldname_array(fn1, fnr...)
    pm = ccall(_mx_create_struct_matrix, Ptr{Cvoid},
        (mwSize, mwSize, Cint, Ptr{Ptr{UInt8}}),
        1, 1, length(a), a)
    MxArray(pm)
end

function set_field(mx::MxArray, i::Integer, f::String, v::MxArray)
    ccall(_mx_set_field, Cvoid,
        (Ptr{Cvoid}, mwIndex, Ptr{UInt8}, Ptr{Cvoid}),
        mx.ptr, i-1, f, v.ptr)
end

set_field(mx::MxArray, f::String, v::MxArray) = set_field(mx, 1, f, v)

function get_field(mx::MxArray, i::Integer, f::String)
    pm = ccall(_mx_get_field, Ptr{Cvoid}, (Ptr{Cvoid}, mwIndex, Ptr{UInt8}),
        mx.ptr, i-1, f)
    if pm == C_NULL
        throw(ArgumentError("Failed to get field."))
    end
    MxArray(pm)
end

get_field(mx::MxArray, f::String) = get_field(mx, 1, f)

function get_field(mx::MxArray, i::Integer, fn::Integer)
    pm = ccall(_mx_get_field_bynum, Ptr{Cvoid}, (Ptr{Cvoid}, mwIndex, Cint),
        mx.ptr, i-1, fn-1)
    if pm == C_NULL
        throw(ArgumentError("Failed to get field."))
    end
    MxArray(pm)
end

get_field(mx::MxArray, fn::Integer) = get_field(mx, 1, fn)


function get_fieldname(mx::MxArray, i::Integer)
    p = ccall(_mx_get_fieldname, Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        mx.ptr, i-1)
    unsafe_string(p)
end

if VERSION >= v"0.4.0-dev+980"
    const Pairs = Union{Pair,NTuple{2}}
else
    const Pairs = NTuple{2}
end

function mxstruct(pairs::Pairs...)
    nf = length(pairs)
    fieldnames = Array{String}(undef, nf)
    for i = 1 : nf
        fn = pairs[i][1]
        fieldnames[i] = string(fn)
    end
    mx = mxstruct(fieldnames)
    for i = 1 : nf
        set_field(mx, fieldnames[i], MxArray(pairs[i][2]))
    end
    mx
end

function mxstruct(d::T) where {T}
    names = fieldnames(T)
    names_str = map(string, names)
    mx = mxstruct(names_str...)
    for i = 1:length(names)
        set_field(mx, names_str[i], MxArray(getfield(d, names[i])))
    end
    mx
end

function mxstructarray(d::Array{T}) where {T}
    names = fieldnames(T)
    names_str = map(string, names)
    a = _fieldname_array(names_str...)

    pm = ccall(_mx_create_struct_array, Ptr{Cvoid}, (mwSize, Ptr{mwSize}, Cint,
        Ptr{Ptr{UInt8}}), ndims(d), _dims_to_mwSize(size(d)), length(a), a)
    mx = MxArray(pm)

    for i = 1:length(d), j = 1:length(names)
        set_field(mx, i, names_str[j],
            MxArray(getfield(d[i], names[j])))
    end
    mx
end

mxstruct(d::AbstractDict) = mxstruct(collect(d)...)
MxArray(d) = mxstruct(d)


###########################################################
#
#  convert from MATLAB to Julia
#
###########################################################

# use deep-copy from MATLAB variable to Julia array
# in practice, MATLAB variable often has shorter life-cycle

function _jarrayx(fun::String, mx::MxArray, siz::Tuple)
    if is_numeric(mx) || is_logical(mx)
        @assert !is_sparse(mx)
        T = eltype(mx)
        if is_complex(mx)
            rdat = unsafe_wrap(Array, real_ptr(mx), siz)
            idat = unsafe_wrap(Array, imag_ptr(mx), siz)
            a = complex(rdat, idat)
        else
            a = Array(T, siz)
            if !isempty(a)
                ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt),
                    a, data_ptr(mx), sizeof(T) * length(a))
            end
        end
        a
        #unsafe_wrap(Array, data_ptr(mx), siz)
    elseif is_cell(mx)
        a = Array(Any, siz)
        for i = 1 : length(a)
            a[i] = Any(get_cell(mx, i))
        end
        a
    else
        throw(ArgumentError("$(fun) only applies to numeric, logical or cell arrays."))
    end
end

jarray(mx::MxArray) = _jarrayx("jarray", mx, size(mx))
jvector(mx::MxArray) = _jarrayx("jvector", mx, (nelems(mx),))

function jmatrix(mx::MxArray)
    if ndims(mx) != 2
        throw(ArgumentError("jmatrix only applies to MATLAB arrays with ndims == 2."))
    end
    _jarrayx("jmatrix", mx, (nrows(mx), ncols(mx)))
end

function jscalar(mx::MxArray)
    if !(nelems(mx) == 1 && (is_logical(mx) || is_numeric(mx)))
        throw(ArgumentError("jscalar only applies to numeric or logical arrays with exactly one element."))
    end
    @assert !is_sparse(mx)
    if is_complex(mx)
        unsafe_wrap(Array, real_ptr(mx), (1,), own=false)[1] + im*unsafe_wrap(Array, imag_ptr(mx), (1,))[1]
    else
        unsafe_wrap(Array, data_ptr(mx), (1,))[1]
    end
end

function _jsparse(ty::Type{T}, mx::MxArray) where {T<:MxRealNum}
    m = nrows(mx)
    n = ncols(mx)
    ir_ptr = ccall(_mx_get_ir, Ptr{mwIndex}, (Ptr{Cvoid},), mx.ptr)
    jc_ptr = ccall(_mx_get_jc, Ptr{mwIndex}, (Ptr{Cvoid},), mx.ptr)
    pr_ptr = ccall(_mx_get_pr, Ptr{T}, (Ptr{Cvoid},), mx.ptr)

    jc_a::Vector{mwIndex} = unsafe_wrap(Array, jc_ptr, (n+1,))
    nnz = jc_a[n+1]

    ir = Array(Int, nnz)
    jc = Array(Int, n+1)

    ir_x = unsafe_wrap(Array, ir_ptr, (nnz,))
    for i = 1 : nnz
        ir[i] = ir_x[i] + 1
    end

    jc_x = unsafe_wrap(Array, jc_ptr, (n+1,))
    for i = 1 : n+1
        jc[i] = jc_x[i] + 1
    end

    pr::Vector{T} = copy(unsafe_wrap(Array, pr_ptr, (nnz,)))
    SparseMatrixCSC(m, n, jc, ir, pr)
end


function jsparse(mx::MxArray)
    if !is_sparse(mx)
        throw(ArgumentError("jsparse only applies to sparse matrices."))
    end
    _jsparse(eltype(mx), mx)
end


function String(mx::MxArray)
    if !(classid(mx) == mxCHAR_CLASS && ((ndims(mx) == 2 && nrows(mx) == 1) || is_empty(mx)))
        throw(ArgumentError("String only applies to char row vectors."))
    end
    transcode(String, unsafe_wrap(Array, Ptr{mxChar}(data_ptr(mx)), ncols(mx), own=false))
end

function Dict(mx::MxArray)
    if !(is_struct(mx) && nelems(mx) == 1)
        throw(ArgumentError("jdict only applies to a single struct."))
    end
    nf = nfields(mx)
    fnames = Array{String}(undef, nf)
    fvals = Array{Any}(undef, nf)
    for i = 1 : nf
        fnames[i] = get_fieldname(mx, i)
        pv::Ptr{Cvoid} = ccall(_mx_get_field_bynum,
            Ptr{Cvoid}, (Ptr{Cvoid}, mwIndex, Cint),
            mx.ptr, 0, i-1)
        fx = MxArray(pv)
        fvals[i] = Any(fx)
    end
    Dict(zip(fnames, fvals))
end

function Function(mx::MxArray)
    if classid(mx) != mxFUNCTION_CLASS || nelems(mx) != 1
        throw(ArgumentError("Function only applies to a single function handle."))
    end
    (args...) -> mx(args...)
end

function jvalue(mx::MxArray)
    if is_numeric(mx) || is_logical(mx)
        if !is_sparse(mx)
            nelems(mx) == 1 ? jscalar(mx) :
            ndims(mx) == 2 ? (ncols(mx) == 1 ? jvector(mx) : jmatrix(mx)) :
            jarray(mx)
        else
            jsparse(mx)
        end
    elseif is_char(mx) && (nrows(mx) == 1 || is_empty(mx))
        String(mx)
    elseif is_cell(mx)
        ndims(mx) == 2 ? (ncols(mx) == 1 ? jvector(mx) : jmatrix(mx)) :
        jarray(mx)
    elseif is_struct(mx) && nelems(mx) == 1
        Dict(mx)
    elseif classid(mx) == mxFUNCTION_CLASS && nelems(mx) == 1
        Function(mx)
    else
        mx
    end
end

# deep conversion from MATLAB variable to Julia array

# convert(::Type{Array}, mx::MxArray)  = jarray(mx)
# convert(::Type{Vector}, mx::MxArray) = jvector(mx)
# convert(::Type{Matrix}, mx::MxArray) = jmatrix(mx)
# convert(::Type{Number}, mx::MxArray) = jscalar(mx)::Number
# convert(::Type{String}, mx::MxArray) = String(mx)::String
# convert(::Type{Dict}, mx::MxArray) = jdict(mx)
# convert(::Type{SparseMatrixCSC}, mx::MxArray) = jsparse(mx)

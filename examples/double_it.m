% An example of a custom mex-like Julia Function

% Define a mex-like julia function. A mex-like julia function accepts a
% vector of MxArrays as its single input and returns an iterable
% collection of values, each of which can be converted to an `MxArray`.
Jl.eval('double_it(args::Vector{MxArray}) = [2*jvalue(arg) for arg in args]');

% Generate some data.
a = rand(5, 5)

% Call our function.
jl.mex('double_it', a)

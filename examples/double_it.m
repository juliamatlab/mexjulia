% An example of a custom mex-like Julia Function

% include the function definition
Jl.include('double_it.jl');

% call it
a = rand(5, 5)
Jl.mex('double_it', a)

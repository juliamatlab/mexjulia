function value = jlget(key)
%JGET Get a value stored in the mexjulia dictionary.
%   Given a key, returns the value associated with it that is stored in the
%   mexjulia dictionary, or the empty string, if not found.
%   With no argument, the contents of the dictionary are printed.

if nargin < 1
  value = jl.get;
else
  value = jl.get(key);
end

end


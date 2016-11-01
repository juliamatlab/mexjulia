function jlset(key, value)
%JLSET Sets a key-value pair in the mexjulia dictionary.
%    KEY and VALUE must both be strings. If VALUE is not given, the 
%    corresponding KEY is removed from the dictionary. If no arguments
%    are given, the contents of the dictionary are displayed.

if nargin == 0
  disp(jl.get);
elseif nargin == 1
  jl.set(key);
else
  jl.set(key, value)
end

end


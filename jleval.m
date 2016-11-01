function [varargout] = jleval(expr)
% JLEVAL Evaluate a Julia expression as a string.

value = jl.eval(expr);
if ~(isstruct(value) && isempty(fields(value)))
  varargout{1} = value;
end
end


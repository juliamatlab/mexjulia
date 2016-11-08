function [varargout] = jleval(varargin)
% JLEVAL Evaluate a Julia expression as a string.

expr = strjoin(varargin, ' ');
value = jl.eval(expr);
if ~(isstruct(value) && isempty(fields(value)))
  varargout{1} = value;
end
end


function exception_tests()

% a julia exception passed back to matlab
try
  jl.call('this_does_not_exist', 42)
catch e
  disp(getReport(e))
end

% an example of a matlab exception caught in Julia and passed back to 
% matlab (with the Julia backtrace appended)
try
  jl.call('call', @(x) exn_thrower(x), 42)
catch e
  disp(getReport(e));
end

end



function y = exn_thrower(x)

y = x;

error('I take exception to everything.');

end


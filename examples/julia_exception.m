% An example of a Julia exception passed back to MATLAB
function julia_exception_test()

try
    jl.call('this_function_does_not_exist')
catch e
    disp(getReport(e))
end

end
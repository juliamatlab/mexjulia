function runtests

test simple_eval jleval 1+1

end

function test(name, varargin)
    expr = strjoin(varargin, ' ');
    try
        if eval(expr)
            fprintf('Test %s passed.\n', name);
        else
            fprintf('Test %s failed:\n', name);
            fprintf('\t%s', expr);
        end
    catch exn
        fprintf('Test %s threw exception:\n', name);
        disp(exn.getReport);
    end
end

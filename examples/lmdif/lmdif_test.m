function sln = lmdif_test(n)

    if nargin < 1
      n = 100;
    end
    
    % an example using handles to anonymous functions
    kappa = 100;
    f = @(x) rosenbrock(x, kappa);
    x0 = rand(n,1);
    sln = lmdif(f, x0);
end

function resid = rosenbrock(x, kappa)
    resid = [ 1-x ; kappa.*diff(x) ];
end

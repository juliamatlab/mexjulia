function sln = lm_test(n)
    % an example using handles to anonymous functions
    kappa = 10;
    f = @(x) rosenbrock(x, kappa);
    jac = @(x) rosenbrock_jacobian(x, kappa);
    x0 = rand(n,1);
    sln = lm(f, jac, x0);
end

function resid = rosenbrock(x, kappa)
    resid = [ 1-x ; kappa.*diff(x) ];
end

function jac = rosenbrock_jacobian(x, kappa)
    n = length(x);
    jac = [ -eye(n) ; -kappa*eye(n-1, n) ];
    for k = 1:n-1
        jac(k+n,k+1) = kappa;
    end
end

![mexjulia.icon](doc/logo.png)

# `mexjulia`: embedding [Julia](http://julialang.org/) in the [MATLAB](http://www.mathworks.com/products/matlab/) process.

## Prerequisites

`mexjulia` requires MATLAB (>=R2008a) and Julia (>=v.0.5) along with a C++ compiler configured to work with MATLAB's `mex` command, the last is required for building the `mexjulia` MEX function. You can check that a compiler is properly configured by executing:

```
>> mex -setup C++
```

from the MATLAB command prompt.

## Configuration

Start MATLAB and navigate to the `mexjulia` directory. Once there, run:

```
>> Jl.build
```

You will be prompted to select a `julia` executable. The build process will:
 1. guess the path to the `julia-config.jl` script,
 1. use `julia-config.jl` to determine build options,
 1. build the `mexjulia` MEX function from source,
 1. check that the [`MATLAB.jl`](https://github.com/JuliaInterop/MATLAB.jl) package is installed,
 1. add the `mexjulia` directory to your MATLAB path.

Call `Jl.build` any time you want to build against a different version of Julia. You can
pass in the path to the desired Julia executable to build against if you don't want
to be prompted to select one.

## Quick start

Use `Jl.eval` to parse and evaluate MATLAB strings as Julia expressions:

```
>> Jl.eval('2+2')

ans =

                    4
```

You can evaluate multiple expressions in a single call:

```
>> [s, c] = Jl.eval('sin(pi/3)', 'cos(pi/3)')

s =

    0.8660


c =

    0.5000
```

Julia's `STDOUT` and `STDERR` are redirected to the MATLAB console:

```
>> Jl.eval('println("Hello, world!")');
Hello, world!
>> Jl.eval('warn("Oh, no!")');
WARNING: Oh, no!
```

Use `Jl.call` to call a Julia function specified by its name as a string:

```
>> Jl.call('factorial', 10)

ans =

     3628800
```

`Jl.call` marshals MATLAB data to/from Julia by invoking `MATLAB.jl`'s `jvariable` function on each of the inputs and `mxarray` on its return value.

Load new Julia code by calling `Jl.include`:

```
>> Jl.include('my_own_julia_code.jl')
```

Exercise more control over how data is marshaled between MATLAB and Julia by defining
a Julia function with a "MEX-like" signature and invoking it with `Jl.mex`:

```
>> Jl.eval('double_it(args::Vector{MxArray}) = [2*jvariable(arg) for arg in args]');
>> a = rand(5, 5)

a =

    0.8687    0.4314    0.1361    0.8530    0.0760
    0.0844    0.9106    0.8693    0.6221    0.2399
    0.3998    0.1818    0.5797    0.3510    0.1233
    0.2599    0.2638    0.5499    0.5132    0.1839
    0.8001    0.1455    0.1450    0.4018    0.2400

>> Jl.mex(1, 'double_it', a)

ans =

    1.7374    0.8628    0.2721    1.7061    0.1519
    0.1689    1.8213    1.7386    1.2441    0.4798
    0.7996    0.3637    1.1594    0.7019    0.2466
    0.5197    0.5276    1.0997    1.0265    0.3678
    1.6001    0.2911    0.2899    0.8036    0.4799
```

The first argument to `Jl.mex` is the number of return values to expect. The second is the name of the function to be invoked. All remaining arguments are treated as function arguments. `Jl.mex` expects the functions on which it is invoked to accept a single argument of type `Vector{MxArray}` and to return an iterable collection of values on which `mxarray` may be successfully invoked (_e.g._, a value of type `Vector{MxArray}`).

See [`lm_test.m`](examples/lm_test.m), [`lm.m`](examples/lm.m), and [`lm.jl`](examples/lm.jl) for a more complex example that exposes [`Optim.jl`](https://github.com/JuliaOpt/Optim.jl)'s Levenberg-Marquardt solver to MATLAB. In it, callbacks are captured as `MxArray`s containing MATLAB function handles.

## Caveats

The input arguments passed in to `mexjulia` from MATLAB must not be modified on the Julia side. If it happens, expect MATLAB to crash. This is a requirement of the MEX interface, and is not specific to `mexjulia`.

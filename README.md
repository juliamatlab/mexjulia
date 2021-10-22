# Mex.jl

*Embedding [Julia](http://julialang.org/) in the [MATLAB](http://www.mathworks.com/products/matlab/) process*

**Mex.jl** embeds Julia into the MATLAB process using MATLAB's [C++ Mex interface](https://www.mathworks.com/help/matlab/cpp-mex-file-applications.html).  This allows Julia functions to be called from MATLAB.  This also allows (embedded) Julia to call MATLAB functions.  

## Prerequisites

`Mex.jl` requires MATLAB and Julia along with a C++ compiler configured to work with MATLAB's `mex` command, the last is required for building the `mexjulia` MEX function. You can check that a compiler is properly configured by executing:

```
>> mex -setup C++
```

from the MATLAB command prompt.

## Installation

First ensure that the [MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) Julia package is properly installed.  This package makes use of the MxArrays type defined in that package and also uses it for this packages initial configuration step.

Then simply add this package in Julia using the following command:
```
]add https://github.com/byuflowlab/Mex.jl
```

The build process will:
 1. use `julia` to determine build options,
 1. build the `mexjulia` MEX function from source,
 1. add the `mexjulia` directory to your MATLAB path.

## Quick start

Use `jl.eval` to parse and evaluate MATLAB strings as Julia expressions:

```
>> jl.eval('2+2')

ans =

  int64

   4
```

You can evaluate multiple expressions in a single call:

```
>> [s, c] = jl.eval('sin(pi/3), cos(pi/3)')

s =

    0.8660


c =

    0.5000
```

Note that Julia's `STDOUT` and `STDERR` are not redirected to the MATLAB console.  But if MATLAB is launched from the terminal they will appear there.

```
>> jl.eval('println("Hello, world!")');
>> jl.eval('@warn("Oh, no!")');
```

One can avoid the parentheses and string quotes using `jleval` (a simple wrapper around
`jl.eval`) and MATLAB's command syntax:

```
>> jleval 1 + 1

ans =

  int64

   2

>> jleval println("Hello, world!")
Hello, world!
```

Use `jl.call` to call a Julia function specified by its name as a string:

```
>> jl.call('factorial', int64(10))

ans =

     3628800
```

Load new Julia code by calling `jl.include`:

```
>> jl.include('my_own_julia_code.jl')
```

Exercise more control over how data is marshaled between MATLAB and Julia by defining
a Julia function with a "MEX-like" signature and invoking it with `jl.mex`:

```
>> jleval import MATLAB
>> jleval double_it(args::Vector{MATLAB.MxArray}) = [2*MATLAB.jvalue(arg) for arg in args]
>> a = rand(5,5)

a =

    0.6443    0.9390    0.2077    0.1948    0.3111
    0.3786    0.8759    0.3012    0.2259    0.9234
    0.8116    0.5502    0.4709    0.1707    0.4302
    0.5328    0.6225    0.2305    0.2277    0.1848
    0.3507    0.5870    0.8443    0.4357    0.9049

>> jl.mex('double_it', a)

ans =

    1.2886    1.8780    0.4155    0.3895    0.6222
    0.7572    1.7519    0.6025    0.4518    1.8468
    1.6232    1.1003    0.9418    0.3414    0.8604
    1.0657    1.2450    0.4610    0.4553    0.3696
    0.7015    1.1741    1.6886    0.8714    1.8098
```

The first argument to `jl.mex` is the name of the function to be invoked. All remaining arguments are treated as function arguments. 

`jl.mex` expects the functions on which it is invoked to accept a single argument of type `Vector{MATLAB.MxArray}` and to return an iterable collection of values on which `MATLAB.mxarray` may be successfully invoked (_e.g._, a value of type `Vector{MATLAB.MxArray}`).
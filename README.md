# jlcall: Call Julia from MATLAB.

`jlcall` is a [MATLAB](http://www.mathworks.com/products/matlab/) [MEX](http://www.mathworks.com/help/matlab/matlab_external/introducing-mex-files.html) function that embeds [Julia](http://julialang.org/) in MATLAB.

## Why `jlcall`?

MATLAB is a venerable tool for technical computing with a well-polished interface, a large number of useful toolboxes, and a significant user base who have established efficient workflows around it. However, MATLAB's language has limitations that lead users to turn to writing MEX extensions in FORTRAN, C or C++ when efficient implementations are infeasible in MATLAB itself.

Julia is a relatively new language for technical computing. Its designers have striven to bring together into one place the most important positive attributes of a variety of languages that one might find being used in today's scientific computing projects, including: a familiar, unintrusive syntax and a large toolbox of scientific software, like MATLAB; convenient system-level "glue" capabilities, like Python; the possibility of achieving excellent runtime performance, like FORTRAN or C. Julia's present is already formidable, and its future is even brighter, but it still lacks an interface as clean and feature-rich as MATLAB's.

The purpose of `jlcall` is to bring MATLAB and Julia together in a way that mitigates the weaknesses of each by exploiting the strengths of the other, benefiting the users of each. `jlcall` lets MATLAB users extend MATLAB's functionality through the MEX interface with a language capable of achieving performance comparable to FORTRAN or C, but in a way that should make them feel more at home. Julia users benefit by being able to use MATLAB's polished front-end, as well as having a means to collaborate seamlessly with colleagues who work primarily in MATLAB.

`jlcall` is not the only way to bridge MATLAB and Julia. [`MATLAB.jl`](https://github.com/JuliaLang/MATLAB.jl) is a Julia package that enables calling MATLAB from Julia through the [MATLAB Engine](http://www.mathworks.com/help/matlab/matlab_external/introducing-matlab-engine.html) interface. Indeed, `jlcall` itself takes advantage of the data marshaling functionality provided in `MATLAB.jl`. However, `MATLAB.jl` itself does not provide a means for MATLAB to call into Julia. `jlcall` complements `MATLAB.jl` in this manner.

Nor is `jlcall` the first attempt to facilitate calling Julia from MATLAB. For instance,  [`julia-matlab`](https://github.com/timholy/julia-matlab) provides a means for calling Julia from MATLAB through a [ZeroMQ](http://zeromq.org/) connection and a clever data codec. For `julia-matlab` the communication is inter-process. As such, all data passed between the two involves copying. In contrast, with `jlcall`, MATLAB and Julia coexist in the same process, sharing a common address space. In this case, one can avoid data copying in certain cases when crossing the language border. The time and space savings can be significant when working with large chunks of memory, as is frequently done in technical computing.

## Getting started with `jlcall`

### Prerequisites

It goes without saying that using `jlcall` requires having both MATLAB and Julia (>=v.0.4) installed on your system. Additionally, to build the MEX function from source, you need a C++ compiler configured to work with MATLAB's `mex` function. You can ensure this is done by executing:

```
>> mex -setup C++
```

from the MATLAB command prompt. Further, `jlcall` relies on the `MATLAB.jl` package being available to Julia. You can install it by executing the following command in Julia:

```
julia> Pkg.add("MATLAB")
```

### Configuration

Now you are ready to set up `jlcall`. Clone it, if you haven't already. Then start MATLAB and navigate to the `jlcall/m` directory. Once there, run the `jlconfig` command:

```
>> jlconfig
```

You will be prompted to select a `julia` executable. Once you have done so, `jlconfig` will:
 1. interrogate your system for settings,
 2. build the `jlcall` MEX function from source,
 3. write a `jlconfig.mat` file containing information necessary to properly initialize `jlcall`,
 4. add the `jlcall/m` directory to your MATLAB path.

### Simple uses of `jlcall`

The `jlcall` project provides `Jl.m`, which contains a high-level interface to the `jlcall` MEX function. Aside from hiding the gory details needed to properly initialize the Julia runtime, `Jl.m` provides two generally useful member functions.

#### `Jl.eval`

Using `Jl.eval`, one can evaluate arbitrary Julia expressions captured in MATLAB strings:

```
>> Jl.eval('2+2')

ans =

                    4
```

#### `Jl.call`

With `Jl.call`, one can call any Julia function whose arguments can be marshaled to Julia via `MATLAB.jl`'s `jvariable` function and whose return value can be marshaled to MATLAB via `mxarray`. The first argument to `Jl.call` is the name of the function as a string. The remaining arguments are the values to be passed to the named function:

```
>> Jl.call('factorial', 10)

ans =

     3628800
```

## `jlcall` from the ground up

A MATLAB MEX function has a fixed signature. It is a `void` function taking four arguments, which are:
 - `int nlhs`, the number of outputs specified in the MATLAB invocation;
 - `mxArrray **plhs`, which points to an array of `min(1,nlhs)` addresses where output addresses are expected to be stored;
 - `int nrhs`, the number of arguments given in the invocation of this MEX function;
 - `mxArray **prhs`, a pointer to an array of `nrhs` addresses which contain the addresses of the values passed in to this MEX function.

The principal way that the `jlcall` MEX function works is, given its first argument is a string, to call the Julia function with the given name, passing in the the (remaining) MEX function arguments. Thus, `jlcall` call allows any Julia function accepting four arguments of type `Int32`, `Ptr{Void}`, `Int32`, and `Ptr{Void}`, respectively, and which interprets the arguments appropriately, to be invoked from MATLAB. In particular, the functionality underlying `Jl.eval` and `Jl.call` is provided by two such Julia functions.

Of course, there are no functions in Julia's `Base` library that match the above criteria, so one also needs, at a minimum, the ability to load code into the Julia runtime. Further, provision must be made for initializing the Julia runtime in the first place. To accomodate, `jlcall` can also be called in other ways. Invoking `jlcall`:
 - with no arguments returns a logical representing whether the Julia runtime has been initialized;
 - with the empty string as its first argument signals initialization, at which point the second and third arguments are interpreted as strings representing the paths of `JULIA_HOME` and the desired Julia system image, respectively;
 - with a non-string first argument signals that all remaining string arguments are to be passed in as arguments to `jl_eval_string`.

The `jlcall` MEX interface is sparse by design. It is meant to provide the minimal functionality necessary to connect MATLAB and Julia through the MEX interface, and nothing more. Higher level functionality is left to be implemented on either side of the interface, each of which provides a language that is more appropriate for that purpose than C++.

## Limitations and caveats

- Arguments passed in to `jlcall` from MATLAB must not be modified on the Julia side. If it happens, expect MATLAB to crash. This is a requirement of the MEX interface, and is not specific to `jlcall`.

- Currently, Julia's `STDOUT` and `STDERR` are not redirected to the MATLAB GUI console. However, it should still be visible in the console from which MATLAB was started. For Windows users, starting MATLAB from the Windows terminal (`cmd`) is insufficient to see output, however, launching MATLAB from the `cygwin` or `msys` prompt should work.

- This project is very new and has been tested on only one machine, let alone across multiple machines, platforms, MATLAB versions, _etc_. Expect bugs, and please report them when they occur. PRs that extend functionality to new platforms are particularly welcome. The author would like to see this project succeed across the three platforms on which Julia and MATLAB are supported, and will make every effort consistent with his other many, many obligations to assist users in getting `jlcall` functioning in their environment.

# jlcall: Call Julia from MATLAB.

`jlcall` is a [MATLAB](http://www.mathworks.com/products/matlab/) [MEX](http://www.mathworks.com/help/matlab/matlab_external/introducing-mex-files.html) function that embeds [Julia](http://julialang.org/) in MATLAB.

## Why `jlcall`?

MATLAB is a tool for technical computing with a well-polished interface, many useful toolboxes, and a large number of users who have established efficient workflows around it. However, MATLAB's language has limitations that lead users to turn to writing MEX extensions in FORTRAN, C or C++ when efficient implementations are infeasible in MATLAB itself.

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
 2. write a `jlconfig.mat` file containing information necessary to properly initialize `jlcall`,
 3. build the `jlcall` MEX function from source,
 4. add the `jlcall/m` directory to your MATLAB path.


### Simple uses of `jlcall`

The `jlcall` project provides `Jl.m`, which contains a high-level interface to the `jlcall` MEX function. Aside from hiding the details of Julia runtime initialization, `Jl.m` provides some useful member functions.

#### `Jl.eval`

Using `Jl.eval`, one can evaluate Julia expressions captured in MATLAB strings:

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

#### `Jl.include`

One can load new Julia code by calling `Jl.include`. Suppose the file `double_it.jl` contains:

```
function double_it(outs::Vector{Ptr{Void}}, ins::Vector{Ptr{Void}})
  try
    mex_return(outs, [ 2*v for v in mex_args(ins) ]...)
  catch e
    mex_showerror(e)
  end
end
```

 This MEX-like function can be loaded into the Julia runtime as follows:

```
>> Jl.include('double_it.jl')
```

#### `Jl.mex`

MEX-like functions can be invoked with `Jl.mex`. The first argument is a string naming the function to be called. Remaining arguments are passed to that function. For instance, now that it is loaded, we can invoke `double_it`:

```
>> a = rand(5,5)

a =

    0.7577    0.7060    0.8235    0.4387    0.4898
    0.7431    0.0318    0.6948    0.3816    0.4456
    0.3922    0.2769    0.3171    0.7655    0.6463
    0.6555    0.0462    0.9502    0.7952    0.7094
    0.1712    0.0971    0.0344    0.1869    0.7547

>> Jl.mex('double_it', a)

ans =

    1.5155    1.4121    1.6469    0.8775    0.9795
    1.4863    0.0637    1.3897    0.7631    0.8912
    0.7845    0.5538    0.6342    1.5310    1.2926
    1.3110    0.0923    1.9004    1.5904    1.4187
    0.3424    0.1943    0.0689    0.3737    1.5094
```

It is worth noting that `Jl.mex` is a constant of the `Jl` class that is equal to `@jlcall`, a handle to the `jlcall` MEX function. We recommend always referring to `Jl.mex` instead of `jlcall`, as the initialization of the `Jl.mex` constant forces the initialization of the Julia runtime. If one were to use `jlcall` directly, one would have to separately ensure initialization occurred.

## Under the hood: the `jlcall` MEX function

The principal way that the `jlcall` MEX function works is, given its first argument is a string, to call the Julia function with the given name, passing in the the (remaining) MEX function arguments, packaged as two values of type `Vector{Ptr{Void}}`. The first argument is the array of outputs, while the second is the array of inputs. Thus, `jlcall` call allows any Julia function with this MEX-like signature to be invoked from MATLAB. In particular, the functionality underlying `Jl.eval` and `Jl.call` is provided by two such Julia functions.

Of course, there are no functions in Julia's `Base` library that match the above criteria, so one also needs, at a minimum, the ability to load code into the Julia runtime. Further, provision must be made for initializing the Julia runtime in the first place. To accomodate, `jlcall` can also be called in other ways. Invoking `jlcall`:
 - with no arguments returns a logical representing whether the Julia runtime has been initialized;
 - with the empty string as its first argument signals initialization, at which point the second and third arguments are interpreted as strings representing the paths of `JULIA_HOME` and the desired Julia system image, respectively;
 - with a non-string first argument signals that all remaining string arguments are to be passed in as arguments to `jl_eval_string`.

The `jlcall` MEX interface is sparse by design. It is meant to provide the minimal functionality necessary to connect MATLAB and Julia through the MEX interface, and nothing more. Higher level functionality is left to be implemented on either side of the interface, each of which provides a language that is more appropriate for that purpose than C++.

## Limitations and caveats

- The input arguments passed in to `jlcall` from MATLAB must not be modified on the Julia side. If it happens, expect MATLAB to crash. This is a requirement of the MEX interface, and is not specific to `jlcall`.

- Currently, Julia's `STDOUT` and `STDERR` are not redirected to the MATLAB GUI console. However, it should still be visible in the console from which MATLAB was started. For Windows users, starting MATLAB from the Windows terminal (`cmd`) is insufficient to see output, however, launching MATLAB from the `cygwin` or `msys` prompt should work.

- This project is very new and has been tested on only one machine, let alone across multiple machines, platforms, MATLAB versions, _etc_. Expect bugs, and please report them when they occur. PRs that extend functionality to new platforms are particularly welcome. The author would like to see this project succeed across the three platforms on which Julia and MATLAB are supported, and will make every effort consistent with his other many, many obligations to assist users in getting `jlcall` functioning in their environment.

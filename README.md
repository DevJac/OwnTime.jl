# OwnTime.jl

OwnTime provides two additional ways to view [Julia's Profile](https://docs.julialang.org/en/v1/manual/profile/) data.

# Installation

Use [Julia's package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/) to install.

In [the Julia REPL](https://docs.julialang.org/en/v1/stdlib/REPL/) do:

```julia
using Pkg
Pkg.add("OwnTime")
```

# Basic Usage

Let's say we have the following code in `mycode.jl`:

```julia
function myfunc()
    A = rand(200, 200, 400)
    maximum(A)
end
```

We profile our code in the usual way:

```julia
julia> include("mycode.jl")
myfunc (generic function with 1 method)

julia> myfunc()  # run once to force JIT compilation
0.9999999760080607

julia> using Profile

julia> @profile myfunc()
0.9999999988120492
```

We can now view our profiling data using `owntime` or `totaltime`:

```julia
julia> owntime()
 [1]  63% => dsfmt_fill_array_close_open!(::Random.DSFMT.DSFMT_state, ::Ptr{Float64}, ...) at DSFMT.jl:95
 [2]  13% => _fast at reduce.jl:454 [inlined]
 [3]  11% => eval(::Module, ::Any) at boot.jl:330
 [4]   8% => Array at boot.jl:408 [inlined]
 [5]   1% => != at float.jl:456 [inlined]


julia> totaltime()
 [1]  96% => eval(::Module, ::Any) at boot.jl:330
 [2]  96% => (::REPL.var"#26#27"{REPL.REPLBackend})() at task.jl:333
 [3]  96% => macro expansion at REPL.jl:118 [inlined]
 [4]  96% => eval_user_input(::Any, ::REPL.REPLBackend) at REPL.jl:86
 [5]  72% => myfunc() at mycode.jl:2
 [6]  72% => rand at Random.jl:277 [inlined]
 [7]  63% => rand(::Type{Float64}, ::Tuple{Int64,Int64,Int64}) at gcutils.jl:91
    ...
[11]  14% => myfunc() at mycode.jl:3
    ...
```

## `owntime` vs `totaltime`

`totaltime` show the amount of time spent on a StackFrame *including* its sub-calls. `owntime` shows the amount of time spent on a StackFrame *excluding* its sub-calls.

## Filtering StackFrames

We can filter [StackFrames](https://docs.julialang.org/en/v1/base/stacktraces/#Base.StackTraces.StackFrame) to shorten the output:

```julia
julia> owntime(stackframe_filter=filecontains("mycode.jl"))
 [1]  72% => myfunc() at mycode.jl:2
 [2]  14% => myfunc() at mycode.jl:3


julia> totaltime(stackframe_filter=filecontains("mycode.jl"))
 [1]  72% => myfunc() at mycode.jl:2
 [2]  14% => myfunc() at mycode.jl:3

julia> owntime(stackframe_filter=stackframe -> stackframe.func == :myfunc)
 [1]  72% => myfunc() at mycode.jl:2
 [2]  14% => myfunc() at mycode.jl:3
```

It's now clear that 72% of the time was spent on line 2 of our code, and 14% on line 3. The rest of the time was spent on overhead related to Julia and profiling; for such a small example a relatively large amount of time is spent on that overhead.

`stackframe_filter` should be passed a function that accepts a single [`StackFrame`](https://docs.julialang.org/en/v1/base/stacktraces/#Base.StackTraces.StackFrame) and returns `true` if that StackFrame should be included.

# How does this relate to Profile in Julia's standard library?

OwnTime merely provides an alternate view into the profiling data collected by Julia. It is complimentary to the [Profile](https://docs.julialang.org/en/v1/stdlib/Profile/) package in the standard library.

`totaltime` provides a view of the profiling data similar to the flat format of [`Profile.print(format=:flat)`](https://docs.julialang.org/en/v1/stdlib/Profile/#Profile.print).

`owntime` is a view unique to OwnTime*, hence the name.

The ability to filter [StackFrames](https://docs.julialang.org/en/v1/base/stacktraces/#Base.StackTraces.StackFrame) is unique to OwnTime*.

(\* At this time, and as far as I'm aware.)

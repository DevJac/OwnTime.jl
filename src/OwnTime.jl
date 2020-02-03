module OwnTime

export owntime, totaltime, filecontains
export framecounts, frametotal, frames

using Printf
using Profile

const StackFrame = StackTraces.StackFrame

function countmap(iter)
    result = Dict{eltype(iter), Int64}()
    for i in iter
        if haskey(result, i)
            result[i] += 1
        else
            result[i] = 1
        end
    end
    result
end

mutable struct OwnTimeState
    last_fetched_data :: Union{Nothing, Array{UInt64,1}}
    last_stacktraces :: Union{Nothing, Array{Array{StackFrame,1},1}}
end

const state = OwnTimeState(nothing, nothing)

new_data() = fetch()[3]

function clear()
    state.last_fetched_data = nothing
    state.last_stacktraces = nothing
end

function fetch()
    maxlen = Profile.maxlen_data()
    len = Profile.len_data()
    data = Vector{UInt}(undef, len)
    GC.@preserve data unsafe_copyto!(pointer(data), Profile.get_data_pointer(), len)
    new_data = data != state.last_fetched_data
    state.last_fetched_data = data
    return data, len == maxlen, new_data
end

function backtraces(;warn_on_full_buffer=true)
    profile_pointers, full_buffer, _new_profile_pointers = fetch()
    if warn_on_full_buffer && full_buffer
        @warn """The profile data buffer is full; profiling probably terminated
                 before your program finished. To profile for longer runs, call
                 `Profile.init()` with a larger buffer and/or larger delay."""
    end
    bts = Array{UInt64,1}[]
    i = 1
    for j in 1:length(profile_pointers)
        # 0 is a sentinel value that indicates the start of a new backtrace.
        # See the source code for `tree!` in Julia's Profile package.
        if profile_pointers[j] == 0
            push!(bts, profile_pointers[i:j-1])
            i = j+1
        end
    end
    filter(!isempty, bts)
end

function stacktraces(;warn_on_full_buffer=true)
    if !new_data() && !isnothing(state.last_stacktraces)
        state.last_stacktraces
    else
        bts = backtraces(warn_on_full_buffer=warn_on_full_buffer)
        stacktraces(bts)
    end
end

function stacktraces(backtraces)
    # Lookups are very slow, so we will lookup each unique pointer only once.
    lookups = Dict(p => StackTraces.lookup(p) for p in unique(reduce(vcat, backtraces, init=[])))
    sts = map(backtraces) do backtrace
        filter(reduce(vcat, map(p -> lookups[p], backtrace))) do stackframe
            stackframe.from_c == false
        end
    end
    state.last_stacktraces = sts
    sts
end

struct FrameCounts
    counts :: Array{Pair{StackFrame,Int64},1}
    total :: Int64
end

framecounts(fcs::FrameCounts) = fcs.counts

frametotal(fcs::FrameCounts) = fcs.total

frames(fcs::FrameCounts) = map(fcs -> fcs.first, fcs.counts)

Base.getindex(fcs::FrameCounts, i) = framecounts(fcs)[i]
Base.iterate(fcs::FrameCounts) = iterate(framecounts(fcs))
Base.iterate(fcs::FrameCounts, state) = iterate(framecounts(fcs), state)
Base.length(fcs::FrameCounts) = length(framecounts(fcs))

function Base.show(io::IO, fcs::FrameCounts)
    for (i, (stackframe, count)) in enumerate(fcs)
        percent_of_time = round(count / frametotal(fcs) * 100)
        if percent_of_time >= 1
            @printf(io, "%4s %3d%% => %s\n", @sprintf("[%d]", i), percent_of_time, stackframe)
        end
    end
end

function owntime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    owntime(sts; stackframe_filter=stackframe_filter)
end

function owntime(stacktraces; stackframe_filter=stackframe -> true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    nonempty_stacktraces = filter(!isempty, filtered_stacktraces)
    framecounts = countmap(reduce(vcat, first.(nonempty_stacktraces), init=StackFrame[]))
    FrameCounts(sort(collect(framecounts), by=pair -> pair.second, rev=true), length(stacktraces))
end

function totaltime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    totaltime(sts; stackframe_filter=stackframe_filter)
end

function totaltime(stacktraces; stackframe_filter=stackframe -> true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    framecounts = countmap(reduce(vcat, collect.(unique.(filtered_stacktraces)), init=StackFrame[]))
    FrameCounts(sort(collect(framecounts), by=pair -> pair.second, rev=true), length(stacktraces))
end

function filecontains(needle)
    function (stackframe)
        haystack = string(stackframe.file)
        occursin(needle, haystack)
    end
end

end # module

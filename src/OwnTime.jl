module OwnTime

export owntime, totaltime, filecontains

using Printf
using Profile
using StatsBase

mutable struct OwnTimeState
    last_fetched_data :: Union{Nothing, Array{UInt64,1}}
    last_stacktraces :: Union{Nothing, Array{Array{StackTraces.StackFrame,1},1}}
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
        if profile_pointers[j] == 0
            push!(bts, profile_pointers[i:j-1])
            i = j+1
        end
    end
    filter(bts) do bt
        length(bt) > 0
    end
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
    sts = map(backtraces) do backtrace
        filter(reduce(vcat, StackTraces.lookup.(backtrace))) do stackframe
            stackframe.from_c == false
        end
    end
    state.last_stacktraces = sts
    sts
end

function owncounts(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    owncounts(sts; stackframe_filter=stackframe_filter)
end

function owncounts(stacktraces; stackframe_filter=stackframe -> true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    nonempty_stacktraces = filter(a -> length(a) > 0, filtered_stacktraces)
    countmap(reduce(vcat, first.(nonempty_stacktraces)))
end

function totalcounts(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    totalcounts(sts; stackframe_filter=stackframe_filter)
end

function totalcounts(stacktraces; stackframe_filter=stackframe -> true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    countmap(reduce(vcat, collect.(Set.(filtered_stacktraces))))
end

function prettyprint(counts, total)
    for (stackframe, count) in sort(collect(counts), by=pair -> pair.second, rev=true)
        percent_of_time = round(count / total * 100)
        if percent_of_time >= 1
            @printf("%3d%%: %s\n", percent_of_time, stackframe)
        end
    end
end

function owntime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    owntime(sts; stackframe_filter=stackframe_filter)
end

function owntime(stacktraces; stackframe_filter=stackframe -> true)
    counts = owncounts(stacktraces; stackframe_filter=stackframe_filter)
    prettyprint(counts, length(stacktraces))
end

function totaltime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = stacktraces(warn_on_full_buffer=warn_on_full_buffer)
    totaltime(sts; stackframe_filter=stackframe_filter)
end

function totaltime(stacktraces; stackframe_filter=stackframe -> true)
    counts = totalcounts(stacktraces; stackframe_filter=stackframe_filter)
    prettyprint(counts, length(stacktraces))
end

function filecontains(needle)
    function (stackframe)
        haystack = string(stackframe.file)
        occursin(needle, haystack)
    end
end

end # module

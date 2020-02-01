module OwnTime

export owntime, totaltime, filecontains

using Profile
using StatsBase

mutable struct OwnTimeState
    last_fetched_data :: Union{Nothing, Array{UInt64,1}}
    last_stacktraces :: Union{Nothing, Array{Array{StackTraces.StackFrame,1},1}}
end

const state = OwnTimeState(nothing, nothing)

new_data() = fetch()[3]

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
    bts = backtraces(warn_on_full_buffer=warn_on_full_buffer)
    stacktraces(bts, warn_on_full_buffer=warn_on_full_buffer)
end

function stacktraces(backtraces; warn_on_full_buffer=true)
    sts = map(backtraces) do backtrace
        filter(reduce(vcat, StackTraces.lookup.(backtrace))) do stackframe
            stackframe.from_c == false
        end
    end
    state.last_stacktraces = sts
    sts
end

function owntime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = new_data() ? stacktraces(warn_on_full_buffer=warn_on_full_buffer) : state.last_stacktraces
    owntime(sts; stackframe_filter=stackframe_filter, warn_on_full_buffer=warn_on_full_buffer)
end

function owntime(stacktraces; stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    nonempty_stacktraces = filter(a -> length(a) > 0, filtered_stacktraces)
    countmap(reduce(vcat, first.(nonempty_stacktraces)))
end

function totaltime(;stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    sts = new_data() ? stacktraces(warn_on_full_buffer=warn_on_full_buffer) : state.last_stacktraces
    totaltime(sts; stackframe_filter=stackframe_filter, warn_on_full_buffer=warn_on_full_buffer)
end

function totaltime(stacktraces; stackframe_filter=stackframe -> true, warn_on_full_buffer=true)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    countmap(reduce(vcat, collect.(Set.(filtered_stacktraces))))
end

function filecontains(needle)
    function (stackframe)
        haystack = string(stackframe.file)
        occursin(needle, haystack)
    end
end

end # module

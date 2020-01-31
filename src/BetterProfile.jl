using Profile
using StatsBase

function fetch()
    maxlen = Profile.maxlen_data()
    len = Profile.len_data()
    data = Vector{UInt}(undef, len)
    GC.@preserve data unsafe_copyto!(pointer(data), Profile.get_data_pointer(), len)
    return data, len == maxlen
end

function profile_backtraces(;warn_on_full_profile_data_buffer=true)
    profile_pointers, full_buffer = fetch()
    if warn_on_full_profile_data_buffer && full_buffer
        @warn """The profile data buffer is full; profiling probably terminated
                 before your program finished. To profile for longer runs, call
                 `Profile.init()` with a larger buffer and/or larger delay."""
    end
    backtraces = Array{UInt64,1}[]
    i = 1
    for j in 1:length(profile_pointers)
        if profile_pointers[j] == 0
            push!(backtraces, profile_pointers[i:j-1])
            i = j+1
        end
    end
    filter(backtraces) do bt
        length(bt) > 0
    end
end

function profile_stacktraces(;warn_on_full_profile_data_buffer=true)
    backtraces = profile_backtraces(warn_on_full_profile_data_buffer=warn_on_full_profile_data_buffer)
    map(backtraces) do backtrace
        filter(reduce(vcat, StackTraces.lookup.(backtrace))) do stackframe
            stackframe.from_c == false
        end
    end
end

function own_time(stackframe_filter=stackframe -> true; warn_on_full_profile_data_buffer=true)
    stacktraces = profile_stacktraces(warn_on_full_profile_data_buffer=warn_on_full_profile_data_buffer)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    nonempty_stacktraces = filter(a -> length(a) > 0, filtered_stacktraces)
    countmap(reduce(vcat, first.(nonempty_stacktraces)))
end

function total_time(stackframe_filter=stackframe -> true; warn_on_full_profile_data_buffer=true)
    stacktraces = profile_stacktraces(warn_on_full_profile_data_buffer=warn_on_full_profile_data_buffer)
    filtered_stacktraces = map(stacktraces) do stackframes
        filter(stackframe_filter, stackframes)
    end
    countmap(reduce(vcat, filtered_stacktraces))
end

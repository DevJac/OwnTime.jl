using OwnTime
using Profile

function profile_me()
    A = rand(200, 200, 400)
    maximum(A)
end

Profile.init(1_000_000, 0.001)
Profile.clear()
@profile profile_me()
owntime()
t = totaltime()
framecounts(t)
frametotal(t)
frames(t)

local Encoder = require("encoder")

local encoder = Encoder:new(1, 2) -- D1 and D2

print("Testing Encoder...")

-- Set up a timer to periodically print the position and velocity
local printTimer = tmr.create()
printTimer:alarm(25, tmr.ALARM_AUTO, function()
    print("Ticks:", encoder:read())
    print("Position (radians):", encoder:getPositionInRadians())
    print("Position (degrees):", encoder:getPositionInDegrees())
end)
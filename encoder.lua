local rotary = require("rotary")

local Encoder = {}
Encoder.__index = Encoder

local ROTARY_ID = 0
local ticksPerRevolution = 2720

function Encoder:new(pinA, pinB)
    local obj = {
        pinA = pinA,
        pinB = pinB,
        currentPosition = 0,
    }

    -- Initialize the rotary module
    rotary.close(ROTARY_ID) -- Close any previous instance
    rotary.setup(ROTARY_ID, pinA, pinB)

    setmetatable(obj, Encoder)
    return obj
end

function Encoder:read()
    self.currentPosition = rotary.getpos(ROTARY_ID)
    return self.currentPosition
end

function Encoder:getPositionInRadians()
    return (self.currentPosition / ticksPerRevolution) * 2 * math.pi
end

function Encoder:getPositionInDegrees()
    return (self.currentPosition / ticksPerRevolution) * 360
end

return Encoder
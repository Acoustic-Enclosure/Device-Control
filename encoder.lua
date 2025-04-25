local Encoder = {}
Encoder.__index = Encoder

function Encoder:new(pinA, pinB)
    local obj = {
        pinA = pinA,
        pinB = pinB,
        position = 0,
        ticksPerRevolution = 544 -- ADJUST 
    }

    gpio.mode(pinA, gpio.INPUT)
    gpio.mode(pinB, gpio.INPUT)

    gpio.trig(pinA, "both", function()
        local pinAState = gpio.read(pinA)
        local pinBState = gpio.read(pinB)
        if pinAState == pinBState then
            obj.position = obj.position + 1
        else
            obj.position = obj.position - 1
        end
        -- print("Encoder| position updated: ", obj.position) -- Debug log to track position changes
    end)

    setmetatable(obj, Encoder)
    return obj
end

function Encoder:read()
    return self.position
end

function Encoder:getPositionInRadians()
    return (self.position / self.ticksPerRevolution) * 2 * math.pi
end

function Encoder:getPositionInDegrees()
    return (self.position / self.ticksPerRevolution) * 360
end

return Encoder
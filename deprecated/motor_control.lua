local Encoder = require("encoder")
local PWMController = require("pwm_controller")
local PIDController = require("pid_controller")

local MotorControl = {}
MotorControl.__index = MotorControl

function MotorControl:new(encoderPins, pwmPins, pidParams)
    local obj = {
        encoder = Encoder:new(encoderPins[1], encoderPins[2]),
        pwm = PWMController:new(pwmPins[1], pwmPins[2]),
        pid = PIDController:new(pidParams.kp, pidParams.ki, pidParams.kd)
    }
    setmetatable(obj, MotorControl)
    return obj
end

function MotorControl:control(setpoint)
    local position = self.encoder:read()
    local output = self.pid:compute(setpoint, position)
    local duty1 = math.max(0, output)
    local duty2 = math.max(0, -output)
    self.pwm:setDutyCycle(duty1, duty2)
end

return MotorControl
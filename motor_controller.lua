local PIDController = require("pid_controller")
local PWMController = require("pwm_controller")

local MotorController = {}
MotorController.__index = MotorController

function MotorController:new(pwmPin, dirPin1, dirPin2, rotaryId, rotaryPinA, rotaryPinB)
    local obj = {
        pid = nil,
        pwm =  PWMController:new(pwmPin, dirPin1, dirPin2),
        rotaryId = rotaryId,
        rotaryPinA = rotaryPinA,
        rotaryPinB = rotaryPinB,
        ticksPerRevolution = 2710, -- Default ticks per revolution
        tolerance =  1, -- Default tolerance of 1 degree
        setpoint = 0,
        controlTimer = nil,
        -- dataCallback = nil -- Callback for sending telemetry data
    }

    setmetatable(obj, MotorController)
    return obj
end

function MotorController:initialize(kp, ki, kd)
    -- Start PWM
    self.pwm:setSpeedAndDirection(0, "none") -- Stop PWM initially
    self.pwm:start()

    -- Initialize rotary encoder
    self:resetRotary()

    -- Set PID output limits
    self.pid = PIDController:new(kp, ki, kd, 0, 0) -- Clockwise direction

    print("[MotorController] Initialized ", self.rotaryId)
end

function MotorController:resetRotary()
    rotary.close(self.rotaryId) -- Close any previous instance
    rotary.setup(self.rotaryId, self.rotaryPinA, self.rotaryPinB)
    if rotary.getpos(self.rotaryId) > 10 then
        self:resetRotary()
    end
end

function MotorController:setSetpoint(setpoint) -- Maybe unnecessary
    self.setpoint = setpoint
    self.pid:setSetpoint(self.setpoint)
end

function MotorController:startControl(dataCallback, stopCallback)
    self:stopControl() -- Stop any previous control loop
    local startTime = tmr.now()

    self.controlTimer = tmr.create()
    self.controlTimer:alarm(100, tmr.ALARM_AUTO, function()
        local position = rotary.getpos(self.rotaryId)
        local normalizedPosition = (position % self.ticksPerRevolution + self.ticksPerRevolution) % self.ticksPerRevolution
        local feedback = (normalizedPosition / self.ticksPerRevolution) * 360 -- Convert ticks to degrees
        local output, error = self.pid:compute(feedback)

        if output then
            local speed = math.abs(output)
            local direction = output >= 0 and "forward" or "reverse"
            self.pwm:setSpeedAndDirection(speed, direction)
        end

        -- Send telemetry data via callback
        if dataCallback then
            local endTime = tmr.now()

            dataCallback({
                setpoint = self.setpoint,
                input = feedback,
                output = output or 0,
                error = error or 0
            })
        end

        -- Stop control if the setpoint is reached within tolerance
        if math.abs(self.setpoint - feedback) < self.tolerance then -- Tolerance of 1 degree
            self:stopControl()
            if stopCallback then
                stopCallback()
            end
        end
    end)
end

function MotorController:stopControl()
    if self.controlTimer then
        self.controlTimer:stop()
        self.controlTimer:unregister()
        self.controlTimer = nil
    end

    self.pwm:setSpeedAndDirection(0, "none") -- Stop the motor
    self.pwm:stop()
end

function MotorController:cleanup()
    self:stopControl()
    self:resetRotary()
end

return MotorController

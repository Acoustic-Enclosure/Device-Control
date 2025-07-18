local PIDController = {}
PIDController.__index = PIDController

function PIDController:new(kp, ki, kd, controllerDirection, setpoint)
    local obj = {
        kp = kp,
        ki = ki,
        kd = kd,
        controllerDirection = controllerDirection or 1,
        outputSum = 0,
        lastInput = 0,
        outMin = -1023,            -- -1023
        outMax = 1023,             -- 1023
        sampleTime = 50000,        -- Default sample time in microseconds (50ms)
        lastTime = tmr.now(),      -- Initialize lastTime with the current time in microseconds
        setpoint = setpoint or 0   -- Initialize setpoint
    }

    setmetatable(obj, PIDController)
    return obj
end

function PIDController:setSetpoint(newSetpoint)
    self.setpoint = newSetpoint
end

function PIDController:compute(input)
    local now = tmr.now()
    local timeChange = now - self.lastTime

    if timeChange >= self.sampleTime then  -- Check if the sample time has elapsed
        local error = self.setpoint - input
        self.outputSum = self.outputSum + (self.ki * error * (self.sampleTime / 1000000))

        if self.outputSum > self.outMax then
            self.outputSum = self.outMax
        elseif self.outputSum < self.outMin then
            self.outputSum = self.outMin
        end

        local dInput = (input - self.lastInput) / (self.sampleTime / 1000000)
        local output = (self.kp * error) + self.outputSum - (self.kd * dInput)

        if output > self.outMax then
            output = self.outMax
        elseif output < self.outMin then
            output = self.outMin
        end

        self.lastInput = input
        self.lastTime = now
        return output, error -- Return output and error
    end

    return nil -- Return nil if the sample time hasn't elapsed
end

return PIDController

local PIDController = require("pid_controller")
local PWMController = require("pwm_controller")
local rotary = require("rotary")

local SetPointC = {}
SetPointC.__index = SetPointC

function SetPointC:new(pwmPin, dirPin1, dirPin2, pinA, pinB, kp, ki, kd, id)
    local obj = {
        pwmPin = pwmPin,
        dirPin1 = dirPin1,
        dirPin2 = dirPin2,
        pinA = pinA,
        pinB = pinB,
        kp = kp,
        ki = ki,
        kd = kd,
        id = id,
        pid = PIDController:new(kp, ki, kd, 0, 0), -- Clockwise direction
        pwm = PWMController:new(pwmPin, dirPin1, dirPin2),
        rotaryId = id,
        ticksPerRevolution = 2710, -- Change if needed
        maxOccurrences = 100, -- Default max occurrences
    }

    setmetatable(obj, SetPointC)
    return obj
end

function SetPointC:initialize()
    -- Initialize rotary encoder
    rotary.close(self.rotaryId) -- Close any previous instance
    rotary.setup(self.rotaryId, self.pinA, self.pinB)

    -- Set PID output limits
    local maxOutput = 1023 --255 -- Max PWM value
    local minOutput = -maxOutput -- Min PWM value
    self.pid:setOutputLimits(minOutput, maxOutput)

    -- Set sample time for PID
    self.pid:setSampleTime(50000) -- 50ms

    -- Start PWM
    self.pwm:setSpeedAndDirection(0, "none") -- Stop PWM initially
    self.pwm:start()

    -- Set initial SetPointC to the current rotary position to start paused
    local initialPosition = rotary.getpos(self.rotaryId)
    if initialPosition > 10 then
        error("[SetPointC] Error: Initial position is greater than 10.")
    end
    local initialDegrees = (initialPosition / self.ticksPerRevolution) * 360
    self.pid:setSetPointC(initialDegrees)

    print("[SetPointC] Initialized with PID and PWM settings")
end

function SetPointC:setOutputLimits(maxOutput, minOutput)
    self.pid:setOutputLimits(minOutput, maxOutput)
end

function SetPointC:setSampleTime(sampleTime)
    self.pid:setSampleTime(sampleTime)
end

function SetPointC:setMaxOccurrences(maxOccurrences)
    self.maxOccurrences = maxOccurrences
end

function SetPointC:start(SetPointCValue, onComplete)
    if not self.pid or not self.pwm then
        print("[SetPointC] Error: SetPointC not initialized. Call initialize() first.")
        return
    end

    -- Set the SetPointC
    local SetPointC = SetPointCValue
    self.pid:setSetPointC(SetPointC)

    -- Data collection
    local data = {
        errors = {}, -- Store errors over time
        positions = {}, -- Store positions over time
    }

    -- Counter for occurrences
    local occurrenceCount = 0

    -- Control loop
    local function controlLoop()
        -- print(string.format("[Memory Heap]: %d bytes", node.heap()))
        local position = rotary.getpos(self.rotaryId)
        -- Normalize position to 0-359 degrees using modular arithmetic
        local normalizedPosition = (position % self.ticksPerRevolution + self.ticksPerRevolution) % self.ticksPerRevolution
        local feedback = (normalizedPosition / self.ticksPerRevolution) * 360 -- Get rotary position in degrees
        local output, err = self.pid:compute(feedback)

        if output then
            local speed = math.abs(output)
            local direction = output >= 0 and "forward" or "reverse"
            self.pwm:setSpeedAndDirection(speed, direction)
        end

        -- Store data for analysis
        table.insert(data.errors, err)
        table.insert(data.positions, feedback)

        -- Check if the SetPointC is reached within a tolerance or if max occurrences reached
        occurrenceCount = occurrenceCount + 1
        if math.abs(err) < 1 or occurrenceCount >= self.maxOccurrences then -- Tolerance of 1 degree
            -- Stop the motor
            self.pwm:setSpeedAndDirection(0, "none") -- Stop PWM
            self.pwm:stop()

            -- Stop the timer
            if self.controlTimer then
                self.controlTimer:stop()
                self.controlTimer:unregister()
                self.controlTimer = nil
            end

            -- Call the callback with the collected data
            if onComplete then
                onComplete(data)
            end
        end
    end

    -- Use a timer to periodically call the control loop
    if self.controlTimer then
        self.controlTimer:stop()
        self.controlTimer:unregister()
    end
    self.controlTimer = tmr.create()
    self.controlTimer:alarm(100, tmr.ALARM_AUTO, controlLoop)

    print("[SetPointC] Process started with SetPointC: " .. SetPointC)
end

return SetPointC
local PWMController = {}
PWMController.__index = PWMController

function PWMController:new(pwmPin, dirPin1, dirPin2)
    local obj = {
        pwmPin = pwmPin,
        dirPin1 = dirPin1,
        dirPin2 = dirPin2
    }

    pwm.setup(pwmPin, 500, 0)
    gpio.mode(dirPin1, gpio.OUTPUT)
    gpio.mode(dirPin2, gpio.OUTPUT)

    setmetatable(obj, PWMController)
    return obj
end

function PWMController:setSpeedAndDirection(speed, direction)
    pwm.setduty(self.pwmPin, speed)
    if direction == "forward" then
        gpio.write(self.dirPin1, gpio.HIGH)
        gpio.write(self.dirPin2, gpio.LOW)
    elseif direction == "reverse" then
        gpio.write(self.dirPin1, gpio.LOW)
        gpio.write(self.dirPin2, gpio.HIGH)
    else
        gpio.write(self.dirPin1, gpio.LOW)
        gpio.write(self.dirPin2, gpio.LOW)
    end
end

function PWMController:start()
    pwm.start(self.pwmPin)
end

function PWMController:stop()
    pwm.stop(self.pwmPin)
end

return PWMController
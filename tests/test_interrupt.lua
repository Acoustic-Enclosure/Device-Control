gpio.mode(1, gpio.INPUT) -- D1 (GPIO5)

gpio.trig(1, "both", function()
    print("Interrupt triggered on D1")
end)

print("Interrupt test running. Trigger D1 to see output.")
print("[INIT] Starting...")

-- Optional delay to allow safe startup
tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
    print("[INIT] Running mqtt.lua")
    dofile("mqtt.lua")
end)
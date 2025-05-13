print("[BASE] Starting...")

-- Optional delay to allow safe startup
tmr.create():alarm(3000, tmr.ALARM_SINGLE, function()
    print("[BASE] Running main.lua")
    dofile("main.lua")
end)
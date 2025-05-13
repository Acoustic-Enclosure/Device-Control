-- TODO: RESOLVE FOR 2 MOTORS
local SetPoint = require("set_point")

-- CONFIGURATION
-- Wi-Fi settings
local WIFI_SSID = "IZZI-33EC" -- Wi-Fi SSID | "IZZI-33EC" | "SiTeConectasTeHackeo"
local WIFI_PASSWORD = "FKarr6FnGhaZqHerXc" -- Wi-Fi password | "FKarr6FnGhaZqHerXc" | "NiditoBodet01"
local WIFI_RETRIES = 0
local MQTT_RETRIES = 0

-- MQTT broker settings
local BROKER_HOST = "192.168.0.61" -- MQTT broker IP or hostname | $ ipconfig getifaddr en0
local BROKER_PORT = 1883 -- MQTT TCP port
local CLIENT_ID = "NODEMCU_01" -- unique client ID, change numeration for each device
print("[INFO] ID:", CLIENT_ID)

-- MQTT topics
local DEVICE_STATUS_TOPIC = "device/" .. CLIENT_ID .. "/status"
local DEVICE_CMD_TOPIC = "device/" .. CLIENT_ID .. "/cmd"
local function motorDataTopic(m) return "motor/" .. m .. "/data" end

-- Physical settings
local PWM_PIN_1 = 5 -- D5
local DIR_PIN1_1 = 7 -- D7
local DIR_PIN2_1 = 8 -- D8
local ROTARY_PIN_A1 = 1 -- D1
local ROTARY_PIN_B1 = 2 -- D2

local PWM_PIN_2 = 6 -- D6
local DIR_PIN1_2 = 9 -- D9
local DIR_PIN2_2 = 10 -- D10
local ROTARY_PIN_A2 = 3 -- D3
local ROTARY_PIN_B2 = 4 -- D4

-- Controller settings
local KP = 8 -- 3.75 -- 8
local KI = 40 -- 0.85 -- 1.8
local KD = 0.1056 -- 0.00001 -- 0.5

-- SETUP
-- Wi-Fi connection
wifi.setmode(wifi.STATION)
station_cfg={}
station_cfg.ssid=WIFI_SSID
station_cfg.pwd=WIFI_PASSWORD 
wifi.sta.config(station_cfg)

-- Initialize two SetPoint objects for two motors
local motor1 = SetPoint:new(PWM_PIN_1, DIR_PIN1_1, DIR_PIN2_1, ROTARY_PIN_A1, ROTARY_PIN_B1, KP, KI, KD, 1) -- Motor 1
motor1:initialize()
motor1:setSampleTime(10000) -- 10ms
motor1:setMaxOccurrences(30) -- 20 occurrences

-- MQTT client
local m = mqtt.Client(CLIENT_ID)

-- Last‑Will: if this client drops, broker will publish DISCONNECTED (retained)
m:lwt(DEVICE_STATUS_TOPIC, "DISCONNECTED", 1, 1)

-- Handle offline event
m:on("offline", function()
    print ("[MQTT] Offline")
    connect_to_mqtt() -- Retry connection
end)

-- Handle incoming messages
m:on("message", function(client, topic, message)
    local ok, cmd = pcall(sjson.decode, message)
    if not ok then
        print("[ERR] Decoding JSON failed")
        client:publish(DEVICE_STATUS_TOPIC, "CMD ERROR", 1, 0)
        return
    end

    if cmd.motor and cmd.angle then
        local motor = nil
        if cmd.motor == 1 then
            motor = motor1
        elseif cmd.motor == 2 then
            motor = motor2
        else
            return
        end

        client:publish(motorDataTopic(cmd.motor), sjson.encode({status="BUSY"}), 1, 0)

        motor:start(cmd.angle, function(data)
            local extended_data = {
                setpoint = cmd.angle,
                errors = data.errors,
                positions = data.positions,
                status = "READY",
            }
            local encode_ok, payload = pcall(sjson.encode, extended_data)
            if not encode_ok then
                local encode_err = "[ERR] Failed to encode data to JSON"
                print(encode_err)
                local err_data = sjson.encode({
                    status = "ERROR",
                    message = encode_err,
                })
                client:publish(motorDataTopic(cmd.motor), err_data, 1, 0)
                return
            end

            client:publish(motorDataTopic(cmd.motor), payload, 1, 0)
            print("[MQTT] Cicle completed, data published.")
        end)
    else
        print("[ERR] Bad request, missing body properties")
        client:publish(DEVICE_STATUS_TOPIC, "CMD ERROR", 1, 0)
    end
end)

-- MQTT connection logic with retries
local function connect_to_mqtt()
    tmr.create():alarm(1000, tmr.ALARM_AUTO, function(timer)
        -- On connection, subscribe to command topic and publish READY
        m:connect(BROKER_HOST, BROKER_PORT, false,
            function(conn)
                print("[MQTT] Connected to broker: " .. BROKER_HOST .. ":" .. BROKER_PORT)
                MQTT_RETRIES = 0
                timer:stop()
                conn:subscribe(DEVICE_CMD_TOPIC, 1, function() print("[MQTT] subscribed to " .. DEVICE_CMD_TOPIC) end)
                conn:publish(DEVICE_STATUS_TOPIC, "CONNECTED", 1, 0) -- last is 0 to not retain
            end,
            function(_,reason)
                print("[MQTT] Connection failed: " .. reason .. " (Attempt " .. MQTT_RETRIES .. ")")
                MQTT_RETRIES = MQTT_RETRIES + 1
            end
        )
    end)
end

-- Wi-Fi connection logic with retries
local function wait_for_wifi()
    tmr.create():alarm(1000, tmr.ALARM_AUTO, function(timer)
        if wifi.sta.getip() == nil then
            print("[Wi-Fi] Connecting... (Attempt " .. WIFI_RETRIES .. ")")
            WIFI_RETRIES = WIFI_RETRIES + 1
        else
            print("[Wi-Fi] Connected: " .. wifi.sta.getip())
            timer:stop()
            WIFI_RETRIES = 0
            -- Proceed to MQTT connection
            connect_to_mqtt()
        end
    end)
end

-- Start
wait_for_wifi()

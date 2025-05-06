-- CONFIGURATION
-- Wi-Fi settings
local WIFI_SSID = "SiTeConectasTeHackeo" -- Wi-Fi SSID | "IZZI-33EC"
local WIFI_PASSWORD = "NiditoBodet01" -- Wi-Fi password | "FKarr6FnGhaZqHerXc"
local WIFI_RETRIES = 0
local MQTT_RETRIES = 0

-- MQTT broker settings
local BROKER_HOST = "192.168.100.116" -- MQTT broker IP or hostname | $ ipconfig getifaddr en0
local BROKER_PORT = 1883 -- MQTT TCP port
local CLIENT_ID = "NODEMCU_01" -- unique client ID, change numeration for each device
local MOTOR_ID = "1" -- this device’s motor ID

-- MQTT topics
local DEVICE_STATUS_TOPIC = "device/" .. CLIENT_ID .. "/status"
local DEVICE_CMD_TOPIC = "device/" .. CLIENT_ID .. "/cmd"

-- SETUP
-- Wi-Fi connection
wifi.setmode(wifi.STATION)
station_cfg={}
station_cfg.ssid=WIFI_SSID
station_cfg.pwd=WIFI_PASSWORD 
wifi.sta.config(station_cfg)

-- MQTT client
local m = mqtt.Client(CLIENT_ID)

-- set Last‑Will: if this client drops, broker will publish DISCONNECTED (retained)
m:lwt(DEVICE_STATUS_TOPIC, "DISCONNECTED", 1, 1)

-- Handle offline event
m:on("offline", function()
    print ("[MQTT] Offline")
    -- Retry connection
    connect_to_mqtt()
end)

-- Handle incoming messages
m:on("message", function(client, topic, message)
    print("[MQTT] Message received: " .. topic .. ": " .. message)
    -- parse and act on payload
    local ok, cmd = pcall(sjson.decode, message)
    if not ok then
        print("[ERR] invalid JSON command")
        return
    end

    print("[JSON] Decoded command:")
    for k, v in pairs(cmd) do
        print("  " .. k .. ": " .. tostring(v))
    end

    -- local motorStTopic = motorStatusTopic(cmd.motor)
    -- m:publish(motorStTopic, "MOVING", 1, 0)
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
                conn:publish(DEVICE_STATUS_TOPIC, "READY", 1, 1)
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

local WifiController = {}
WifiController.__index = WifiController

function WifiController:new(networks)
    local obj = {
        networks = networks or {},
        idx         = 1,
        ip_poll     = 5000,
        timeout     = 10000,
        retry       = 5000,
        events      = {},
        ip_timer    = nil,
        to_timer    = nil,
    }

    setmetatable(obj, WifiController)
    return obj
end

function WifiController:on(event, fn)
    self.events[event] = fn
end

function WifiController:emit(event, ...)
    if self.events[event] then
        self.events[event](...)
    end
end

function WifiController:tryCurrent()
    local net = self.networks[self.idx]
    print("[Wi-Fi] Connecting to: " .. net.ssid)
    wifi.setmode(wifi.STATION)
    wifi.sta.config{ ssid=net.ssid, pwd=net.pwd }
    wifi.sta.connect()
end

function WifiController:start()
    if self.ip_timer then self.ip_timer:stop() end
    if self.to_timer then self.to_timer:stop() end

    self:tryCurrent()

    self.ip_timer = tmr.create()
    self.ip_timer:alarm(self.ip_poll, tmr.ALARM_AUTO, function()
        local ip = wifi.sta.getip()
        if ip then
            self.ip_timer:stop()
            self.to_timer:stop()
            self:emit("connected", ip)
        end
    end)

    self.to_timer = tmr.create()
    self.to_timer:alarm(self.timeout, tmr.ALARM_SINGLE, function()
        self.ip_timer:stop()
        print("[Wi-Fi] Connection timed out on " .. self.networks[self.idx].ssid)
        self.idx = (self.idx % #self.networks) + 1
        if self.idx == 1 then
            print("[Wi-Fi] All networks failed, retrying list after delay")
            tmr.create():alarm(self.retry, tmr.ALARM_SINGLE, function()
                self:start()
            end)
        else
            self:start()
        end
    end)
end

return WifiController

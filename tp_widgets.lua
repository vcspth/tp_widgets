local io = io
local string = string
local math = math
local widget = widget
local timer = timer
local awful = awful
local setmetatable = setmetatable

module("tp_widgets")

local battery_path = "/sys/devices/platform/smapi/BAT0/"
default_text = "no tp_smapi found"
default_power_update_freq = 10
default_battery_update_freq = 120

battery_discharging_format = "|B:%02.f:%02.f "
battery_charging_format = "|B: charging "
battery_ac_format = "|B: ac power "
battery_percent_format = "( %02.f/%02.f%% )"

power_discharging_format = " |P:%6.f mW"
power_charging_format = " |P: --"

local metasettings = {}

local function create_widget_helper(timer_func,update_freq)
	local w = widget({ type = "textbox" })
	metasettings[w] = {}
	metasettings[w].widget = w
	metasettings[w].timer = timer({ timeout = update_freq })
	metasettings[w].update = function() timer_func(metasettings[w]) end			
	metasettings[w].timer:add_signal("timeout", metasettings[w].update)

	metasettings[w].init = function() metasettings[w].timer:start() metasettings[w].update() end

	return w
end

function update(widget)
	if metasettings[widget] ~= nil then
		metasettings[widget].update()
	end
end

function getMetaObject(widget)
	return metasettings[widget]
end

function create_battery_widget(update_freq)
	local w = create_widget_helper(update_battery_state, update_freq or default_battery_update_freq)

	metasettings[w].discharging_format = battery_discharging_format
	metasettings[w].charging_format = battery_charging_format
	metasettings[w].ac_format = battery_ac_format
	metasettings[w].percent_format = battery_percent_format
	metasettings[w].init()

	return w
end

function create_power_widget(update_freq)
	local w = create_widget_helper(update_power_state, update_freq or default_power_update_freq)

	metasettings[w].discharging_format = power_discharging_format
	metasettings[w].charging_format = power_charging_format
	metasettings[w].init()

	return w
end

local function exec_command(command)
	local stream = io.popen(command)
	if not stream then do return nil end end
	
	local result = stream:read('*a')

	io.close(stream)

	return result
end

function update_battery_state(info)
	local catcommand = "cat " .. battery_path

	local percent = exec_command(catcommand .. "remaining_percent")
	local maxpercent = exec_command(catcommand .. "stop_charge_thresh")
	local state = exec_command(catcommand .. "state");
	
	local text = ""

	if string.find(state,"discharging") then
		local time = exec_command(catcommand .. "remaining_running_time")
		local hours = math.floor(time/60)
		local minutes = time - hours * 60
		text  = string.format(info.discharging_format,hours,minutes)

	elseif string.find(state,"charging") then
		text = string.format(info.charging_format)
	else
		text = string.format(info.ac_format)
	end
	
	local text = text .. string.format(info.percent_format,percent,maxpercent)

	info.widget.text = text
end

function update_power_state(info)
	local catcommand = "cat " .. battery_path

	local powerinfo = exec_command(catcommand .. "power_now") * 1;

	if powerinfo >= 0 then
		info.widget.text = string.format(info.charging_format,math.abs(powerinfo))
		return
	end

	info.widget.text = string.format(info.discharging_format,math.abs(powerinfo))
end

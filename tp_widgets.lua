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

function set_custom_update(widget,func)
	if metasettings[widget] ~= nil then
		metasettings[widget].custom_update = func
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
	
	if info.max_percent == nil then
		info.max_percent = exec_command(catcommand .. "stop_charge_thresh")
	end

	info.percent = exec_command(catcommand .. "remaining_percent")
	local state = exec_command(catcommand .. "state");
	
	local text = ""

	if string.find(state,"discharging") then
		local time = exec_command(catcommand .. "remaining_running_time")
		info.hours = math.floor(time/60)
		info.minutes = time - hours * 60
		info.is_discharging = true
		info.is_charging = false
		text  = string.format(info.discharging_format,info.hours,info.minutes)

	elseif string.find(state,"charging") then
		info.is_discharging = false
		info.is_charging = true
		text = string.format(info.charging_format)
	else
		info.is_discharging = false
		info.is_charging = false
		text = string.format(info.ac_format)
	end
	
	local text = text .. string.format(info.percent_format,info.percent,info.max_percent)
	
	if info.custom_update ~= nil then
		info.custom_update(info)
	end

	info.widget.text = text
end

function update_power_state(info)
	local catcommand = "cat " .. battery_path

	info.value = exec_command(catcommand .. "power_now") * 1;

	if info.value >= 0 then
		info.widget.text = string.format(info.charging_format,math.abs(info.value))
		return
	end
	
	if info.custom_update ~= nil then
		info.custom_update(info)
	end

	info.widget.text = string.format(info.discharging_format,math.abs(info.value))
end

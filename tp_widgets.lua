local io = io
local string = string
local math = math
local widget = widget
local timer = timer
local awful = awful

module("tp_widgets")

local battery_path = "/sys/devices/platform/smapi/BAT0/"
local default_text = "no tp_smapi found"
local default_power_update_freq = 10
local default_battery_update_freq = 120

function create_widget_helper(timer_func,update_freq)
	local w = widget({ type = "textbox" })
	w.text = timer_func()
		
	t = timer({ timeout = update_freq })
	t:add_signal("timeout", function () w.text = timer_func() end)
	t:start()

	return w
end

function create_battery_widget(update_freq)
	if update_freq == nil then
		update_freq = default_battery_update_freq
	end

	return create_widget_helper(get_battery_state, update_freq)
end

function create_power_widget(update_freq)
	if update_freq == nil then
		update_freq = default_power_update_freq
	end

	return create_widget_helper(get_power_state, update_freq)
end

function exec_command(command)
	local stream = io.popen(command)
	if not stream then do return nil end end
	
	local result = stream:read('*a')

	io.close(stream)

	return result
end

function get_battery_state()
	local catcommand = "cat " .. battery_path

	local percent = exec_command(catcommand .. "remaining_percent")
	local maxpercent = exec_command(catcommand .. "stop_charge_thresh")
	local state = exec_command(catcommand .. "state");
	
	local text = "|B: "

	if string.find(state,"discharging") then
		local time = exec_command(catcommand .. "remaining_running_time")
		local hours = math.floor(time/60)
		local minutes = time - hours * 60
		text  = text .. string.format("%2.f",hours) .. ":" .. string.format("%2.f", minutes )

	elseif string.find(state,"charging") then
		text = text .. "charging"
	else
		text = text .. "ac power"
	end
	
	local percentstr = string.format("%2.f", percent)
	local maxstr = string.format("%2.f", maxpercent)
	local text  = text .. " ( " .. percentstr ..  "/" .. maxstr .. "% )"

	return text
end

function get_power_state()
	local catcommand = "cat " .. battery_path

	local powerinfo = exec_command(catcommand .. "power_now") * 1;
	local text = " |P:"

	if powerinfo >= 0 then
		return text .. " --"
	end

	text = text .. string.format("%6.f",math.abs(powerinfo)) .. " mW"

	return text
end

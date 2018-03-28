--[[----------------------------------------
"time_ext.lua" > Put this VLC Extension Lua script file in \lua\extensions\ folder
--------------------------------------------
Requires "looper_intf.lua" > Put the VLC Interface Lua script file in \lua\intf\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=looper_intf
* Otherwise the Extension script (First run: "Time > SETTINGS" dialog box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [looper_intf]
Then use the Extension ("Time" dialog box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
--]]----------------------------------------
-- TODO: timer/reminder/alarm; multiple time format inputs for different positions (1-9);

config={}
local cfg={}
looping_interface = "slowsub_looper_intf" -- Location: \lua\intf\slowsub_looper_intf.lua
-- defaults
DEF_time_format = "[T]"  -- [T]ime, [O]ver, [E]lapsed, [D]uration, [R]emaining
DEF_osd_position = "top-right"
time_formats = {"--- Clear! ---", "[E]", "[E25]", "[D]", "[R]", "[T]", "[O]", "[n]", "[_]", "<--- Append / Replace --->", "[E] / [D]", "[T] >> [O]", "-[R] / [D]", "-[R] ([T])"}
positions = {"top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"}
appendreplace_id = 0

function descriptor()
	return {
		title = "Slow Sub";
		version = "3.0";
		author = "michele";
		url = 'http://addons.videolan.org/content/show.php?content=149618';
--		shortdesc = "Time displayer.";
-- No shortdesc to use title instead of short description in VLC menu.
-- Then the first line of description will be the short description.
		description = [[
Time displayer.

Time is VLC extension that displays running time on the screen in a playing video.
(Extension script "time_ext.lua" + Interface script "looper_intf.lua")

Features:
- supported tags:  [E], [Efps], [D], [R], [T], [O], [n], [_];
- 9 possible positions on the screen;
- elapsed time with milliseconds;
- playback speed rate taken into account for duration time;
]];
		capabilities = {"menu"}
	}
end

function activate()
	Get_config()
	if config and config.SLOWSUB then
		cfg = config.SLOWSUB
	end
	if cfg.first_run==nil or cfg.first_run==true then
		cfg.first_run = false
		Set_config(cfg, "SLOWSUB")
		create_dialog_S()
	end
end

function deactivate()
end

function close()
	vlc.deactivate()
end

function meta_changed()
end

function menu()
	return {"Control panel", "Settings"}
end
function trigger_menu(id)
	if id==2 then -- Settings
		if dlg then dlg:delete() end
		create_dialog_S()
	end
end

-----------------------------------------

function create_dialog_S()
	dlg = vlc.dialog(descriptor().title .. " > SETTINGS")
	cb_extraintf = dlg:add_check_box("Enable interface: ", true,1,1,1,1)
	ti_luaintf = dlg:add_text_input(looping_interface,2,1,2,1)
	dlg:add_button("SAVE", click_SAVE_settings,1,2,1,1)
	dlg:add_button("CANCEL", click_CANCEL_settings,2,2,1,1)
	lb_message = dlg:add_label("CLI options: --extraintf=luaintf --lua-intf="..looping_interface,1,3,3,1)
end

function click_SAVE_settings()
	if cb_extraintf:get_checked() then
		vlc.config.set("extraintf", "luaintf")
		vlc.config.set("lua-intf", ti_luaintf:get_text())
	else
		vlc.config.set("extraintf", "")
	end
	lb_message:set_text("Please restart VLC for changes to take effect!")
end

function click_CANCEL_settings()
	trigger_menu(1)
end


-----------------------------------------

function Get_config()
	local s = vlc.config.get("bookmark10")
	if not s or not string.match(s, "^config={.*}$") then s = "config={}" end
	assert(loadstring(s))() -- global var
end

function Set_config(cfg_table, cfg_title)
	if not cfg_table then cfg_table={} end
	if not cfg_title then cfg_title=descriptor().title end
	Get_config()
	config[cfg_title]=cfg_table
	vlc.config.set("bookmark10", "config="..Serialize(config))
end

function Serialize(t)
	if type(t)=="table" then
		local s='{'
		for k,v in pairs(t) do
			if type(k)~='number' then k='"'..k..'"' end
			s = s..'['..k..']='..Serialize(v)..',' -- recursion
		end
		return s..'}'
	elseif type(t)=="string" then
		return string.format("%q", t)
	else --if type(t)=="boolean" or type(t)=="number" then
		return tostring(t)
	end
end

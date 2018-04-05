--[[----------------------------------------
"slowsub.lua" > Put this VLC Extension Lua script file in \lua\extensions\ folder
--------------------------------------------
Requires "slowsub_looper_intf.lua" > Put the VLC Interface Lua script file in \lua\intf\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=slowsub_looper_intf
* Otherwise the Extension script (First run: "Slow sub > SETTINGS" dialog box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [slowsub_looper_intf]
Then use the Extension ("Slow sub" dialog box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
--]]----------------------------------------

config={}
local cfg={}
looping_interface = "slowsub_looper_intf" -- Location: \lua\intf\slowsub_looper_intf.lua
--rateTable = {1.1, 1.2, 1.3,1.4,1.5,1.6,1.7,1.8,1.9,2.0,2.1,2.2,2.3,2.4,2.5}
rateTable = {"1,1", "1,2","1,3","1,4","1,5","1,6","1,7","1,8","1,9","2,0","2,1","2,2","2,3","2,4","2,5"}
-- defaults
--DEF_time_format = "[T]"  -- [T]ime, [O]ver, [E]lapsed, [D]uration, [R]emaining
--DEF_osd_position = "top-right"
--time_formats = {"--- Clear! ---", "[E]", "[E25]", "[D]", "[R]", "[T]", "[O]", "[n]", "[_]", "<--- Append / Replace --->", "[E] / [D]", "[T] >> [O]", "-[R] / [D]", "-[R] ([T])"}
--positions = {"top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"}
--appendreplace_id = 0

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
Slow Sub

This VLC extension slow down the rate video while a subs is on the screen.
(Extension script "slowsub.lua" + Interface script "slowsub_looper_intf.lua")
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
	else create_dialog() end
end

function deactivate()
    --create_dialog_S()
end

function close()
	--vlc.deactivate()
end

function meta_changed()
end

function menu()
	return {"Control panel", "Settings"}
end
function trigger_menu(id)
    if id==1 then -- Control panel
		if dlg then dlg:delete() end
		create_dialog()
	elseif id==2 then -- Settings
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
    --Verify the checkbox and set the config file
	if cb_extraintf:get_checked() then 
		vlc.config.set("extraintf", "luaintf")
		vlc.config.set("lua-intf", ti_luaintf:get_text())
	else
		--if user uncheck the box at next start the looper doesn't work
        vlc.config.set("extraintf", "")
        cfg.first_run = true
        Set_config(cfg, "SLOWSUB")
	end
	lb_message:set_text("Please restart VLC for changes to take effect!")
end

function click_CANCEL_settings()
	trigger_menu(1)
end

-----------------------------------------

function create_dialog()
	dlg = vlc.dialog(descriptor().title)
	--dlg:add_label("Time format: \\ Position:",1,1,2,1)
	dlg:add_label("<b>Slow rate</b>",1,1,1,1)
    dd_rate = dlg:add_dropdown(2,1,1,1)
		for i,v in ipairs(rateTable) do
			dd_rate:add_value(v, i)
		end
    rateButton = dlg:add_button("Update Values", clickUpdate,3,1,1,1)
end

function clickUpdate()
    cfg.rate = dd_rate:get_text()
    Set_config(cfg, "SLOWSUB")
end
-----------------------------------------

function Get_config()
	local s = vlc.config.get("bookmark10")
	if not s or not string.match(s, "^config={.*}$") then s = "config={}" end
	--Assert : check if there is an error from function
    --Loadstring  : loadstring load a Lua chunk from a string and it only compiles the chunk and returns the compiled chunk as a function
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

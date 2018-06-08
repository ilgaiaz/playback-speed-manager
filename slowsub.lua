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
rateTable = {"0.9", "0.85", "0.80", "0.75", "0.70", "0.65", "0.60", "0.55", "0.50"}
defaultRate = "0.65"
--Check subs variables
subtitles_uri = nil -- "file:///D:/films/subtitles.srt"
charset = "Windows-1250" -- nil or "UTF-8", "ISO-8859-2", ...
filename_extension = "srt" -- "eng.srt", "srt-vlc", ...
html1 = "<div align=\"center\" style=\"background-color:white;\"><a style=\"font-family:Verdana;font-size:36px;font-weight:bold;color:black;background-color:white;\">"
html2 = "</a></div>"


function descriptor()
    return {
        title = "Slow Sub";
        version = "3.0";
        author = "michele";
        --url = '';
--        shortdesc = "Time displayer.";
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
    get_config()
    if vlc.input.item() and check_subtitles() then
        --cfg.ready = true
        --set_config(cfg, "SLOWSUB")
        if config and config.SLOWSUB then 
            cfg = config.SLOWSUB 
        end
        cfg.rate = defaultRate
        set_config(cfg, "SLOWSUB")
        if cfg.first_run==nil or cfg.first_run==true then
            cfg.first_run = false
            set_config(cfg, "SLOWSUB")
            create_dialog_S()
        else 
            create_dialog() 
        end
    else
        create_dialog_error()
    end
        
end

function deactivate()
    cfg.rate = 1
    set_config(cfg, "SLOWSUB")
    --create_dialog_S()
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
    if id==1 then -- Control panel
        if dlg then 
            dlg:delete() 
        end
        create_dialog()
    elseif id==2 then -- Settings
        if dlg then 
            dlg:delete() 
        end
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
        set_config(cfg, "SLOWSUB")
    end
    lb_message:set_text("Please restart VLC for changes to take effect!")
end

function click_CANCEL_settings()
    trigger_menu(1)
end

function click_close()
    vlc.deactivate()
end

-----------------------------------------

function create_dialog()
    dlg = vlc.dialog(descriptor().title)
    --dlg:add_label("Time format: \\ Position:",1,1,2,1)
    dlg:add_label("<b>Slow speed</b>",1,1,1,1)
    dd_rate = dlg:add_dropdown(2,1,1,1)
        for i,v in ipairs(rateTable) do
            dd_rate:add_value(v, i)
        end
    rateButton = dlg:add_button("Update values", click_update_rate,3,1,1,1)
end

function click_update_rate()
    cfg.rate = dd_rate:get_text()
    set_config(cfg, "SLOWSUB")
end
-----------------------------------------
    
-----------------CHECK SUBS--------------  

function create_dialog_error()
    dlg = vlc.dialog(descriptor().title .. " > ERROR")
    w1 = dlg:add_label(html1..descriptor().title..html2.."<ol><li>Check if file .srt have the same name and folder of the film</li><li>Play a media before open this extension.</li><li>If the film is already on restart VLC for changes to take effect!</li><li>Take the steps before and now you're ready to use it.</li></ol>", 1, 1, 1, 1)
    dd_close = dlg:add_button("Close", click_close,1,4,1,1)
    --[[future implementation -> add srt file path with GUI
    Otherwise write the .srt file's path (/path/to/file.srt) in this label and update the info
    new_path = dlg:add_text_input("",1,2,1,1)
    dd_path = dlg:add_button("Update path", click_update_path,1,3,1,1)
    dd_close = dlg:add_button("Close", click_close,1,4,1,1)
       ]]
end

--[[ future implementation 
function click_update_path()
    cfg.path = new_path:get_text()
    set_config(cfg, "SLOWSUB")
    vlc.deactivate()
end
]]
function check_subtitles()
    if subtitles_uri==nil then 
        subtitles_uri=media_path(filename_extension) 
    end
-- read file
    local s = vlc.stream(subtitles_uri)
    if s==nil then 
        return false 
    end
    return true
end

    
function media_path(extension)
    local media_uri = vlc.input.item():uri()
    media_uri = string.gsub(media_uri, "^(.*)%..-$","%1") .. "." .. extension
    vlc.msg.info(media_uri)
    return media_uri
end

-----------------------------------------
        
function get_config()
    local s = vlc.config.get("bookmark10")
    if not s or not string.match(s, "^config={.*}$") then 
        s = "config={}" 
    end
    --Assert : check if there is an error from function
    --Loadstring  : loadstring load a Lua chunk from a string and it only compiles the chunk and returns the compiled chunk as a function
    assert(loadstring(s))() -- loads the vlcrc string in "bookmark10" (like a refresh after modified) ??
end

function set_config(cfg_table, cfg_title)
    if not cfg_table then 
        cfg_table={} 
    end
    if not cfg_title then 
        cfg_title=descriptor().title 
    end
    get_config()
    config[cfg_title]=cfg_table
    vlc.config.set("bookmark10", "config="..serialize(config))
end

function serialize(t)
    if type(t)=="table" then
        local s='{'
        for k,v in pairs(t) do
            if type(k)~='number' then 
                k='"'..k..'"' 
            end
            s = s..'['..k..']='..serialize(v)..',' -- recursion
        end
        return s..'}'
    elseif type(t)=="string" then
        return string.format("%q", t)
    else --if type(t)=="boolean" or type(t)=="number" then
        return tostring(t)
    end
end

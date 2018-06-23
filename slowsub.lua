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

rateTable = {"1", "0.9", "0.85", "0.80", "0.75", "0.70", "0.65", "0.60", "0.55", "0.50"}
--Check subs variables
FILENAME_EXTENSION = "srt" -- "eng.srt", "srt-vlc", ...

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
    cfg = load_config()
    if cfg.general.first_run then
        create_dialog_S()
    end
    if vlc.input.item() and check_subtitles() then
        create_dialog()
    else
        create_dialog_error()
    end
end

function deactivate()
    cfg.general.rate = "1"
    save_config(cfg)
end

function close()
    if dlg_id == 1 then
        vlc.deactivate()
    end
end

function menu()
    return {"Control panel"}
end

function trigger_menu(id)
    close_dialog()
    if id == 1 then
        create_dialog()
    end
end

function meta_changed()
end
-----------------------------------------

function close_dialog()
    if dlg then
        dlg:delete()
        dlg = nil
    end
end

--(x,x,x,x) = column, line, how many colums unify,  how many line unify??
function create_dialog_S()
    dlg_id = 1
    close_dialog()
    dlg = vlc.dialog(descriptor().title .. " > First run")
    message = dlg:add_label("To run the extension SlowSub a VLC loop interface needs to<br>be activated the first time. Do you want to enable it now?", 1, 1, 2, 1)
    dlg:add_button("Enable", click_ENABLE,1,2,1,1)
    dlg:add_button("Cancel", click_CANCEL_settings,2,2,1,1)
end

function click_ENABLE()
    vlc.config.set("extraintf", "luaintf")
    vlc.config.set("lua-intf", "slowsub_looper_intf")
    cfg.general.first_run = false
    save_config(cfg)
    lb_message_dialog_s:set_text("Please restart VLC for changes to take effect!")
end

function create_dialog()
    cfg = load_config()

    dlg = vlc.dialog(descriptor().title .. " > Speed Rate")
    dlg:add_label("Slow speed: ",1,1,1,1)
    dd_rate = dlg:add_dropdown(2,1,1,1)
    for i,v in ipairs(rateTable) do
        dd_rate:add_value(v, i)
    end
    log_msg("Current rate: " .. cfg.general.rate) -- This log adds enough delay to avoid the set_text to not fail
    dd_rate:set_text(cfg.general.rate)
    cb_extraintf = dlg:add_check_box("Interface enabled", true,1,3,1,1)
    dlg:add_button("Save", click_SAVE_settings,1,4,1,1)
    dlg:add_button("Cancel", click_CANCEL_settings ,2,4,1,1)
    lb_message_dialog = dlg:add_label("Uncheck and save for disable VLC loop interface",1,5,2,1)
end

function click_SAVE_settings()
    --Verify the checkbox and set the config file
    if not cb_extraintf:get_checked() then
        vlc.config.set("extraintf", "")
        cfg.general.first_run = true
        cfg.general.rate = "1"
        lb_message_dialog:set_text("Please restart VLC for changes to take effect!")
    else
        --if user uncheck the box at next start the looper doesn't work
        vlc.config.set("extraintf", "luaintf")
        cfg.general.rate = dd_rate:get_text()
        lb_message_dialog:set_text("Uncheck and save for disable VLC loop interface")
    end
    save_config(cfg)
    dlg:hide()
end

function click_CANCEL_settings()
    dlg:hide()
    if dlg_id == 1 then
        vlc.deactivate()
    end
end

-----------------------------------------

-----------------------------------------

-----------------CHECK SUBS--------------

function create_dialog_error()
    dlg = vlc.dialog(descriptor().title .. " > ERROR")
    w1 = dlg:add_label(html1..descriptor().title..html2.."-Play a media before opening this extension<br>-Check if the file .srt has the same name of the movie and is in the same folder<br>", 1, 1, 1, 1)
    dd_close = dlg:add_button("Close", click_close,1,4,1,1)
end

function check_subtitles()
    subtitles_uri=media_path(FILENAME_EXTENSION)
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

function log_msg(lm)
    vlc.msg.info("[Slowsub config interface] " .. lm)
end

-----------------------------------------

--- Returns a table containing all the data from the INI file.
--@param fileName The name of the INI file to parse. [string]
--@return The table containing all data from the INI file. [table]
function load_config()
    fileName = vlc.config.configdir() .. "slowsubrc"
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    local file = io.open(fileName, 'r')
    if not file then
        --, 'Error loading file :' .. fileName);
        data = default_config();
        save_config(data)
        return data
    end
    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if(tempSection)then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {};
        end
        local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
        if(param and value ~= nil)then
            if(tonumber(value))then
                value = tonumber(value);
            elseif(value == 'true')then
                value = true;
            elseif(value == 'false')then
                value = false;
            end
            if(tonumber(param))then
                param = tonumber(param);
            end
            data[section][param] = value;
        end
    end
    file:close();
    return data;
end

--- Saves all the data from a table to an INI file.
--@param fileName The name of the INI file to fill. [string]
--@param data The table containing all the data to store. [table]
function save_config(data)
    fileName = vlc.config.configdir() .. "slowsubrc"
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    assert(type(data) == 'table', 'Parameter "data" must be a table.');
    local file = assert(io.open(fileName, 'w+b'), 'Error loading file :' .. fileName);
    local contents = '';
    for section, param in pairs(data) do
        contents = contents .. ('[%s]\n'):format(section);
        for key, value in pairs(param) do
            contents = contents .. ('%s=%s\n'):format(key, tostring(value));
        end
        contents = contents .. '\n';
    end
    file:write(contents);
    file:close();
end

function default_config()
    local data = {}
    data.general = {}
    data.general.first_run = true
    data.general.rate = 1
    return data
end

--[[----- Slow sub ------------------------
"slowsub_looper_intf.lua" - Put this VLC Interface Lua script file in \lua\intf\ folder
--------------------------------------------
Requires "slowsub.lua" > Put the VLC Extension Lua script file in \lua\extensions\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=slowsub_looper_intf
* Otherwise the Extension script (First run: "Time > SETTINGS" dialog_msg box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [slowsub_looper_intf]
Then use the Extension ("Slowsub" dialog_msg box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
* Windows (current user): %APPDATA%\VLC\lua\intf\
* Linux (all users): /usr/lib/vlc/lua/intf/
* Linux (current user): ~/.local/share/vlc/lua/intf/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/
--]]----------------------------------------


--config.TIME={} -- subtable reserved for TIME extension
 -- subtable reserved for slowsub extension
--Load subs variables
CHARSET = "Windows-1250" -- nil or "ISO-8859-2", Windows-1250...
FILENAME_EXTENSION = "srt" -- "eng.srt", "srt-vlc", ...
--Speed video variables
MAXTIMEDIFFERENCE = 3 --Time in seconds


--**********************LOAD SUBS****************************
function load_subtitles()
    local subtitles_uri = media_path(FILENAME_EXTENSION)
    -- read file subtitles_uri
    local s = vlc.stream(subtitles_uri)
    if s==nil then
        return false
    end
    --Read max 500000 chars -> enough
    local data = s:read(500000)
    --replace the "\r" char with an empty char
    data = string.gsub( data, "\r", "")
    -- UTF-8 BOM detection
    if string.char(0xEF,0xBB,0xBF)==string.sub(data,1,3) then
        CHARSET=nil
    end
    -- parse datavlc.object.
    subtitles={}
    srt_pattern = "(%d%d):(%d%d):(%d%d),(%d%d%d) %-%-> (%d%d):(%d%d):(%d%d),(%d%d%d).-\n(.-)\n\n"
    --Find string match for find time value in the srt file
    for h1, m1, s1, ms1, h2, m2, s2, ms2, text in string.gmatch(data, srt_pattern) do
        --If the text is empty then add a space
        if text=="" then
            text=" "
        end
        if CHARSET~=nil then
            text=vlc.strings.from_charset(CHARSET, text)
        end
        --Add value start/stop time and text in the table subtitles
        table.insert(subtitles,{format_time(h1, m1, s1, ms1), format_time(h2, m2, s2, ms2), text})
    end
    if #subtitles~=0 then
        return true
    else
        return false
    end
end

function format_time(h,m,s,ms) -- time to seconds
    --ToDO : add millisecond + tonumber(ms)
    return tonumber(h)*3600+tonumber(m)*60+tonumber(s)
end

function media_path(extension)
    local media_uri = vlc.input.item():uri()
    media_uri = string.gsub(media_uri, "^(.*)%..-$","%1") .. "." .. extension
    vlc.msg.info(media_uri)
    return media_uri
end

--***************************ENDOF LOAD SUBS*********************************


--******************************SLOWSPEED************************************
function rate_adjustment(my_index)
    local i = 1
    local input = vlc.object.input()
    local currentSpeed = vlc.var.get(input,"rate")
    local normalSpeed = 1.0
    local updatedSpeed = set_video_speed(normalSpeed) --verify if user change the rate

    actual_time = get_elapsed_time()
    vlc.msg.dbg("Current rate: "..vlc.var.get(input,"rate"))
    if my_index == nil then
        if currentSpeed ~= normalSpeed then
            vlc.var.set(input, "rate", normalSpeed)
        end
        return nil  --Avoid some rare case of error when user change the elapsed time
    elseif  subtitles[my_index + 1] == nil then
        if currentSpeed ~= normalSpeed then
            vlc.var.set(input, "rate", normalSpeed)
        end
        return nil  --check for the last subs and avoid error with the table subtitles
    elseif actual_time < subtitles[1][1] then --avoid loop while waiting the first sub
        --vlc.msg.dbg("FIRST SUB")
        if currentSpeed ~= normalSpeed then
            vlc.var.set(input, "rate", normalSpeed)
        end
        return 1
    elseif actual_time >= subtitles[my_index][1] and actual_time<=subtitles[my_index][2] then
        --vlc.msg.dbg("IN THE SUB")
        if currentSpeed ~= updatedSpeed then
            vlc.var.set(input, "rate", updatedSpeed)
        end
        return my_index --if find the next sub return the index and avoid the while
    elseif actual_time > subtitles[my_index][2] and actual_time < subtitles[my_index + 1][1] then
        --vlc.msg.dbg("BETWEEN 2 SUB")
        if (subtitles[my_index + 1][1] - subtitles[my_index][2]) < MAXTIMEDIFFERENCE then
            return my_index --don't change the rate if two subs are near
        elseif currentSpeed ~= normalSpeed then
            vlc.var.set(input, "rate", normalSpeed)
        end
        return my_index --if we are in the middle from two consecutive subs return and avoid the while
    elseif actual_time >= subtitles[my_index + 1][1] and actual_time<=subtitles[my_index + 1][2] then
        --vlc.msg.dbg("NEXT SUB")
        vlc.var.set(input, "rate", updatedSpeed)
        return my_index + 1 --if we are in the next Sub update my_index
    else --if user change the elapsed time check all subs and wait for the new index
        if not ((actual_time>=subtitles[my_index][1] and actual_time<=subtitles[my_index][2]) or actual_time<=subtitles[my_index][1]) then
            while subtitles[i] do
                if actual_time>=subtitles[i][1] and actual_time<=subtitles[i][2] then
                    if currentSpeed ~= updatedSpeed then
                        vlc.var.set(input, "rate", updatedSpeed)
                    end
                    return i
                elseif actual_time<=subtitles[i][1] then
                    return i
                end
                i = i + 1
            end
        end
    end

    if currentSpeed ~= normalSpeed then
        vlc.var.set(input, "rate", normalSpeed)
    end
    return my_index
end

function get_elapsed_time()
    local input = vlc.object.input()
    --VLC 3 : elapsed_time must be divided by 1000000 -> to seconds
    --VLC2.1+ : Don't need the division -> already in seconds
    local elapsed_time = vlc.var.get(input, "time") / 1000000

    return elapsed_time
end

function set_video_speed(mySpeed)
    local rateFactor = nil

    rateFactor = tonumber(cfg.general.rate)
    if rateFactor ~= nil then
        --vlc.msg.dbg("updateRate: ".. rateFactor .. type(rateFactor))
        return mySpeed * rateFactor
    else
        --This option is true when extension is off so keep the rate to 1
        return 1
    end
end
--*****************************ENDOF SLOWSPEED*********************************


--*********************************LOOPER**************************************
function looper()
    local last_index = 1
    local curi=nil

    cfg = load_config()
    cfg.general.rate = 1
    cfg.status.restarted = true
    save_config(cfg)

    while true do
        if vlc.volume.get() == -256 then -- inspired by syncplay.lua; kills vlc.exe process in Task Manager
            break
        end
        cfg = load_config()
        if vlc.playlist.status()=="stopped" then -- no input or stopped input
            if curi then -- input stopped
                log_msg("stopped")
                curi=nil
            end
            sleep(1)
        else -- playing, paused
            local uri=nil
            if vlc.input.item() then
                uri=vlc.input.item():uri()
            end
            if not uri then
                log_msg("Playlist status: " .. vlc.playlist.status())
                sleep(0.1)
            elseif not curi or curi~=uri then -- new input (first input or changed input)
                curi=uri
                subs_ready = load_subtitles() --Update subtitles for the new video
                log_msg(curi)
            else -- current input
                if vlc.playlist.status()=="playing" then
                    --Call the function only when the video is playing
                    if subs_ready then
                        last_index = rate_adjustment(last_index)
                        if last_index == nil then
                            sleep(0.3)
                        end
                    else
                        subs_ready = load_subtitles()
                        sleep(0.3)
                        --vlc.msg.dbg("last_index value: "..last_index)
                    end
                    --log_msg("playing")
                elseif vlc.playlist.status()=="paused" then
                    --log_msg("paused")
                    sleep(0.3)
                else -- ?
                    log_msg("unknown. Playlist status: ".. vlc.playlist.status())
                    sleep(1)
                end
                sleep(0.1)
            end
        end
    end
end

function log_msg(lm)
    vlc.msg.info("[Slowsub looper_intf] " .. lm)
end

function sleep(st) -- seconds
    vlc.misc.mwait(vlc.misc.mdate() + st*1000000)
end

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
    data.general.rate = 1
    data.status = {}
    data.status.restarted = true
    return data
end
--- MAIN ---

looper()

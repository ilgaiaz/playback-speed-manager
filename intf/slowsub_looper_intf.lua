--[[----- Slow sub ------------------------
"slowsub_looper_intf.lua" - Put this VLC Interface Lua script file in \lua\intf\ folder
--------------------------------------------
Requires "slowsub.lua" > Put the VLC Extension Lua script file in \lua\extensions\ folder

* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=slowsub_looper_intf
* Otherwise the Extension script (First run: "Time > SETTINGS" dialog box) will help you to set appropriate VLC preferences for automatic activation of the Interface script or you can do it manually:
VLC Preferences:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [slowsub_looper_intf]
Then use the Extension ("Slowsub" dialog box) to control the active Interface script.
The installed Extension is available in VLC menu "View" or "Vlc > Extensions" on Mac OS X.

INSTALLATION directory:
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
* Windows (current user): %APPDATA%\VLC\lua\intf\
* Linux (all users): /usr/lib/vlc/lua/intf/
* Linux (current user): ~/.local/share/vlc/lua/intf/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/
--]]----------------------------------------

config={}
--config.TIME={} -- subtable reserved for TIME extension
config.SLOWSUB={} -- subtable reserved for slowsub extension
--Load subs variables
subtitles_uri = nil -- "file:///D:/films/subtitles.srt"
charset = "Windows-1250" -- nil or "UTF-8", "ISO-8859-2", ...
filename_extension = "srt" -- "eng.srt", "srt-vlc", ...
--Speed video variables
rateFactor = nil            --dafault
normalSpeed = 1.0
slowSpeed = nil--normalSpeed/rateFactor
maxTimeDifference = 3 --Time in seconds
--Rate table conversion
rateTable = {["0,9x"]=1.1,["0,83x"]=1.2,["0,77x"]=1.3,["0,71x"]=1.4,["0,66x"]=1.5,["0,625x"]=1.6,["0,58x"]=1.7,["0,55x"]=1.8,["0,52"]=1.9,["0,5x"]=2.0}
    

--**********************LOAD SUBS****************************
function Load_subtitles()
    --future implementation
    --Get_config()
    --if config.SLOWSUB.path then subtitles_uri = config.SLOWSUB.path end
        
	if subtitles_uri==nil then subtitles_uri=media_path(filename_extension) end
-- read file
	local s = vlc.stream(subtitles_uri)
	if s==nil then return false end
    --Read max 500000 chars -> enough
	data = s:read(500000)
    --replace the "\r" char with an empty char
	data = string.gsub( data, "\r", "")
	-- UTF-8 BOM detection
	if string.char(0xEF,0xBB,0xBF)==string.sub(data,1,3) then charset=nil end
-- parse datavlc.object.
	subtitles={}
	srt_pattern = "(%d%d):(%d%d):(%d%d),(%d%d%d) %-%-> (%d%d):(%d%d):(%d%d),(%d%d%d).-\n(.-)\n\n"
    --Find string match for find time value in the srt file
	for h1, m1, s1, ms1, h2, m2, s2, ms2, text in string.gmatch(data, srt_pattern) do
        --If the text is empty then add a space
		if text=="" then text=" " end
		if charset~=nil then text=vlc.strings.from_charset(charset, text) end
        --Add value start/stop time and text in the table subtitles
		table.insert(subtitles,{format_time(h1, m1, s1, ms1), format_time(h2, m2, s2, ms2), text})
	end
    
    if #subtitles~=0 then return true else return false end
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
function Pause_detection(my_index)
    local i = 1
    local input = vlc.object.input()
    local currentSpeed = vlc.var.get(input,"rate")
    
    Get_rate() --verify if user change the rate
        
    actual_time = Get_elapsed()
    vlc.msg.dbg("Current rate: "..vlc.var.get(input,"rate"))
    if my_index == nil then
        if currentSpeed ~= normalSpeed then vlc.var.set(input, "rate", normalSpeed) end
        return nil  --Avoid some rare case of error when user change the elapsed time
    elseif  subtitles[my_index + 1] == nil then
        if currentSpeed ~= normalSpeed then vlc.var.set(input, "rate", normalSpeed) end
        return nil  --check for the last subs and avoid error with the table subtitles
    elseif actual_time < subtitles[1][1] then --avoid loop while waiting the first sub 
        --vlc.msg.dbg("FIRST SUB")
        if currentSpeed ~= normalSpeed then vlc.var.set(input, "rate", normalSpeed) end
        return 1
    elseif actual_time >= subtitles[my_index][1] and actual_time<=subtitles[my_index][2] then
        --vlc.msg.dbg("IN THE SUB")
        if currentSpeed ~= slowSpeed then vlc.var.set(input, "rate", slowSpeed) end
        return my_index --if find the next sub return the index and avoid the while
    elseif actual_time > subtitles[my_index][2] and actual_time < subtitles[my_index + 1][1] then
        --vlc.msg.dbg("BETWEEN 2 SUB")
        if (subtitles[my_index + 1][1] - subtitles[my_index][2]) < maxTimeDifference then
            return my_index --don't change the rate if two subs are near 
        elseif currentSpeed ~= normalSpeed then 
            vlc.var.set(input, "rate", normalSpeed) 
        end
        return my_index --if we are in the middle from two consecutive subs return and avoid the while
    elseif actual_time >= subtitles[my_index + 1][1] and actual_time<=subtitles[my_index + 1][2] then
        --vlc.msg.dbg("NEXT SUB")
        vlc.var.set(input, "rate", slowSpeed)
        return my_index + 1 --if we are in the next Sub update my_index
    else --if user change the elapsed time check all subs and wait for the new index
        while subtitles[i] do
            if actual_time>=subtitles[i][1] and actual_time<=subtitles[i][2] then
                if currentSpeed ~= slowSpeed then vlc.var.set(input, "rate", slowSpeed) end
                return i + 1
            end
        i = i + 1
        end
    end
    
    if currentSpeed ~= normalSpeed then vlc.var.set(input, "rate", normalSpeed) end
    return my_index
end

function Get_elapsed()
    local input = vlc.object.input()
    --VLC 3 : elapsed_time must be divided by 1000000
    --VLC2.1+ : Don't need the division 
    local elapsed_time = vlc.var.get(input, "time") / 1000000

    return elapsed_time
end

function Get_rate()
    if config.SLOWSUB then 
        local newRate = config.SLOWSUB.rate
        rateFactor = rateTable[newRate]
    else
        return
    end
    if rateFactor ~= nil then
        --vlc.msg.dbg("updateRate: ".. updateRate .. type(updateRate))
        slowSpeed = normalSpeed / rateFactor
    else
        --This option is true when extension is off so keep the rate to 1
        slowSpeed = 1
    end
end
--*****************************ENDOF SLOWSPEED*********************************
        
        
--*********************************LOOPER**************************************
function Looper()
    local last_index = 1
	local curi=nil
	local loops=0 -- counter of loops
    
    Load_subtitles()
    
	while true do
		if vlc.volume.get() == -256 then break end  -- inspired by syncplay.lua; kills vlc.exe process in Task Manager
		Get_config()
--		config.SLOWSUB={time_format="[E1]",osd_position="bottom-left"}

		if vlc.playlist.status()=="stopped" then -- no input or stopped input
			if curi then -- input stopped
				Log("stopped")
				curi=nil
			end
			loops=loops+1
			Log(loops)
			Sleep(1)
		else -- playing, paused
			local uri=nil
			if vlc.input.item() then uri=vlc.input.item():uri() end
			if not uri then --- WTF (VLC 2.1+): status playing with nil input? Stopping? O.K. in VLC 2.0.x
				Log("Playlist status: " .. vlc.playlist.status())
				Sleep(0.1)
			elseif not curi or curi~=uri then -- new input (first input or changed input)
				curi=uri
                Load_subtitles() --Update subtitles for the new video
				Log(curi)
			else -- current input
				if vlc.playlist.status()=="playing" then
                    --Call the function only when the video is playing
                    if config.SLOWSUB then 
                        last_index = Pause_detection(last_index)
                        if last_index == nil then Sleep(0.3) end
                        --vlc.msg.dbg("last_index value: "..last_index)
                    end
					--Log("playing")
				elseif vlc.playlist.status()=="paused" then
					--Log("paused")
					Sleep(0.3)
				else -- ?
					Log("unknown")
					Sleep(1)
				end
				Sleep(0.1)
			end
		end
	end
end

function Log(lm)
	vlc.msg.info("[looper_intf] " .. lm)
end

function Sleep(st) -- seconds
	vlc.misc.mwait(vlc.misc.mdate() + st*1000000)
end

function Get_config()
	local s = vlc.config.get("bookmark10")
	if not s or not string.match(s, "^config={.*}$") then s = "config={}" end
	assert(loadstring(s))() -- global var
end

--- XXX --- SLOWSUB ---
        
--future implementation check if sub file is ready
--Get_config()
--subs_ready = config.SLOWSUB.ready == false 
--add a loop until video start'

while vlc.playlist.status() == "stopped" do
    --Get_config()
    --Load_subtitles()
    Sleep(1) 
end
--and Load_subtitles()
Looper()

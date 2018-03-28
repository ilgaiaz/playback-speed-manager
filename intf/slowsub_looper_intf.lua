--[[----- TIME v3.0 ------------------------
"looper_intf.lua" - Put this VLC Interface Lua script file in \lua\intf\ folder
--------------------------------------------
Requires "time_ext.lua" > Put the VLC Extension Lua script file in \lua\extensions\ folder

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
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
* Windows (current user): %APPDATA%\VLC\lua\intf\
* Linux (all users): /usr/lib/vlc/lua/intf/
* Linux (current user): ~/.local/share/vlc/lua/intf/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/
--]]----------------------------------------

config={}
config.TIME={} -- subtable reserved for TIME extension

function Load_subtitles()
	if subtitles_uri==nil then subtitles_uri=media_path(filename_extension) end
-- read file
    --istanzia un oggetto stream all'indirizzo passato
	local s = vlc.stream(subtitles_uri)
	if s==nil then return false end
    --legge fino a 500000 caratteri ritorna 0 se non ci sono più dati presenti
	data = s:read(500000)
    --sostituiamo gli a capo "\r" con una stringa vuota (c'era un problema segnalato nei commenti)
	data = string.gsub( data, "\r", "")
	-- UTF-8 BOM detection
	if string.char(0xEF,0xBB,0xBF)==string.sub(data,1,3) then charset=nil end
-- parse datavlc.object.
	subtitles={}
	srt_pattern = "(%d%d):(%d%d):(%d%d),(%d%d%d) %-%-> (%d%d):(%d%d):(%d%d),(%d%d%d).-\n(.-)\n\n"
    --cerco le stringhe corrispondenti di tempo inizio/fine dei subs e faccio un ciclo
	for h1, m1, s1, ms1, h2, m2, s2, ms2, text in string.gmatch(data, srt_pattern) do
        --al testo vuoto assegno almeno uno spazio (non so perché)
		if text=="" then text=" " end
		if charset~=nil then text=vlc.strings.from_charset(charset, text) end
        --comando che inserisce i campi "tempo inizio/fine" e "testo" nella tabella globale "subtitles"
        --che poi posso riutilizzare dopo
		table.insert(subtitles,{format_time(h1, m1, s1, ms1), format_time(h2, m2, s2, ms2), text})
	end
	if #subtitles~=0 then return true else return false end
end

function format_time(h,m,s,ms) -- time to seconds
	return tonumber(h)*3600+tonumber(m)*60+tonumber(s) -- +tonumber("."..ms)
end

function Looper()
	local curi=nil
	local loops=0 -- counter of loops
	while true do
		if vlc.volume.get() == -256 then break end  -- inspired by syncplay.lua; kills vlc.exe process in Task Manager
		Get_config()
--		config.TIME={time_format="[E1]",osd_position="bottom-left"}

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
				Log("WTF??? " .. vlc.playlist.status())
				Sleep(0.1)
			elseif not curi or curi~=uri then -- new input (first input or changed input)
				curi=uri
				Log(curi)
			else -- current input
				if not config.TIME or config.TIME.stop~=true then TIME_Loop() end
				if vlc.playlist.status()=="playing" then
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

--- TIME ---

TIME_time_format = "[E] / [D][_]([T])"
TIME_osd_position = "top-right"

function TIME_Loop()
	if config.TIME then
		TIME_time_format = config.TIME.time_format or TIME_time_format
		TIME_osd_position = config.TIME.osd_position or TIME_osd_position
	end
	local osd_output = TIME_Decode_time_format()
	vlc.osd.message(osd_output, 1111111111, TIME_osd_position)
end

function TIME_Decode_time_format()
-- TODO: rewrite/improve this old code; autoformat (s > m:s > h:m:s);
	local input = vlc.object.input()

	local elapsed_time = vlc.var.get(input, "time")/1000000
	--local duration = vlc.var.get(input, "length")
	local duration = vlc.input.item():duration()

	local systemHour = os.date("%H")
	local systemMinute = os.date("%M")
	local systemSecond = os.date("%S")

	local elapsedHour = math.floor(elapsed_time / 3600)
	local elapsedMinute = math.floor((elapsed_time % 3600) / 60)
	local elapsedSecond = elapsed_time % 60

	local remaining_time
	local ending_time
	if duration>0 then
---
		local rate = vlc.var.get(vlc.object.input(),"rate")
		duration = duration/rate
---
		local durationHour = math.floor(duration / 3600)
		local durationMinute = math.floor((duration % 3600) / 60)
		local durationSecond = math.floor(duration % 60)

		remaining_time = duration - elapsed_time
		local remainingHour = math.floor(remaining_time / 3600)
		local remainingMinute = math.floor((remaining_time % 3600) / 60)
		local remainingSecond = math.floor(remaining_time % 60)

		local endingSecond = math.floor((systemSecond + remainingSecond) % 60)
		local endingMinute = math.floor(((systemSecond + remainingSecond) / 60 + (systemMinute + remainingMinute)) % 60)
		local endingHour = math.floor((((systemSecond + remainingSecond) / 60 + (systemMinute + remainingMinute)) / 60 + systemHour + remainingHour) % 24)
		duration = string.format("%02d:%02d:%02d", durationHour, durationMinute, durationSecond)
---
		if rate~=1 then duration = duration .. " ("..string.format("%3.1f", rate).."x)" end
---
		remaining_time = string.format("%02d:%02d:%02d", remainingHour, remainingMinute, remainingSecond)
		ending_time = string.format("%02d:%02d:%02d", endingHour, endingMinute, endingSecond)
	else
		duration = "--:--"
		remaining_time = "--:--"
		ending_time = "--:--"
	end

	local et = elapsed_time

	local elapsed_time = string.format("%02d:%02d:%06.3f", elapsedHour, elapsedMinute, elapsedSecond)
	--local system_time = os.date("%H:%M:%S")
	local system_time = systemHour..":"..systemMinute..":"..systemSecond

	local osd_output = string.gsub(TIME_time_format, "%[E%]", elapsed_time)
	local osd_output = string.gsub(osd_output, "%[T%]", system_time)
	local osd_output = string.gsub(osd_output, "%[D%]", duration)
	local osd_output = string.gsub(osd_output, "%[R%]", remaining_time)
	local osd_output = string.gsub(osd_output, "%[O%]", ending_time)

	local osd_output = string.gsub(osd_output, "%[n%]", vlc.input.item():name())

	local osd_output = string.gsub(osd_output, "%[_%]", "\n")
	local fps=tonumber(string.match(osd_output,"%[E(.-)%]"))
	if fps~=nil then
--		osd_output = string.gsub(osd_output, "%[E.-%]", math.floor(et * fps))
		osd_output = string.gsub(osd_output, "%[E.-%]", string.format("%.3f", et * fps))
	end

	return osd_output
end

--- XXX --- TIME ---

Looper()

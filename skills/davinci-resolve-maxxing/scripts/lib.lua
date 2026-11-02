-- R: helpers for driving free DaVinci Resolve 21.1 through the Lua Console bridge.
-- bridge.lua loads this as the global `R` (reload with R = reload()).
-- Every helper encodes a rule measured on free 21.1.1 Linux; see references/gotchas.md.
-- Frames are RELATIVE to the timeline start (0 = first frame) unless a name says otherwise.
local R = {}
local HOME = os.getenv("HOME")
R.dir = HOME .. "/resolve-bridge/"
R.templates = R.dir .. "templates/"  -- built-in Fusion templates unpacked by install.sh: R.fx(item, R.templates .. "Edit/Effects/CCTV.setting")
R.assets = R.dir .. "assets/"
R.effects = R.dir .. "fx/"  -- the skill's ready-made effect presets (assets/fx, linked by install.sh): R.fx(item, R.effects .. "glitch.setting")

-- ── handles ──────────────────────────────────────────────────────────────────
function R.pm() return resolve:GetProjectManager() end
function R.project() return R.pm():GetCurrentProject() end
function R.mp() return R.project():GetMediaPool() end
function R.tl() return R.project():GetCurrentTimeline() end
function R.save() return R.pm():SaveProject() end

local function page(name) if resolve:GetCurrentPage() ~= name then resolve:OpenPage(name) end end

-- ── media pool ───────────────────────────────────────────────────────────────
-- Clip by exact name, searching every bin. Prefers clips backed by a file: compound clips and imported
-- timelines can carry the same name (a compound "talk_b.mov" shadowed the real file once).
function R.find(name, folder)
  local fallback
  local function walk(f)
    for _, c in ipairs(f:GetClipList()) do
      if c:GetName() == name then
        if (c:GetClipProperty("File Path") or "") ~= "" then return c end
        fallback = fallback or c
      end
    end
    for _, s in ipairs(f:GetSubFolderList()) do local r = walk(s) if r then return r end end
  end
  return walk(folder or R.mp():GetRootFolder()) or fallback
end

-- Bin under the root, created if missing.
function R.bin(name)
  local root = R.mp():GetRootFolder()
  for _, f in ipairs(root:GetSubFolderList()) do if f:GetName() == name then return f end end
  return R.mp():AddSubFolder(root, name)
end

-- Import files into a bin. Reuses clips already in the pool (matched by file path).
-- Warns on media Resolve cannot decode (Linux free: H.264/HEVC/AAC import "succeeds" with no resolution).
-- The media-pool clip of this exact FILE (any bin), or nil.
function R.find_path(path)
  local function walk(f)
    for _, c in ipairs(f:GetClipList()) do if c:GetClipProperty("File Path") == path then return c end end
    for _, s in ipairs(f:GetSubFolderList()) do local r = walk(s) if r then return r end end
  end
  return walk(R.mp():GetRootFolder())
end

function R.import(paths, bin)
  local mp, out = R.mp(), {}
  if bin then mp:SetCurrentFolder(R.bin(bin)) end
  local todo = {}
  for _, p in ipairs(paths) do
    -- reuse by FILE PATH (a same-named file elsewhere is a different clip); a reused clip stays in its bin
    local have = R.find_path(p)
    if have then out[#out + 1] = have else todo[#todo + 1] = p end
  end
  if #todo > 0 then
    for _, it in ipairs(mp:ImportMedia(todo) or {}) do
      out[#out + 1] = it
      local t = it:GetClipProperty("Type") or ""
      if (t:find("Video") or t == "") and (it:GetClipProperty("Resolution") or "") == "" then
        print("WARN undecodable on this OS (transcode to ProRes): " .. it:GetName())
      end
    end
  end
  mp:SetCurrentFolder(mp:GetRootFolder())
  return out
end

-- ── timelines ────────────────────────────────────────────────────────────────
function R.fps(tl) return math.floor(tonumber((tl or R.tl()):GetSetting("timelineFrameRate")) + 0.5) end

-- Clip length in frames. Audio-only clips have no "Frames" property, only Duration (TC at the clip's FPS).
function R.frames(clip)
  local n = tonumber(clip:GetClipProperty("Frames"))
  if n then return n end
  local h, m, s, f = clip:GetClipProperty("Duration"):match("(%d+):(%d+):(%d+)[:;](%d+)")
  local fps = math.floor(tonumber(clip:GetClipProperty("FPS")) + 0.5)
  return ((tonumber(h) * 60 + tonumber(m)) * 60 + tonumber(s)) * fps + tonumber(f)
end

-- Any value -> short readable string (tables to depth 2). For dumping API returns.
function R.ser(v, d)
  d = d or 0
  if type(v) ~= "table" then return tostring(v) end
  if d > 2 then return "{...}" end
  local s = {}
  for k, x in pairs(v) do
    if k ~= "__flags" then s[#s + 1] = tostring(k) .. "=" .. R.ser(x, d + 1) end
    if #s > 60 then s[#s + 1] = "..." break end
  end
  table.sort(s)
  return "{" .. table.concat(s, ", ") .. "}"
end

-- Relative frame -> timecode string (non-drop, integer fps).
function R.tc(tl, rel)
  tl = tl or R.tl()
  local fps = R.fps(tl)
  local h, m, s, f = tl:GetStartTimecode():match("(%d+):(%d+):(%d+)[:;](%d+)")
  local n = ((tonumber(h) * 60 + tonumber(m)) * 60 + tonumber(s)) * fps + tonumber(f) + rel
  local fl = math.floor  -- LuaJIT is Lua 5.1: no // operator
  return string.format("%02d:%02d:%02d:%02d", fl(n / (3600 * fps)), fl(n / (60 * fps)) % 60, fl(n / fps) % 60, n % fps)
end

-- New timeline (unique name: CreateEmptyTimeline returns nil on a duplicate name).
-- o.w/o.h give it its own resolution (vertical timelines inside a 16:9 project work).
-- Project fps can only change while the project has NO timelines: set it before the first one.
-- o.crop = true: other-aspect sources fill the frame (scaleToCrop) and R.frame() picks what shows.
function R.timeline(name, o)
  o = o or {}
  local p, mp = R.project(), R.mp()
  if o.fps and p:GetTimelineCount() == 0 then p:SetSetting("timelineFrameRate", tostring(o.fps)) end
  local base, n, tl = name, 1, nil
  repeat
    tl = mp:CreateEmptyTimeline(name)
    if not tl then n = n + 1; name = base .. " " .. n end
  until tl or n > 50
  assert(tl, "could not create timeline " .. base)
  p:SetCurrentTimeline(tl)
  if o.w and o.h then
    tl:SetSetting("useCustomSettings", "1")
    tl:SetSetting("timelineResolutionWidth", tostring(o.w))
    tl:SetSetting("timelineResolutionHeight", tostring(o.h))
  end
  if o.crop then tl:SetSetting("timelineInputResMismatchBehavior", "scaleToCrop") end
  R.tracks(tl, "video", o.video or 1)
  R.tracks(tl, "audio", o.audio or 1)
  return tl
end

function R.open(name)
  local p = R.project()
  for i = 1, p:GetTimelineCount() do
    local t = p:GetTimelineByIndex(i)
    if t:GetName() == name then p:SetCurrentTimeline(t) return t end
  end
end

-- Make sure the timeline has at least n tracks of kind ("video"/"audio"/"subtitle").
-- A trackIndex that does not exist makes AppendToTimeline drop the clip at the END of track 1.
function R.tracks(tl, kind, n)
  while tl:GetTrackCount(kind) < n do tl:AddTrack(kind, kind == "audio" and "stereo" or nil) end
end

-- Place a clip. o: track(1), at(rel frame, 0), from(source in, 0), len(frames, default rest of clip),
-- media ("video" | "audio" | nil = both, linked). endFrame is EXCLUSIVE; recordFrame is absolute.
-- Returns the placed items (video first) and errors if Resolve put them somewhere else.
function R.place(tl, clip, o)
  o = o or {}
  if type(clip) == "string" then clip = assert(R.find(clip), "no clip " .. clip) end
  local from = o.from or 0
  local total = R.frames(clip)
  local len = o.len or (total - from)
  -- past the source end AppendToTimeline still "succeeds" with a frozen last frame and no handles
  assert(from + len <= total, string.format("%s: source range %d+%d is past its %d frames", clip:GetName(), from, len, total))
  local track, at = o.track or 1, o.at or 0
  local mtype = ({video = 1, audio = 2})[o.media or ""]
  if mtype ~= 2 then R.tracks(tl, "video", track) end
  if mtype ~= 1 then R.tracks(tl, "audio", o.atrack or track) end
  local info = {mediaPoolItem = clip, startFrame = from, endFrame = from + len, recordFrame = tl:GetStartFrame() + at, trackIndex = track}
  if mtype then info.mediaType = mtype end
  local got = R.mp():AppendToTimeline({info}) or {}
  assert(#got > 0, "AppendToTimeline placed nothing for " .. clip:GetName())
  -- AppendToTimeline returns one item per request; linked audio comes back via GetLinkedItems
  for _, l in ipairs(got[1]:GetLinkedItems() or {}) do got[#got + 1] = l end
  local s = got[1]:GetStart() - tl:GetStartFrame()
  if s ~= at then  -- the spot was taken (Resolve appends at the track end instead): undo, then fail
    tl:DeleteClips(got, false)
    error(string.format("%s landed at %d, wanted %d (track %d): range occupied?", clip:GetName(), s, at, track))
  end
  return got
end

-- Frame a subject in a clip that is wider than the timeline (16:9 source in a 9:16 timeline made with
-- R.timeline{crop = true}): x = subject's horizontal position as a fraction of the SOURCE width (read it off a
-- frame of the source), zoom >= 1. Pan units are timeline pixels: Pan = (0.5 - x) * timeline_width * zoom
-- (pixel-verified). x is clamped so no black edge shows. Set per cut when the speaker moves.
function R.frame(item, x, zoom)
  zoom = zoom or 1.0
  local tl = R.tl()
  local tw, th = tonumber(tl:GetSetting("timelineResolutionWidth")), tonumber(tl:GetSetting("timelineResolutionHeight"))
  local sw, sh = (item:GetMediaPoolItem():GetClipProperty("Resolution") or ""):match("(%d+)x(%d+)")
  if sw then
    local vis = math.min(1, (tw / th) / (tonumber(sw) / tonumber(sh))) / zoom  -- visible fraction of source width
    x = math.max(vis / 2, math.min(1 - vis / 2, x))
  end
  item:SetProperties({ZoomX = zoom, ZoomY = zoom, Pan = (0.5 - x) * tw * zoom})
  return x
end

-- Lay source ranges back to back (jump cuts): silence removal, selects, beat-cut montages.
-- ranges = {{in, out}, ...} source frames (out exclusive), e.g. analyze.py silence keep_f.
-- o: track(1), at(0), media(nil = video+audio). Returns the placed video items.
function R.keep(tl, clip, ranges, o)
  o = o or {}
  if type(clip) == "string" then clip = assert(R.find(clip), "no clip " .. clip) end
  local at, out = o.at or 0, {}
  for _, r in ipairs(ranges) do
    local len = r[2] - r[1]
    if len > 0 then
      out[#out + 1] = R.place(tl, clip, {track = o.track, at = at, from = r[1], len = len, media = o.media})[1]
      at = at + len
    end
  end
  return out, at
end

-- Items on one track, ordered as Resolve returns them.
function R.items(tl, kind, track) return (tl or R.tl()):GetItemListInTrack(kind or "video", track or 1) or {} end

-- Human-readable map of the whole timeline.
function R.dump(tl)
  tl = tl or R.tl()
  if not tl then return "project '" .. R.project():GetName() .. "': no current timeline (" .. R.project():GetTimelineCount() .. " timelines)" end
  local t0, rows = tl:GetStartFrame(), {tl:GetName() .. "  " .. tl:GetSetting("timelineResolutionWidth") .. "x" .. tl:GetSetting("timelineResolutionHeight") .. " @" .. R.fps(tl)}
  for _, k in ipairs({"video", "audio", "subtitle"}) do
    for t = 1, tl:GetTrackCount(k) do
      for _, it in ipairs(tl:GetItemListInTrack(k, t)) do
        rows[#rows + 1] = string.format("%s%d  %5d-%5d  %s%s", k:sub(1, 1):upper(), t, it:GetStart() - t0, it:GetEnd() - t0,
          it:GetName(), (k == "video" and it:GetFusionCompCount() > 0) and "  [fusion]" or "")
      end
    end
  end
  return table.concat(rows, "\n")
end

-- ── Fusion: fonts, titles, motion ────────────────────────────────────────────
-- Fusion only scans /usr/share/fonts. A missing font renders NOTHING and raises no error,
-- so every text helper checks the family first.
function R.has_font(family)
  local fm = resolve:Fusion().FontManager
  if fm:GetFontList()[family] then return true end
  fm:ScanDir(HOME .. "/.local/share/fonts/")
  return fm:GetFontList()[family] ~= nil
end

-- Easing = CSS cubic-bezier {x1, y1, x2, y2} per segment. Fusion stores Bezier handles RELATIVE to their key
-- ({dframes, dvalue}); script-set keys get "linear" handles (a third of the way to the neighbour key).
R.EASE = {linear = {1/3, 1/3, 2/3, 2/3}, inout = {0.42, 0, 0.58, 1}, ["in"] = {0.42, 0, 1, 1}, out = {0, 0, 0.58, 1},
  smooth = {1/3, 0, 2/3, 1}, snap = {0.16, 1, 0.3, 1}, back = {0.34, 1.56, 0.64, 1}, hold = "hold"}
local function shape(sp, e)
  local k, fs = sp:GetKeyFrames(), {}
  for f in pairs(k) do fs[#fs + 1] = f end
  table.sort(fs)
  for i = 1, #fs - 1 do
    local a, b = fs[i], fs[i + 1]
    local dx, dy = b - a, k[b][1] - k[a][1]
    if e == "hold" then k[b].Flags = {StepIn = true}  -- StepIn on the LATER key holds the earlier value until it
    else
      k[a].RH = {e[1] * dx, e[2] * dy}
      k[b].LH = {(e[3] - 1) * dx, (e[4] - 1) * dy}
    end
  end
  sp:SetKeyFrames(k, true)
end

-- frames = {{frame, value}, ..., ease = "out"}; adds to existing animation. ease: a name in R.EASE or {x1, y1, x2, y2}
-- (applied to every segment of this input; Center/XYPath eases X and Y).
local function key(tool, input, frames, ease)
  if not tool[input]:GetConnectedOutput() then
    tool:AddModifier(input, tool[input]:GetAttrs().INPS_DataType == "Point" and "XYPath" or "BezierSpline")
  end
  for _, kv in ipairs(frames) do tool[input][kv[1]] = kv[2] end
  if tool.ID:match("^ofx%.") then print("R.key: live keys on a ResolveFX render as a static value; key it through R.fx(item, id, {p = {{f, v}...}}) or R.save_fx + R.fx(file)") end
  ease = ease or frames.ease
  if ease then
    local e, m = type(ease) == "table" and ease or assert(R.EASE[ease], "unknown ease " .. tostring(ease)), tool[input]:GetConnectedOutput():GetTool()
    if m.ID == "XYPath" then shape(m.X:GetConnectedOutput():GetTool(), e); shape(m.Y:GetConnectedOutput():GetTool(), e) else shape(m, e) end
  end
end
R.key = key

-- Transparent carrier clip for titles at the timeline's resolution and fps (made by install.sh / prep.py carriers).
function R.carrier(tl)
  local w, h = tl:GetSetting("timelineResolutionWidth"), tl:GetSetting("timelineResolutionHeight")
  local path = R.assets .. "carrier_" .. w .. "x" .. h .. "_" .. R.fps(tl) .. ".mov"
  local ok, item = pcall(function() return R.import({path}, "_carriers")[1] end)
  return assert(ok and item, "missing carrier " .. path .. " (run: prep.py carriers " .. w .. "x" .. h .. " --fps " .. R.fps(tl) .. " --out " .. R.assets .. ")")
end

-- Title on its own track with exact timing. NEVER use InsertTitleIntoTimeline/InsertFusionTitleIntoTimeline
-- on a real edit: they ripple-insert 5 s on V1 at the playhead.
-- o: text, at, len, track(2), font/style (default R.default_font()), size (Text+ Size, a fraction of frame WIDTH; 16:9: 0.05 caption, 0.08 subhead, 0.16 headline; 9:16: 0.2 line, 0.55 full-width word),
--    color{r,g,b}, center{x,y} (0..1, y up), tracking(0), outline{r,g,b,thickness} (doesn't stick in the same rv call: set it again, gotchas.md),
--    anim: "pop" (default) | "fade" | "type" | "words" | "rise" | "slide" | "none"; speed = frames (per line, word or letter)
-- Returns item, comp, text tool.
-- First bold sans Fusion can see (Open Sans is NOT installed on stock Ubuntu; DejaVu Sans is).
function R.default_font()
  for _, f in ipairs({"Open Sans", "Inter", "DejaVu Sans", "Helvetica Neue", "Arial"}) do
    if R.has_font(f) then return f, "Bold" end
  end
  error("no default font visible to Fusion")
end

function R.title(tl, o)
  local font, style = o.font, o.style
  if not font then font, style = R.default_font() end
  style = style or "Bold"
  assert(R.has_font(font), "Fusion cannot see font '" .. font .. "' (install it, then R.has_font)")
  local item = R.place(tl, R.carrier(tl), {track = o.track or 2, at = o.at, len = o.len, media = "video"})[1]
  local comp = item:AddFusionComp()  -- never comp:Lock(): writes inside Lock do not render
  local txt, mrg = comp:AddTool("TextPlus"), comp:AddTool("Merge")
  local c = o.color or {1, 1, 1}
  txt:SetInput("StyledText", o.text)
  txt:SetInput("Font", font); txt:SetInput("Style", style)
  txt:SetInput("Size", o.size or 0.08)
  txt:SetInput("Red1", c[1]); txt:SetInput("Green1", c[2]); txt:SetInput("Blue1", c[3])
  if o.tracking then txt:SetInput("CharacterSpacing", 1 + o.tracking) end
  if o.center then txt:SetInput("Center", {o.center[1], o.center[2]}) end
  if o.outline then
    local ol = o.outline
    txt:SetInput("Enabled2", 1); txt:SetInput("Thickness2", ol[4] or 0.05)
    txt:SetInput("Red2", ol[1]); txt:SetInput("Green2", ol[2]); txt:SetInput("Blue2", ol[3])
  end
  mrg.Background = comp:FindTool("MediaIn1").Output
  mrg.Foreground = txt.Output
  comp:FindTool("MediaOut1").Input = mrg.Output
  local size, a, n = o.size or 0.08, o.anim or "pop", #o.text
  if a == "pop" then
    key(txt, "Size", {{0, size * 1.45}, {5, size}, ease = "out"})
  elseif a == "fade" then
    key(mrg, "Blend", {{0, 0}, {8, 1}})
  elseif a == "type" then  -- typewriter: Text+ Write On End, o.speed frames for the whole line (default 1 char/frame)
    key(txt, "End", {{0, 0}, {o.speed or math.max(6, n), 1}})
  elseif a == "words" then  -- word by word, o.speed frames per word (Write On End jumps to each word's end and holds)
    local pts, i = {ease = "hold"}, 0
    for e in o.text:gmatch("%S+()") do pts[#pts + 1] = {i * (o.speed or 6), (e - 1) / n}; i = i + 1 end
    key(txt, "End", pts)
  elseif a == "rise" then  -- letters rise and fade in one after another (Follower modifier, o.speed frames apart)
    txt:AddModifier("StyledText", "StyledTextFollower")
    local fo = txt.StyledText:GetConnectedOutput():GetTool()
    fo:SetInput("Text", o.text); fo:SetInput("Delay", o.speed or 2)
    key(fo, "CharacterOffset", {{0, {0, -0.1}}, {10, {0, 0}}, ease = "out"})
    key(fo, "Opacity1", {{0, 0}, {10, 1}})
  elseif a == "slide" then  -- slides up into place and fades in
    local c = o.center or {0.5, 0.5}
    key(txt, "Center", {{0, {c[1], c[2] - 0.06}}, {10, c}, ease = "snap"})
    key(mrg, "Blend", {{0, 0}, {6, 1}})
  end
  return item, comp, txt
end

-- Reuse a saved .comp (item:ExportFusionComp) on a new carrier and retarget its first Text+.
function R.template(tl, comp_path, o)
  local item = R.place(tl, R.carrier(tl), {track = o.track or 2, at = o.at, len = o.len, media = "video"})[1]
  local comp = assert(item:ImportFusionComp(comp_path), "ImportFusionComp failed: " .. comp_path)
  local txt = comp:FindToolByID("TextPlus")
  if txt and o.text then txt:SetInput("StyledText", o.text) end
  return item, comp, txt
end

-- Read a whole file (the console has no io and no bmd.readfile; libc via ffi, declared by bridge.lua).
function R.readfile(p)
  local f = ffi.C.fopen(p, "rb")
  if f == nil then return nil end
  local buf, out = ffi.new("char[65536]"), {}
  repeat
    local n = tonumber(ffi.C.fread(buf, 1, 65536, f))
    out[#out + 1] = ffi.string(buf, n)
  until n < 65536
  ffi.C.fclose(f)
  return table.concat(out)
end

-- Splice any Fusion tool or ResolveFX into a clip's comp just before MediaOut1 (repeat calls chain).
-- id: a .setting file (macro or Effects template), a Fusion tool ID ("FilmGrain", "Transform", "SoftGlow") or OFX ID ("ofx.com.blackmagicdesign.resolvefx.Glow"; the 53
-- that work on free, with their params: references/effects-catalog.tsv). params: {InputID = value | {{frame, value}, ...}}.
-- ResolveFX take the image on "Source", Fusion tools on "Input": FindMainInput(1) finds either. Wiring "Input" on a
-- ResolveFX leaves it unconnected and the clip renders BLACK.
function R.fx(item, id, params)
  local comp = item:GetFusionCompCount() > 0 and item:GetFusionCompByIndex(1) or item:AddFusionComp()
  local mo = comp:FindTool("MediaOut1")
  local t, head
  if id:match("%.setting$") then  -- macro/template file: paste it; Paste leaves exactly the pasted top-level tools selected
    -- comp:Paste() returns false unless the comp is the one open in the Fusion page
    local tl, pg = R.tl(), resolve:GetCurrentPage()
    R.seek(tl, item:GetStart() - tl:GetStartFrame())  -- seek first: SetCurrentTimecode is ignored on the Fusion page
    -- the Fusion page opens the TOP enabled clip under the playhead: switch off the video tracks above this one meanwhile
    local off, ti = {}, item:GetTrackTypeAndIndex()[2]
    for i = ti + 1, tl:GetTrackCount("video") do
      if tl:GetIsTrackEnabled("video", i) then tl:SetTrackEnable("video", i, false); off[#off + 1] = i end
    end
    resolve:OpenPage("fusion")
    for _ = 1, 30 do  -- wait until the Fusion page really shows this clip's comp, or Paste lands elsewhere
      if resolve:Fusion():GetCurrentComp() == comp then break end
      bmd.wait(0.1)
    end
    for _, i in ipairs(off) do tl:SetTrackEnable("video", i, true) end
    assert(resolve:Fusion():GetCurrentComp() == comp, "Fusion page did not open this clip's comp")
    -- one argument only: bmd.readstring(s, x) returns nil, and Paste(nil) pastes the CLIPBOARD instead
    local settings = bmd.readstring((assert(R.readfile(id), "cannot read " .. id)))
    assert(type(settings) == "table" and settings.Tools, "not a Fusion .setting: " .. id)
    assert(comp:Paste(settings), "Paste failed: " .. id)
    -- several top-level tools: take the end of the chain = the one no other pasted tool reads from
    -- (Paste may auto-connect it to MediaOut, so connections to non-pasted tools don't count)
    local pasted = {}
    for _, x in pairs(comp:GetToolList(true)) do pasted[x.Name] = x end
    for _, x in pairs(pasted) do
      local out, fed = x:FindMainOutput(1), false
      for _, inp in pairs(out and out:GetConnectedInputs() or {}) do fed = fed or pasted[inp:GetTool().Name] ~= nil end
      if out and not fed then t = x end
    end
    assert(t, "no output tool found in " .. id)
    -- a chain (A -> B -> t, saved with R.save_fx): walk back along main inputs to its head, which takes the picture
    head = t
    while true do
      local src = head:FindMainInput(1) and head:FindMainInput(1):GetConnectedOutput()
      if src and pasted[src:GetTool().Name] then head = src:GetTool() else break end
    end
    resolve:OpenPage(pg)
  else
    t = assert(comp:AddTool(id), "AddTool failed: " .. id)
  end
  local main = (head or t):FindMainInput(1)  -- nil for generators/titles: their output simply replaces the picture
  if main then main:ConnectTo(mo.Input:GetConnectedOutput() or comp:FindTool("MediaIn1").Output) end
  mo.Input:ConnectTo(t:FindMainOutput(1))  -- macros output on "MainOutput1", tools on "Output"
  local keyed = false
  for k, v in pairs(params or {}) do  -- SetInput on a wrong ID is silently ignored: check it exists
    assert(t[k], "no input '" .. k .. "' on " .. id .. "; R.inputs(tool) lists them")
    if type(v) == "table" and type(v[1]) == "table" then key(t, k, v); keyed = true else t:SetInput(k, v) end
  end
  if keyed and t.ID:match("^ofx%.") then
    -- keyframes added live to a ResolveFX read back fine but RENDER the static value; pasted from a .setting they animate
    local tmp = R.save_fx({t}, R.dir .. "ofx_keys.setting")
    mo.Input:ConnectTo(t:FindMainInput(1):GetConnectedOutput()); t:Delete()
    return R.fx(item, tmp)
  end
  return t, comp
end

function R.writefile(p, s)
  local f = ffi.C.fopen(p, "wb")
  assert(f ~= nil, "cannot write " .. p .. " (does the folder exist?)")
  ffi.C.fwrite(s, 1, #s, f); ffi.C.fclose(f)
  return p
end

-- Save Fusion tools (a chain, with their keyframes and modifiers) as a .setting that R.fx(item, path) re-applies to any clip.
-- tools: a list of tools in one comp, e.g. the returns of several R.fx calls.
function R.save_fx(tools, path)
  return R.writefile(path, bmd.writestring(tools[1]:Comp():CopySettings(tools)))
end

-- Curves by script (Fusion ColorCurves: each channel is a LUTBezier whose "frames" are inputs 0..1 and values outputs).
-- R.curve(item, {{0, 0.05}, {0.25, 0.18}, {0.75, 0.85}, {1, 0.97}})        S-curve on R, G and B
-- R.curve(item, {{0, 0}, {1, 0.9}}, "b")                                   one channel ("r", "g", "b" or any mix)
-- Returns the ColorCurves tool (chained like any R.fx effect). Verified: {{0,0},{1,0.5}} on "r" halves the red mean exactly.
function R.curve(item, pts, ch)
  local cc, k = R.fx(item, "ColorCurves"), {}
  for _, p in ipairs(pts) do k[p[1]] = {p[2]} end
  for c in (ch or "rgb"):gmatch(".") do
    cc[({r = "Red", g = "Green", b = "Blue"})[c]]:GetConnectedOutput():GetTool():SetKeyFrames(k, true)
  end
  return cc
end

-- A tool's own settable inputs with current values (skips images, masks and the common Settings page): param IDs for R.fx.
function R.inputs(tool)
  local o = {}
  for _, inp in ipairs(tool:GetInputList()) do
    local a = inp:GetAttrs()
    if a.INPS_DataType ~= "Image" and a.INPS_DataType ~= "Mask" and a.INPS_ICS_ControlPage ~= "Common" then
      -- skips the shared Settings page; macros expose InputN, so show the display name too
      local name = (a.INPS_Name and a.INPS_Name ~= a.INPS_ID) and "(" .. a.INPS_Name .. ")" or ""
      o[#o + 1] = a.INPS_ID .. name .. "=" .. R.ser(inp[0])
    end
  end
  return table.concat(o, " ")
end

-- Keyframed motion on a clip through a Fusion Transform (renders in the timeline and in Deliver).
-- o.punch = {from=1.25, to=1.0, frames=6}  impact zoom at the head of the clip
-- o.push  = {from=1.0, to=1.08}            slow eased zoom across the whole clip
-- o.shake = {amp=0.015, frames=10}         decaying shake (fraction of frame)
function R.motion(item, o)
  local comp = item:GetFusionCompCount() > 0 and item:GetFusionCompByIndex(1)
  local xf = comp and comp:FindToolByID("Transform") or R.fx(item, "Transform")
  local n = item:GetDuration()
  if o.push then key(xf, "Size", {{0, o.push.from or 1.0}, {n - 1, o.push.to or 1.08}}) end
  if o.punch then
    local p = o.punch
    local tail = o.push and (o.push.to or 1.08) or (p.to or 1.0)
    key(xf, "Size", {{0, p.from or 1.25}, {p.frames or 6, p.to or 1.0}, {n - 1, tail}})
  end
  if o.shake then
    local pts, amp, fr = {}, o.shake.amp or 0.015, o.shake.frames or 10
    for f = 0, fr do
      local a = amp * math.exp(-f / (fr / 3))
      pts[#pts + 1] = {f, {0.5 + a * math.sin(f * 1.9), 0.5 + a * math.cos(f * 2.7)}}
    end
    pts[#pts + 1] = {fr + 1, {0.5, 0.5}}
    key(xf, "Center", pts)
  end
  if o.blur ~= false then xf:SetInput("MotionBlur", 1); xf:SetInput("Quality", 4) end
  return xf
end

-- Follow a track made by scripts/track.py (OpenCV): key tool[input] (a Point: Text+ Center, a mask's Center, Transform Center)
-- to the tracked box centre. item = the TRACKED clip on the timeline (its source frames are the track's frame numbers);
-- o.on = the item whose comp holds the tool when that is another clip (a title carrier above it). o.offset = {dx, dy} (fractions, y up);
-- o.size = scale -> also key the mask's Width/Height to the box (masks measure both in frame WIDTHS);
-- o.stabilize = true -> key a Transform Center so the object stays where it was on the item's first tracked frame.
-- Returns the number of keyed frames.
function R.track(item, tool, input, path, o)
  o = o or {}
  local t = assert(dofile(path), "bad track file " .. path)
  local on = o.on or item
  local s0, n, d = item:GetSourceStartFrame() + on:GetStart() - item:GetStart(), on:GetDuration(), o.offset or {0, 0}
  local pts, wp, hp, first = {}, {}, {}, nil
  for f = 0, n - 1 do
    local b = t.frames[s0 + f]
    if b then
      first = first or b
      if o.stabilize then pts[#pts + 1] = {f, {0.5 - (b[1] - first[1]), 0.5 - (b[2] - first[2])}}
      else pts[#pts + 1] = {f, {b[1] + d[1], b[2] + d[2]}} end
      if o.size then wp[#wp + 1] = {f, b[3] * o.size}; hp[#hp + 1] = {f, b[4] * t.h / t.w * o.size} end
    end
  end
  assert(#pts > 0, "no tracked frames in source range " .. s0 .. "-" .. s0 + n - 1)
  key(tool, input, pts)
  if o.size then key(tool, "Width", wp); key(tool, "Height", hp) end
  return #pts
end

-- Zoom onto a point and back (screen-recording demos). target = {x, y} as fractions of the frame measured from the
-- TOP-LEFT (what you read off a screenshot). Eases in over o.ease frames from o.at, holds to o.hold, eases out.
-- Maths: with the pivot at the centre, point t lands at (t - 0.5) * s + Center, so Center = 0.5 - (t - 0.5) * s (y up).
function R.zoom(item, o)
  local xf = R.motion(item, {blur = false})
  local s, e = o.scale or 2.0, o.ease or 15
  local tx, ty = o.target[1], 1 - o.target[2]
  local c = {0.5 - (tx - 0.5) * s, 0.5 - (ty - 0.5) * s}
  key(xf, "Size", {{o.at, 1.0}, {o.at + e, s}, {o.hold, s}, {o.hold + e, 1.0}})
  key(xf, "Center", {{o.at, {0.5, 0.5}}, {o.at + e, c}, {o.hold, c}, {o.hold + e, {0.5, 0.5}}})
  return xf
end

-- ── color ────────────────────────────────────────────────────────────────────
-- LUT path is RELATIVE to the master LUT folder (/opt/resolve/LUT on Linux); SetLUT rejects anything else.
function R.lut(items, lut, node)
  R.project():RefreshLUTList()
  local n = 0
  for _, it in ipairs(items) do if it:GetNodeGraph():SetLUT(node or 1, lut) then n = n + 1 end end
  return n
end

-- CDL on node 1. o.slope/offset/power = {r,g,b}, o.sat = number.
function R.cdl(item, o)
  local function s(v, d) v = v or d return v[1] .. " " .. v[2] .. " " .. v[3] end
  return item:SetCDL({NodeIndex = o.node or 1, Slope = s(o.slope, {1, 1, 1}), Offset = s(o.offset, {0, 0, 0}),
    Power = s(o.power, {1, 1, 1}), Saturation = tostring(o.sat or 1)})
end

-- One look for many clips: a color group with the LUT in its pre-clip graph (timeline-level graphs have 0 nodes).
function R.group(name, items, lut)
  local p = R.project()
  local g
  for _, x in ipairs(p:GetColorGroupsList() or {}) do if x:GetName() == name then g = x end end
  g = g or p:AddColorGroup(name)
  for _, it in ipairs(items) do it:AssignToColorGroup(g) end
  if lut then p:RefreshLUTList(); g:GetPreClipNodeGraph():SetLUT(1, lut) end
  return g
end

-- ── audio ────────────────────────────────────────────────────────────────────
function R.volume(item, db) return item:SetProperties({AudioVolume = db}) end   -- dB, -100..+30
function R.fade(item, fin, fout) return item:SetFades({FadeIn = fin or 0, FadeOut = fout or 0}) end

-- Clip-gain loudness normalization. mode: "YouTube" | "EBU R128" | "Netflix" | "True Peak" | ... (tl:GetNormalizeAudioModes())
function R.normalize(tl, items, mode, target)
  return tl:NormalizeAudioLevel(items, {normalizationMode = mode or "EBU R128", targetLoudness = target or -23,
    setLevelMode = resolve.NORMALIZE_AUDIO_SET_LEVEL_INDEPENDENT})
end

-- Waveform-sync an external recorder to a camera clip (media pool). Verified sample-accurate.
-- The synced clip then carries 2 audio tracks: give it 2 audio tracks on the timeline.
-- Do NOT use tl:AutoAlignClips (returned false / crashed Resolve in the lab).
function R.sync(cam, mic)
  R.mp():AutoSyncAudio({cam, mic}, {[resolve.AUDIO_SYNC_MODE] = resolve.AUDIO_SYNC_WAVEFORM,
    [resolve.AUDIO_SYNC_CHANNEL_NUMBER] = -1, [resolve.AUDIO_SYNC_RETAIN_EMBEDDED_AUDIO] = true,
    [resolve.AUDIO_SYNC_RETAIN_VIDEO_METADATA] = false})
  return cam:GetClipProperty("Synced Audio"), cam:GetClipProperty("Audio Offset")
end

-- ── review: the agent's eyes ─────────────────────────────────────────────────
-- Full timeline composite (all tracks, Fusion, grades) at timeline resolution, as PNG. Edit page only.
-- Move the playhead to a relative frame. Right after a page switch the first move can be dropped: retry.
function R.seek(tl, rel)
  local tc = R.tc(tl, rel)
  for _ = 1, 5 do
    tl:SetCurrentTimecode(tc)
    if tl:GetCurrentTimecode() == tc then return tc end
    bmd.wait(0.2)
  end
  error("playhead did not move to " .. tc)
end

function R.still(tl, rel, path)
  tl = tl or R.tl()
  page("edit")
  R.seek(tl, rel)
  -- the console can't mkdir: a missing folder makes the export return false and write nothing
  return assert(R.project():ExportCurrentFrameAsStill(path), "still export failed (does the folder exist?): " .. path)
end

function R.stills(tl, frames, dir, prefix)
  local out = {}
  for _, f in ipairs(frames) do
    local p = string.format("%s/%s%05d.png", dir, prefix or "f", f)
    if R.still(tl, f, p) then out[#out + 1] = p end
  end
  return out
end

-- Drop markers (e.g. beats) on the timeline. frames are relative.
function R.markers(tl, frames, color, name)
  local n = 0
  for _, f in ipairs(frames) do if tl:AddMarker(f, color or "Blue", name or "beat", "", 1, "") then n = n + 1 end end
  return n
end

-- ── render ───────────────────────────────────────────────────────────────────
function R.storage() return resolve:GetMediaStorage():GetMountedVolumeList() end

-- Render the current timeline. Free Resolve only renders INTO Media Storage folders; anything else makes
-- AddRenderJob return "" and pops a "Render Path Inaccessible" dialog. Linux free has no H.264: render
-- ProRes/DNxHR and encode deliverables with finish.sh.
-- o: dir, name, format("mov"), codec("ProRes422HQ"), range {in, out} relative frames (inclusive), audio(true)
function R.render(o)
  local p, tl = R.project(), R.tl()
  o.dir = o.dir:gsub("^~", HOME)
  local ok = false
  for _, v in ipairs(R.storage()) do if o.dir:sub(1, #v) == v then ok = true end end
  assert(ok, o.dir .. " is not inside Media Storage (" .. table.concat(R.storage(), ", ") .. ")")
  p:DeleteAllRenderJobs()
  -- settings stack on whatever preset is loaded (an earlier "Audio Only" silently drops video): reset first
  p:LoadRenderPreset(o.preset or "ProRes 422 HQ")
  p:SetCurrentRenderMode(1)
  assert(p:SetCurrentRenderFormatAndCodec(o.format or "mov", o.codec or "ProRes422HQ"), "bad format/codec (use the codec ID, e.g. ProRes422HQ, DNxHRHQ)")
  local s = {TargetDir = o.dir, CustomName = o.name, ExportVideo = true, ExportAudio = o.audio ~= false, SelectAllFrames = o.range == nil}
  if o.range then s.MarkIn = tl:GetStartFrame() + o.range[1]; s.MarkOut = tl:GetStartFrame() + o.range[2] end
  -- o.settings: any other SetRenderSettings key, e.g. {ExportSubtitle = true, SubtitleFormat = "BurnIn"}
  for k, v in pairs(o.settings or {}) do s[k] = v end
  assert(p:SetRenderSettings(s), "SetRenderSettings rejected")
  local id = p:AddRenderJob()
  assert(id and id ~= "", "AddRenderJob failed (render path / settings)")
  local t = os.time()
  p:StartRendering({id})
  while p:IsRenderingInProgress() do bmd.wait(0.5) end
  local st = p:GetRenderJobStatus(id)
  return st.JobStatus, os.time() - t, o.dir .. "/" .. o.name .. "." .. (o.format or "mov")
end

return R

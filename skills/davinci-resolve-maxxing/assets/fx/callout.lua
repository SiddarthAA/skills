-- Callout: box(es) around a subject + leader line + label pill, animated in, on its own carrier clip.
--   dofile(R.effects .. "callout.lua")
--   R.callout(tl, {at = 250, len = 90, label = "Type anywhere", pill = {975, 200}, boxes = {{520, 380, 1430, 770, 975, 380}}})
-- Geometry in timeline PIXELS from the top-left (read it off a still). boxes = {{x1, y1, x2, y2, ax, ay}...}: ax, ay = where the
-- line leaves the box. Optional: track (2), size (Text+ size, 0.036), font/style ("SemiBold"), ink {r,g,b} (label text),
-- drift = {dx, dy} px over the callout (follows a slowly moving subject). Returns the carrier item and its comp.
-- Units [L]: RectangleMask Width = frame widths, Height = frame HEIGHTS; EllipseMask uses widths for both.
local function callout(tl, o)
  local W, H = tonumber(tl:GetSetting("timelineResolutionWidth")), tonumber(tl:GetSetting("timelineResolutionHeight"))
  local function P(x, y) return {x / W, 1 - y / H} end
  local car = R.place(tl, R.carrier(tl), {track = o.track or 2, at = o.at, len = o.len, media = "video"})[1]
  local comp = car:AddFusionComp()
  local prev = comp:FindTool("MediaIn1").Output
  local function fill(mask)  -- white solid through a mask, merged over everything so far
    local b = comp:AddTool("Background")
    b:SetInput("Width", W); b:SetInput("Height", H)
    b:SetInput("TopLeftRed", 1); b:SetInput("TopLeftGreen", 1); b:SetInput("TopLeftBlue", 1)
    b.EffectMask = mask.Mask
    local m = comp:AddTool("Merge"); m.Background = prev; m.Foreground = b.Output; prev = m.Output
    return m
  end
  local T = 4  -- stroke px
  for _, b in ipairs(o.boxes or {}) do
    local x1, y1, x2, y2, ax, ay = unpack(b)
    local bw, bh = x2 - x1, y2 - y1
    local outer, inner = comp:AddTool("RectangleMask"), comp:AddTool("RectangleMask")  -- ring = outer minus inner
    for _, m in ipairs({outer, inner}) do m:SetInput("Center", P((x1 + x2) / 2, (y1 + y2) / 2)); m:SetInput("CornerRadius", 0.08) end
    inner:SetInput("PaintMode", "Subtract"); inner.EffectMask = outer.Mask
    R.key(outer, "Width", {{0, (bw + 2 * T) * 1.08 / W}, {10, (bw + 2 * T) / W}, ease = "out"})
    R.key(outer, "Height", {{0, (bh + 2 * T) * 1.08 / H}, {10, (bh + 2 * T) / H}, ease = "out"})
    R.key(inner, "Width", {{0, bw * 1.08 / W}, {10, bw / W}, ease = "out"})
    R.key(inner, "Height", {{0, bh * 1.08 / H}, {10, bh / H}, ease = "out"})
    R.key(fill(inner), "Blend", {{0, 0}, {8, 1}})
    local dx, dy = o.pill[1] - ax, o.pill[2] - ay  -- leader line grows from the box to the pill
    local ln = comp:AddTool("RectangleMask")
    ln:SetInput("Height", T / H); ln:SetInput("Angle", math.deg(math.atan2(-dy, dx)))
    R.key(ln, "Width", {{0, 0}, {6, 0}, {18, math.sqrt(dx * dx + dy * dy) / W}, ease = "out"})
    R.key(ln, "Center", {{0, P(ax, ay)}, {6, P(ax, ay)}, {18, P(ax + dx / 2, ay + dy / 2)}, ease = "out"})
    R.key(fill(ln), "Blend", {{0, 0}, {5, 0}, {7, 1}})
    local dot = comp:AddTool("EllipseMask")
    dot:SetInput("Center", P(ax, ay)); dot:SetInput("Width", 14 / W); dot:SetInput("Height", 14 / W)
    R.key(fill(dot), "Blend", {{0, 0}, {8, 1}})
  end
  local size, font, style = o.size or 0.036, o.font, o.style or "SemiBold"
  if not font then font = R.default_font(); style = o.style or "Bold" end
  local fpx = size * W  -- about one em in px
  local pm = comp:AddTool("RectangleMask")  -- pill sized from the label length (~0.36 em per character)
  pm:SetInput("Center", P(o.pill[1], o.pill[2])); pm:SetInput("CornerRadius", 0.5)
  pm:SetInput("Width", (#o.label * fpx * 0.36 + fpx) / W); pm:SetInput("Height", fpx * 1.05 / H)
  R.key(fill(pm), "Blend", {{0, 0}, {14, 0}, {22, 1}})
  local txt, ink = comp:AddTool("TextPlus"), o.ink or {0.06, 0.11, 0.22}
  txt:SetInput("StyledText", o.label); txt:SetInput("Font", font); txt:SetInput("Style", style); txt:SetInput("Size", size)
  txt:SetInput("Red1", ink[1]); txt:SetInput("Green1", ink[2]); txt:SetInput("Blue1", ink[3])
  txt:SetInput("Center", P(o.pill[1], o.pill[2] + fpx * 0.04))
  local mt = comp:AddTool("Merge"); mt.Background = prev; mt.Foreground = txt.Output; prev = mt.Output
  R.key(mt, "Blend", {{0, 0}, {16, 0}, {24, 1}})
  if o.drift then
    local xf = comp:AddTool("Transform"); xf.Input = prev
    R.key(xf, "Center", {{0, {0.5, 0.5}}, {o.len - 1, {0.5 + o.drift[1] / W, 0.5 - o.drift[2] / H}}})
    prev = xf.Output
  end
  comp:FindTool("MediaOut1").Input = prev
  R.fade(car, 0, 8)
  return car, comp
end
R.callout = callout
return callout

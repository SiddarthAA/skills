-- Builders for the effect presets in this folder (R.effects). Each takes a timeline item, builds the effect with R.fx/R.key and
-- returns its tools in chain order. Rebuild or vary a preset:
--   dofile(R.effects .. "build.lua"); local tools = FX.b["glitch"](item); R.save_fx(tools, "/abs/my-glitch.setting")
-- Keys are frames from the clip's first frame. Verified on free 21.1.1 Linux (references/effects.md).
FX = {b = {}}
local OFX = "ofx.com.blackmagicdesign.resolvefx."

-- impact zoom: 135% -> 100% in 6 frames, fast start (snap), motion blur
FX.b["zoom-punch"] = function(it)
  local x = R.fx(it, "Transform", {MotionBlur = 1, Quality = 8, ShutterAngle = 180})
  R.key(x, "Size", {{0, 1.35}, {6, 1.0}, ease = "snap"})
  return {x}
end

-- slow push-in over the clip (Ken Burns), smooth
FX.b["push-in"] = function(it)
  local x = R.fx(it, "Transform")
  R.key(x, "Size", {{0, 1.0}, {89, 1.12}, ease = "smooth"})
  return {x}
end

-- impact shake: decaying jitter in the first 12 frames + small punch
FX.b["impact-shake"] = function(it)
  local x = R.fx(it, "Transform", {MotionBlur = 1, Quality = 8})
  local pts = {}
  for f = 0, 12 do
    local a = 0.03 * math.exp(-f / 4)
    pts[#pts + 1] = {f, {0.5 + a * math.sin(f * 2.3), 0.5 + a * math.cos(f * 3.1)}}
  end
  pts[#pts + 1] = {13, {0.5, 0.5}}
  R.key(x, "Center", pts)
  R.key(x, "Size", {{0, 1.12}, {13, 1.04}, ease = "out"})
  return {x}
end

-- handheld camera: continuous gentle shake, scaled up 6% so edges never show
FX.b["handheld"] = function(it)
  local s = R.fx(it, "CameraShake", {XDeviation = 0.12, YDeviation = 0.12, RotationDeviation = 0.08, Speed = 0.35, OverallStrength = 0.25})
  local x = R.fx(it, "Transform", {Size = 1.06})
  return {s, x}
end

-- light flicker (old film / unstable light): ResolveFX Flicker Addition
FX.b["flicker"] = function(it)
  return {(R.fx(it, OFX .. "FlickerAddition", {flickerRange = 0.6, flickerSpeed = 2, flickerRand = 0.8}))}
end

-- strobe: hard 2-on/2-off brightness via an expression
FX.b["strobe"] = function(it)
  local bc = R.fx(it, "BrightnessContrast")
  bc.Gain:SetExpression("iif(time % 4 < 2, 1, 0.25)")
  return {bc}
end

-- flash in: starts blown out white, settles in 8 frames
FX.b["flash-in"] = function(it)
  local bc = R.fx(it, "BrightnessContrast")
  R.key(bc, "Gain", {{0, 5}, {8, 1}, ease = "out"})
  R.key(bc, "Saturation", {{0, 0}, {8, 1}, ease = "out"})
  return {bc}
end

-- RGB split (chromatic offset): red right, blue left, constant
FX.b["rgb-split"] = function(it)
  return {(R.fx(it, "KD_ChannelShifter", {Center1 = {0.508, 0.5}, Center3 = {0.492, 0.5}}))}
end

-- glitch burst (first 12 frames): jumping RGB split + horizontal jolts + JPEG blocks, then clean
FX.b["glitch"] = function(it)
  local cs = R.fx(it, "KD_ChannelShifter")
  local x = R.fx(it, "Transform")
  local jd = R.fx(it, OFX .. "JPEGDamage", {ofxQuality = 3})
  local r = {0.03, -0.02, 0.05, 0, -0.04, 0.02, 0.06, -0.01, 0, 0.03, -0.05, 0}
  local c1, c3, xc, bl = {}, {}, {}, {}
  for i, d in ipairs(r) do
    local f = (i - 1)
    c1[#c1 + 1] = {f, {0.5 + d, 0.5}}
    c3[#c3 + 1] = {f, {0.5 - d * 0.7, 0.5}}
    xc[#xc + 1] = {f, {0.5 + d * 0.4, 0.5 + (i % 3 == 0 and 0.01 or 0)}}
    bl[#bl + 1] = {f, (i % 2 == 0) and 0 or 1}   -- JPEG damage every other frame
  end
  c1[#c1 + 1] = {12, {0.5, 0.5}}; c3[#c3 + 1] = {12, {0.5, 0.5}}; xc[#xc + 1] = {12, {0.5, 0.5}}; bl[#bl + 1] = {12, 1}
  c1.ease, c3.ease, xc.ease = "hold", "hold", "hold"
  R.key(cs, "Center1", c1); R.key(cs, "Center3", c3); R.key(x, "Center", xc)
  -- ResolveFX blend: 0 = full effect, 1 = original
  R.key(jd, "blend", {{0, 0}, {1, 1}, {2, 0}, {3, 1}, {4, 0}, {5, 1}, {6, 0}, {7, 1}, {8, 0}, {12, 1}, ease = "hold"})
  return {cs, x, jd}
end

-- VHS: soft horizontal smear, colour bleed, scanlines, grain, lower saturation
FX.b["vhs"] = function(it)
  local bl = R.fx(it, "Blur", {LockXY = 0, XBlurSize = 2.5, YBlurSize = 0.3})
  local cs = R.fx(it, "KD_ChannelShifter", {Center1 = {0.503, 0.5}, Center3 = {0.497, 0.5}})
  local sl = R.fx(it, OFX .. "ScanlineV2", {frequency = 40, width = 0.4, blend = 0.8})
  local g = R.fx(it, "FilmGrain", {MasterStrength = 0.06, Monochrome = 1})
  local bc = R.fx(it, "BrightnessContrast", {Saturation = 0.7, Contrast = -0.08, Lift = 0.04})
  return {bl, cs, sl, g, bc}
end

-- film look: grain + soft oval vignette
FX.b["film-look"] = function(it)
  local g = R.fx(it, "FilmGrain", {MasterStrength = 0.06})
  local v = R.fx(it, OFX .. "Vignette", {size = 0.8, softness = 0.8, transparency = 0.45})
  return {g, v}
end

-- letterbox 2.39:1 bars: black outside a centred rectangle (Rectangle mask, inverted, on a zero-gain BrightnessContrast)
FX.b["letterbox"] = function(it)
  local bc = R.fx(it, "BrightnessContrast", {Gain = 0, Lift = 0})
  local rc = it:GetFusionCompByIndex(1):AddTool("RectangleMask")
  rc:SetInput("Width", 1.2); rc:SetInput("Height", (16 / 9) / 2.39); rc:SetInput("Invert", 1)
  bc.EffectMask = rc.Mask
  return {rc, bc}
end

-- black and white, punchy
FX.b["black-white"] = function(it)
  return {(R.fx(it, "BrightnessContrast", {Saturation = 0, Contrast = 0.2}))}
end

-- dreamy glow / bloom
FX.b["glow"] = function(it)
  return {(R.fx(it, "SoftGlow", {Threshold = 0.6, Gain = 1.5, XGlowSize = 25}))}
end

-- procedural light leak: big soft warm noise, screened over the clip, drifting
FX.b["light-leak"] = function(it)
  local comp = it:GetFusionCompByIndex(1) or it:AddFusionComp()
  local n = comp:AddTool("FastNoise")
  n:SetInput("Width", 1920); n:SetInput("Height", 1080)
  n:SetInput("Detail", 0); n:SetInput("Contrast", 1.6); n:SetInput("XScale", 0.6); n:SetInput("SeetheRate", 0.05)
  -- gradient colours: dark -> orange/red
  n:SetInput("Color1Red", 0); n:SetInput("Color1Green", 0); n:SetInput("Color1Blue", 0)
  n:SetInput("Color2Red", 1); n:SetInput("Color2Green", 0.45); n:SetInput("Color2Blue", 0.1)
  local m = R.fx(it, "Merge", {ApplyMode = "Screen", Blend = 0.75})
  m.Foreground = n.Output
  R.key(n, "Center", {{0, {0.3, 0.5}}, {89, {0.7, 0.55}}})
  return {n, m}
end

-- blur a region (face, licence plate): blurred inside an ellipse; move/track Center
FX.b["blur-region"] = function(it)
  local b = R.fx(it, "Blur", {XBlurSize = 40})
  local e = it:GetFusionCompByIndex(1):AddTool("EllipseMask")
  e:SetInput("Width", 0.12); e:SetInput("Height", 0.2); e:SetInput("Center", {0.62, 0.62}); e:SetInput("SoftEdge", 0.02)
  b.EffectMask = e.Mask
  return {e, b}
end

-- zoom blur in: rushes in from 150% with radial zoom blur
FX.b["zoom-blur-in"] = function(it)
  local x = R.fx(it, "Transform")
  R.key(x, "Size", {{0, 1.5}, {8, 1.0}, ease = "out"})
  local zb = R.fx(it, OFX .. "ZoomBlur")
  R.key(zb, "blend", {{0, 0}, {8, 1}, ease = "out"})
  return {x, zb}
end

-- lower third on a CARRIER clip: red bar wipes open, text slides up (o: text, center {x, y}, color {r, g, b})
FX.b["lower-third"] = function(carrier, o)
  o = o or {}
  local c = o.center or {0.27, 0.16}
  local tl = R.tl()
  local comp = carrier:GetFusionCompCount() > 0 and carrier:GetFusionCompByIndex(1) or carrier:AddFusionComp()
  local txt, mrg = comp:AddTool("TextPlus"), comp:AddTool("Merge")
  local font, style = R.default_font()
  txt:SetInput("StyledText", o.text or "Name  /  Role"); txt:SetInput("Font", font); txt:SetInput("Style", style); txt:SetInput("Size", 0.04)
  R.key(txt, "Center", {{0, {c[1], c[2] - 0.06}}, {10, c}, ease = "snap"})
  local bg, rc, bar = comp:AddTool("Background"), comp:AddTool("RectangleMask"), comp:AddTool("Merge")
  local col = o.color or {0.9, 0.2, 0.2}
  bg:SetInput("TopLeftRed", col[1]); bg:SetInput("TopLeftGreen", col[2]); bg:SetInput("TopLeftBlue", col[3])
  rc:SetInput("Center", c); rc:SetInput("Height", 0.075); rc:SetInput("CornerRadius", 0.2)
  R.key(rc, "Width", {{0, 0}, {8, 0.42}, ease = "snap"})
  bg.EffectMask = rc.Mask
  bar.Background = comp:FindTool("MediaIn1").Output; bar.Foreground = bg.Output
  mrg.Background = bar.Output; mrg.Foreground = txt.Output
  R.key(mrg, "Blend", {{0, 0}, {6, 1}})
  comp:FindTool("MediaOut1").Input = mrg.Output
  return {bar, bg, rc, txt, mrg}
end

# Craft and delivery specs (researched 2026-10-29)

Numbers-first defaults for an editing agent. Apply them unless the brief says otherwise.

**Tags:** **[O]** = official platform or standards doc. **[R]** = reported by press or a third-party summary of an official page I couldn't load. **[C]** = community consensus or derived; the platform doesn't publish it. Treat [C] as a default you can tune.
Platforms change specs without notice, so check the [R] items against the live help page before a paid campaign.

---

## 1. Delivery specs

### 1a. Picture, length, file size

| Platform | Deliver at | Also accepted | fps | Max length | Ideal length [C] | Max file |
|---|---|---|---|---|---|---|
| **Instagram Reels** | 1080x1920 9:16. Meta's ads guide lists 1440x2560 [O] | 3:4 1080x1440, 4:5 | Fixed rate. 30, or 60 for fast motion | Ads: 15 min [O]. Organic: 3 min standard, 20 min rolling out since Nov 2025 [R] | 15-45 s. Reels over 3 min reportedly lose non-follower reach [R] | 4 GB [O] |
| **TikTok** | 1080x1920 9:16 | 1:1 and 16:9 (pillarboxed) | 30 (23-60 accepted [R]) | Upload: 60 min [C]. Ads (non-Spark): 10 min. TopView: 5-60 s [R] | 15-45 s organic. Ads: 9-15 s (TikTok's TopView guidance [R]) | Ads: 500 MB [R]. Content Posting API: 4 GB [R] |
| **YouTube Shorts** | 1080x1920 9:16 | 1:1 | Match source | 3 min. A Short over 1 min with an active Content ID claim is **blocked globally** [O] | 20-58 s. Stay under 60 s whenever there's licensed music | 256 GB |
| **YouTube long-form** | 3840x2160 or 1920x1080 16:9 | Any ratio; the player adapts [O] | Match source (24/25/30/48/50/60) [O] | 12 h or 256 GB, whichever comes first (verified accounts) [O] | 2-8 min for demos and explainers, 8-15 min for talks [C] | 256 GB [O] |
| **LinkedIn feed** | 1080x1350 4:5 or 1080x1080 1:1. 1920x1080 for desktop-heavy audiences | 1:2.4 to 2.4:1; 256x144 to 4096x2304 [O] | 30 (10-60 accepted [O]) | 15 min. Minimum 3 s on desktop, 2 s on mobile [O] | 30-90 s [C] | 5 GB (min 75 KB) [O] |
| **X** | 1920x1080 16:9, or 1080x1080 / 1080x1350 | 1:3 to 3:1 [O] | 30 or 60, never over 60 [O] | Free: 140 s. Premium: 4 h at 1080p on web/iOS, 10 min on Android [O] | 15-45 s [C] | Free: 512 MB [C]. Premium: 16 GB [O] |
| **Website hero loop** | 1920x1080 desktop, plus a 1080x1350 or 720x1280 mobile cut | none | 24-30 | n/a | 6-15 s seamless loop [C] | 1-3 MB desktop, under 1 MB mobile [C] |

Sources:
- Reels: https://www.facebook.com/business/ads-guide/update/video/instagram-reels and https://petapixel.com/2025/11/25/instagram-updates-camera-so-you-can-film-20-minute-reels
- TikTok: https://www.relevantaudience.com/tiktok-ads/tiktok-video-size-ad-specs/ (summarises the TikTok Ads help pages, updated Jun 2026; ads.tiktok.com was unreachable from this network)
- Shorts: https://support.google.com/youtube/answer/15424877
- YouTube long-form: https://support.google.com/youtube/answer/1722171 and https://support.google.com/youtube/answer/71673
- LinkedIn: https://www.linkedin.com/help/linkedin/answer/a548372
- X: https://help.x.com/en/using-x/premium-longer-videos and https://docs.x.com/x-api/media/quickstart/best-practices

### 1b. Encode, audio, loudness, covers

Encode every deliverable from a ProRes/DNxHR master (see §5). Bitrates marked [C] are deliberately above the platform minimums because every platform re-encodes the upload.

| Platform | Video encode | Audio | Loudness the platform normalizes to | Cover / thumbnail |
|---|---|---|---|---|
| **Reels** | H.264 High, 4:2:0, progressive, square pixels [O]. 16-20 Mbps VBR at 1080p30 [C] | AAC stereo, 128 kbps or more [O]. Use 320 kbps at 48 kHz | **Not published.** Deliver -14 LUFS / -1 dBTP [C] | 1080x1920. The profile grid shows a centred 3:4 (1080x1440) crop [C], so keep cover text inside y 240-1680. The often-quoted "420x654" is unverified |
| **TikTok** | H.264 (H.265 accepted). 12-20 Mbps at 1080p30 [C]. Ads need 516 kbps or more, TopView 2.5 Mbps or more [R] | AAC 48 kHz 320 kbps. Ads can't be silent [R] | **Not published.** -14 LUFS / -1 dBTP [C] | Pick a frame or upload a cover in the app. Grid shows a roughly 3:4 crop [C] |
| **Shorts** | Same as long-form below. Some creators upload 1440x2560 to get a better re-encode [C] | AAC-LC 48 kHz, 384 kbps stereo [O] | About -14 LUFS, and it only turns loud uploads down [C]. The Resolve manual also calls -14 the YouTube target | Custom thumbnail upload rolling out to YPP channels since Jul 2026, desktop Studio only; otherwise choose a frame [R] (https://ppc.land/youtube-ends-2-year-wait-for-shorts-thumbnails-but-blocks-a-b-testing/) |
| **YouTube** | H.264 High, MP4 with moov atom at the front (faststart), no edit lists, closed GOP of half the frame rate, 2 B-frames, CABAC, BT.709 tags. Recommended SDR bitrates [O]: 1080p 8 Mbps (24-30 fps) / 12 Mbps (48-60). 1440p 16/24. 4K 35-45/53-68. Use 1.5-2x these [C] | AAC-LC or Opus, 48 kHz. Bitrates: mono 128, stereo 384, 5.1 512 kbps [O] | About -14 LUFS, turn-down only [C] | 1280x720 (min width 640), 16:9, JPG/PNG/GIF, under 2 MB [O] (https://support.google.com/youtube/answer/72431). End screen: last 5-20 s of a video at least 25 s long [O] (https://support.google.com/youtube/answer/6388789) |
| **LinkedIn** | MP4 H.264. Allowed 192 kbps to 30 Mbps [O]. 10-16 Mbps at 1080p [C] | AAC 48 kHz 192-320 kbps [C] (LinkedIn doesn't specify) | **Not published.** -14 / -1 [C] | Custom thumbnail at upload, same aspect as the video, JPG/PNG under 2 MB [C] |
| **X** | H.264 High, YUV 4:2:0, progressive, no open GOP, at least 5 Mbps [O]. 8-12 Mbps at 1080p [C] | AAC-LC only (HE-AAC not supported), mono or stereo (no 5.1), 128 kbps or more [O] | **Not published.** -14 / -1 [C] | Posts can't take a custom thumbnail (Media Studio can [C]). Make frame 1 a strong still |
| **Hero loop** | MP4 H.264 High at CRF 24-28, plus WebM VP9 (`-b:v 0 -crf 33-41`), listing WebM first [O] (https://web.dev/articles/codelab-replace-gifs-with-video) | **No audio track** (`-an`). Muted or audio-less video is what browsers allow to autoplay [O] (https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay) | n/a | `poster` = first frame, same size, WebP/AVIF under 100 KB [C]. Markup: `<video autoplay muted loop playsinline>` [O]. Loops over 5 s need a pause control (WCAG 2.2.2) [O] (https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html). Respect `prefers-reduced-motion` [C] |

**Loudness reference points**
- EBU R128 (broadcast, EU): -23 LUFS ±0.5, max -1 dBTP [O]. https://tech.ebu.ch/docs/r/r128-2014.pdf
- ATSC A/85 (broadcast, US): -24 LKFS ±2. The -2 dBTP ceiling is the commonly cited value [C]. https://www.tcelectronic.com/broadcast-standards
- AES TD1008 (streaming): -18 LUFS for speech or mixed content, -16 LUFS for music [O]. https://productionadvice.co.uk/td1008/
- Apple Podcasts: -16 LKFS ±1, true peak at or below -1 dBFS [O]. https://podcasters.apple.com/support/audio-requirements
- YouTube's -14 LUFS has never been officially published [C]. https://youlean.co/?p=30813

**House rule:** social and YouTube masters go out at **-14 LUFS integrated, -1 dBTP**. Use -1.5 dBTP if the AAC bitrate is 192 kbps or lower. Audio-only podcast feeds get -16 LUFS. Fairlight's meter target defaults to -23, so set it to -14 (Resolve 21.1 manual, "Target Loudness Level").

---

## 2. UI safe zones

### 2a. 9:16 at 1080x1920: what the platform UI covers

| Platform | Top | Bottom | Left | Right | Basis |
|---|---|---|---|---|---|
| Instagram Reels | 269 px (14%) | 672 px (35%) | 65 px (6%) | 65 px (6%) | Meta ads guide [O] |
| TikTok | 240 px | 660 px | 120 px | 120 px. The button column is about 180 px wide, starting near y 840 | TikTok In-Feed safe-zone file, scaled from 720x1280 [R] (https://www.socialync.io/tools/safe-zones) |
| TikTok In-Feed **ad** (measured Mar 2026) | 254 | 707 | 122 | 242 | Measured from ad previews [C] (https://adkit.so/tools/safe-zones/tiktok) |
| YouTube Shorts | 288 px (15%) | 672 px (35%) | 48 px | 192 px (18%) | Google Ads vertical template [O image, R values] (https://support.google.com/google-ads/answer/13547298) |

Since June 2026 Shorts viewers can turn on "Clear Screen" to hide the UI, but design for the UI being visible [R] (https://reap.video/blog/short-form-video-safe-zones).

### 2b. One rectangle that works on all three
- **Universal safe rect: x 120-888, y 288-1248 (768x960 px).** It takes the worst case on each edge: top and right from Shorts, bottom from Reels and Shorts, left from TikTok.
- **Strict variant for TikTok paid:** x 122-838, y 288-1213.
- Text, logos, prices, CTAs and faces' eyes go inside the rect. Backgrounds and B-roll can fill the whole frame.
- **Captions:**
  - Centre them on x = 540, max text width 696 px (x 192-888). Never let the right edge pass x 888, which is the button column.
  - Default caption block is **y 1000-1248**: bottom line's baseline at about y 1200, roughly 62% of frame height.
  - Hype word-pop captions can sit at frame centre (y 900-1100).
  - Move captions up if they cover a mouth, hands or the product. Never put them above y 288 or below y 1248 [C].

### 2c. Other ratios [C unless tagged]
- **4:5 1080x1350 (IG/LinkedIn feed):**
  - Feed UI barely overlaps the video.
  - The IG grid shows a centred 3:4 crop (1012x1350), so keep at least 40 px clear on the sides.
  - Use 54 px margins all round (5%). Keep key text out of the bottom 135 px (10%), where the mute/tag icons and LinkedIn's CC captions sit.
- **1:1 1080x1080 (LinkedIn/X):** 54 px margins (5%). Keep the bottom 108 px clear of text, because the player controls and progress bar overlay it.
- **16:9 1920x1080 (YouTube/LinkedIn/X):**
  - Graphics-safe is 90%: 96 px left/right, 54 px top/bottom. Action-safe is 93%. Per EBU R95 [O] (https://tech.ebu.ch/publications/r095).
  - Keep lower thirds above the bottom 120 px, where YouTube's progress bar and CC sit.
  - In the last 5-20 s, leave the right half or centre free for end-screen elements.
- **Covers and thumbnails:** keep title text inside the centred 1080x1350 area of a 9:16 cover. That's the only region that survives the 9:16, 4:5 and 3:4 crops [C] (https://www.hopperhq.com/blog/instagram-reel-size/).

---

## 3. Clean-edit craft by video type

### 3a. Short-form hype reels
**Hook (0-2 s)**
- Frame 1 must already be moving and on-brand. No logo sting, no fade from black, no "hey guys" [C].
- Open on the payoff shot or a pattern interrupt. Get the text hook on screen by frame 6-15 and the first spoken word by about 0.3 s [C].
- State the value proposition within 3 s and land the full hook within 6 s [O] (https://ads.tiktok.com/help/article/creative-best-practices). Google's ABCD framework says the same: start fast, tight framing, brand early [O] (https://support.google.com/google-ads/answer/14783551).

**Beat-synced cutting**
- One beat lasts `fps*60/BPM` frames. Place the cut for beat *n* at `round(n*fps*60/BPM)`, computed cumulatively from the downbeat. Rounding each shot separately makes the cuts drift.
- Cut on the beat frame or 1 frame early, never late. People notice audio that leads picture beyond about 45 ms, which is about 1 frame at 30p. They tolerate audio lagging picture by up to about 125 ms (ITU-R BT.1359 [O], https://www.itu.int/rec/R-REC-BT.1359).

| BPM | Beat (ms) | Frames per beat @24 / 25 / 30 / 60 | Default shot length [C] |
|---|---|---|---|
| 90 | 667 | 16 / 16.7 / 20 / 40 | 2 beats (1.33 s); 1-beat cuts on accents |
| 100 | 600 | 14.4 / 15 / 18 / 36 | 2 beats (1.2 s) |
| 120 | 500 | 12 / 12.5 / 15 / 30 | 2 beats (1.0 s); 1-beat bursts of 4-8 cuts on the drop |
| 128 | 469 | 11.25 / 11.7 / 14.06 / 28.1 | 2 beats (0.94 s) |
| 140 | 429 | 10.3 / 10.7 / 12.86 / 25.7 | 2 beats (0.86 s), or 4 beats in half-time sections |
| 174 | 345 | 8.3 / 8.6 / 10.3 / 20.7 | 4 beats (1.38 s); 2-beat bursts only |

- Hold hero shots for a full bar (4 beats). Never go under 8 frames at 30p, except deliberate 1-2 frame flashes.
- Change the energy every 8 bars: tempo of cuts, shot scale, or a speed ramp [C].

**Speed ramps** [C]
- Ramp 100% down to 20-40% over 4-8 frames into the action. Hold the slow section for half a beat to a full beat, then ramp back to 100-200% so it lands on the next beat.
- Use 60/120 fps sources for slow sections. Otherwise use Resolve Retime Curve with Optical Flow and ease in/out.

**Punch-ins** [C]
- Scale 110-115% from a 1080 source (more turns soft); up to 200% from a 4K source.
- Snap punch-ins on beats or emphasis words. A 2-4 frame eased zoom works as an impact accent.

**Transitions** [C]
- Feel good: hard cuts (90% or more of edits), match cuts on shape, motion or colour, whip pans of 6-10 frames with motion blur plus a whoosh, masked object wipes, zoom-throughs on the beat, 2-4 frame flash or light leak on a drop.
- Look cheap: library 3D, page-peel, spin or star wipes; cross-dissolves inside high-energy sections; glitch on every cut; any transition over 12 frames; transitions the camera motion doesn't motivate; three or more styles in one reel.
- Cap: 1 stylised transition per 5 cuts or more.
- No more than 3 flashes in any 1 s (WCAG 2.3.1 [O], https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html).

**Sound design layers** [C]
- **Riser:** 1-2 bars long, ending exactly on the drop cut, with its tail cut off.
- **Whoosh:** 6-15 frames. Offset the clip so its peak lands on the cut frame.
- **Impact/hit:** on the cut frame. Add a sub-boom for reveals and a reverse cymbal into reveals.
- **Text pops:** a soft click or pop on the text's first frame.
- Never stack more than 2 SFX on the same frame. Levels are in §4.

**Text animation** [C]
- Animate in over 4-8 frames with ease-out. Animate out over 3-6 frames, or hard-cut out on a beat. Land entrances on beats.
- Hold each card for at least `max(0.83 s, 0.3 s × words + 0.3 s)`.
- One headline plus at most one support line on screen.
- TikTok advises 5-10 words per second for ad overlays [O]. That's for punchy bursts; sustained text stays at or under 3 words per second.

### 3b. Product demos and screen recordings
**Capture**
- Record at 1440p or 4K, or at 2x display scale, so zooms stay sharp. 60 fps when the demo involves scrolling or drag.
- Use demo data. **Blur or redact emails, API keys, tokens and customer names** before export.

**Zoom-ins** [C]
- 125-150% for a panel, about 200% for a button or field. Ease in and out over 12-18 frames at 30p (0.4-0.6 s).
- Stay zoomed for 1.5-3 s, or until the action's result is visible. A zoom that doesn't show the result is decoration.
- Zoom out to re-orient before moving to a different screen area. No more than 1 zoom move every 3-5 s, and no zoom pumping while the user types.
- Sources: https://www.nemovideo.com/blog/ai-video-workflows/screen-studio-review and https://screen.studio/

**Cursor** [C]
- Enlarge 1.5-2x and smooth its movement.
- Use one consistent click highlight (ripple 200-300 ms). Hide the cursor once it has been idle for more than 1 s.
- Optional spotlight: dim the rest of the UI 30-50%.

**Hold on a UI state** [C]
- Simple result: at least 2 s.
- Dense dashboard or table: 3-5 s, plus about 1 s for each extra line the viewer has to read.
- Spinners and loading: cut them, or speed up 4-8x leaving about 0.5 s visible so it still reads as real.
- Mouse travel longer than 0.5 s: speed it up.

**Pacing and voiceover** [C]
- Show the product within 5 s. One idea every 5-10 s.
- Write the script first, record the VO, then cut picture to the VO at 140-160 wpm.
- The VO names a control 0.3-0.5 s before the click or zoom lands, so the eye arrives in time.

**Captions** [C]
- Burn them in for social; upload an SRT sidecar for YouTube and LinkedIn.
- Never lay captions over the UI being demonstrated. Use a band below the UI, or reposition per shot.

### 3c. Talking head and podcast
**Multicam switching** [C] (https://vidpros.com/how-to-edit-multi-camera-podcast-footage-step-by-step-video-workflow)
- Stay on the active speaker. Switch when the speaker changes and the new speaker talks for longer than 1.5-2 s.
- Don't cut for "yeah" or "mm-hm". Cut to a listener only for a meaningful reaction (laugh, surprise), for 1-2 s.
- Hold any angle for 3-10 s. Use the wide shot for crosstalk or shared laughter, and every 30-60 s to reset geography.
- Cut at phrase boundaries or on breaths, never mid-word.
- Solo talking head: alternate 100% and 115% framing across jump cuts.

**Silence and filler removal**
- Resolve's Ripple Delete Silence (Clip > Audio Operations) exposes Threshold, Pre Head, Post Tail and Minimum to Trip. It isn't Studio-only. Fairlight's "Remove Silence" is Studio-only.
- auto-editor defaults: margin 0.2 s, minimum cut 0.2 s, minimum clip 0.1 s [O] (https://auto-editor.com/ref/options).

| Setting [C] | Social / short-form | Long-form / podcast |
|---|---|---|
| Threshold | Noise floor + 8-10 dB. Typically -40 to -45 dBFS on a clean lav, -35 dBFS on a noisy room | same |
| Min silence to cut | 0.25-0.35 s | 0.6-1.0 s |
| Pre head (padding before speech) | 0.08-0.12 s | 0.15-0.25 s |
| Post tail (padding after speech) | 0.12-0.2 s | 0.25-0.4 s |
| Pause kept between sentences | 0.15-0.25 s | 0.3-0.5 s |

- Add a 10-20 ms audio crossfade on every cut so it doesn't click. Lay room tone under any gap.
- Remove isolated "um"/"uh". Keep a filler if cutting it creates a visible jump that has no B-roll or punch-in to cover it.

**J and L cuts** [C] (https://vimeo.com/blog/post/j-cuts-l-cuts)
- On a speaker change, bring the incoming speaker's audio in 6-15 frames (0.2-0.5 s) before their picture (J cut).
- Let audio trail 0.5-1 s over B-roll or a reaction (L cut).
- Use one or more J/L cuts every 3-4 speaker changes so the edit doesn't feel mechanical.

**B-roll cadence** [C]
- Short-form: some visual change (cut, punch-in, B-roll or text) every 2-4 s.
- Long-form: every 5-15 s, plus a pattern interrupt every 20-40 s.
- B-roll clips run 2-5 s and start on a word. Cover jump cuts and literal mentions (product, place, number).
- Never cover the hook line or emotional beats that play on the face.

**Dialogue chain.** In order. Resolve's free tools: Vocal Channel, Dialogue Processor, De-Esser, Noise Reduction FX, Dynamics, Limiter. Studio-only: Voice Isolation, Dialogue Separator, Audio Assistant.

| # | Step | Typical setting [C unless tagged] |
|---|---|---|
| 1 | Clip gain | Raw dialogue peaks around -12 dBFS before processing |
| 2 | High-pass | 70-100 Hz for male voices, 100-120 Hz for female, 12-24 dB/oct. Dialogue Processor's De-Rumble: 40-50 Hz is the safe setting [O manual] |
| 3 | Noise reduction | No more than 6-12 dB of reduction; stop before it sounds "underwater". Voice Isolation (Studio): Amount 70-80 [O manual] |
| 4 | Subtractive EQ | -2 to -4 dB at 200-400 Hz (mud/box), Q 2-3. Notch out room resonances |
| 5 | Compression | 3:1-4:1, attack 5-15 ms, release 80-200 ms, 3-6 dB gain reduction on peaks. Vocal Channel defaults to 1.5:1 at -25 dB, so raise the ratio. Sources: https://www.audacityteam.org/features/compressor/ and https://www.acast.com/en/blog/a-guide-to-vocal-compression-for-podcasters |
| 6 | Additive EQ | +1-3 dB at 3-5 kHz (presence). Optional +1-2 dB shelf at 10-12 kHz |
| 7 | De-ess | 6-7 kHz (Resolve's guidance [O manual]; sibilance spans 5-8 kHz). No more than 4-6 dB of reduction |
| 8 | Bus limiter / loudness | Ceiling -1 dBTP; integrated loudness to target (§1). Dialogue LRA 4-8 LU for phone playback |

### 3d. Event recaps and ads
**Structure** [C]

| Section | Time (30 s recap) | Content |
|---|---|---|
| Hook | 0-3 s | Best moment: crowd peak, bold claim, or the result |
| Context | 3-8 s | Event name, place, date (title or lower third) |
| Build | 8-22 s | Escalating montage (arrivals, talks, demos, people, energy) with 1-2 sound bites of 8 s or less |
| Payoff | 22-27 s | Peak moment: applause, winner, reveal, the strongest quote |
| CTA / end card | last 2-4 s | Logo, one verb-led CTA, URL or handle |

- Ad cutdowns: 6 s, 15 s and 30 s. TikTok: 9-15 s [R].
- B-roll ratio: about 70-80% B-roll to 20-30% sound bites for recaps; about 50/50 for testimonial ads [C].

**Music bed** [C]
- Pick a track with clear sections. Edit it to length on bar lines.
- End on the track's own ending (the "button") rather than a fade.
- Duck it under speech (§4).

**Lower thirds** [C]
- Name plus role/company, 2 lines max. Only on a person's first appearance.
- On screen 3-5 s; animate in over 8-12 frames.
- Position: 16:9 left-aligned at graphics-safe; 9:16 inside the safe rect, at y 1248 or above.

**End cards**
- Social: 2-4 s.
- YouTube end screen: 5-20 s at the end of the video [O].
- Keep every element inside the safe zone.

---

## 4. Universal rules

### Audio levels [C unless tagged]
| Element | Target |
|---|---|
| Programme | -14 LUFS integrated, -1 dBTP max (§1) |
| Dialogue | Short-term about -14 to -16 LUFS while speaking. Peaks -6 to -3 dBFS, average -20 to -12 dBFS |
| Music, no speech | Up to programme loudness (about -14 LUFS short-term) |
| Music under VO | 15-25 dB below the voice; start at -18 dB. Example: voice at -16 LUFS puts the bed around -34 to -38 LUFS. Duck attack 50-100 ms, release 300-800 ms (Fairlight Ducker or sidechain). Sources: https://www.overseeros.com/blog/background-music-volume-under-voiceover and https://sounddesign.irpr.agency/guides/how-to-mix-audio-for-youtube/ |
| SFX (impacts) | Peaks at or below -6 dBFS; sit 3-6 dB under music peaks, except hero hits |
| Whooshes, risers, UI clicks | 6-12 dB under the music; clicks -24 to -30 dBFS |
| QA | Check on phone speakers and on earbuds. Peak meters mislead, so judge by LUFS |

### Colour workflow, in order
1. **Colour management first.** Set the timeline to Rec.709 Gamma 2.4, or apply a CST on input (log or HLG to Rec.709) so balancing works on a normalized image (https://portrait.com/blog/cullen-kellys-color-grading-philosophy).
   - iPhone HDR (HLG) sources: transcode to ProRes keeping HLG, then CST Rec.2100 HLG to Rec.709 with tone mapping [C].
2. **Balance:** set the white/black point, then white balance along the temperature axis, then green/magenta (Cullen Kelly's two-axis method).
3. **Exposure** with Offset/Gain. Typical skin luma: 40-55% on the waveform for darker complexions, 55-70% for lighter [C].
4. **Contrast:** set the pivot. Blacks at 0-5%, highlights at or below 95-100%. No clipped faces.
5. **Saturation**, then **match shots** to one hero shot per scene: blacks, then whites, then mids, then RGB parade balance, then saturation. Compare side by side with a split-screen still. Resolve's Shot Match is only a starting point.
6. **Secondaries:** skin, sky, distracting colours.
7. **Look last**, at timeline level. Creative LUT or film look at a 60-80% key. Same look across the whole piece (https://gamut.io/how-to-color-grade-in-davinci-resolve-the-complete-step-by-step-guide/).
8. **Skin:** use the vectorscope's "Show Skin Tone Indicator" line. It sits at the traditional in-phase angle, a guide for average skin hue [O manual]. Hue should sit on or near the line for every complexion; saturation varies. Protect skin when pushing looks (qualifier or hue-vs-hue).
9. **Export tags:**
   - Rec.709 primaries, transfer and matrix (BT.709, H.273 value 1) [O YouTube]. Full range gets converted to limited [O].
   - Don't render Rec.709-A; it's only for Mac viewer monitoring [C] (https://forum.blackmagicdesign.com/viewtopic.php?p=562283).
   - Data levels: Auto/Video.

### Typography and caption readability
| Rule | Value |
|---|---|
| Caption size at 1080 width (9:16) | Start at 64 px (60-75 px range); never below 48 px [C] (https://blitzcutai.com/blog/best-caption-size-tiktok-2026). Word-pop 80-110 px. Headlines 90-140 px |
| Caption size at 1920x1080 | 48-60 px, about 4.5-5.5% of frame height [C]. Size it so 42 characters fit across [O Netflix] |
| Max characters per line | 16:9: 42 [O] (https://partnerhelp.netflixstudios.com/hc/en-us/articles/217350977-English-USA-Timed-Text-Style-Guide). 9:16: 22-26 at 64 px within the 696 px caption width [C, derived] |
| Lines on screen | 1 preferred, 2 max. In two-line captions make the bottom line the longer one [O Netflix] |
| Word-pop style | 1 line, 1-3 words (12-15 characters or fewer). Highlight the active word in the brand accent [C] (https://www.kapwing.com/explore/hormozi-style-captions-template) |
| Reading speed | 20 cps or less for adults (17 for kids) [O Netflix]; 160-180 wpm [O BBC, via https://clevercast.com/bbc-subtitling-guidelines] |
| Duration per caption | 0.83 s (5/6 s) to 7 s [O] (https://partnerhelp.netflixstudios.com/hc/en-us/articles/215758617). Leave a gap of 2 frames or more between captions [C] |
| Contrast | 4.5:1 or better against the background (WCAG 1.4.3 [O], https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). White fill with a black stroke of 8-12% of the font size, or a 60-80% black box, or a soft 50% shadow [C] |
| Font | Bold or extra-bold sans with tracking at 0 and line height 1.1-1.2. Two families max per piece [C] |
| Test | Play on a phone at arm's length with sound off [C] |

### Pacing heuristics [C]
- Rough average shot lengths: hype 0.5-1.5 s; recaps 1-2.5 s; ads 1.5-3 s; social talking head 2-5 s between visual changes; demos 3-8 s; long-form talking head 5-15 s.
- Cut as soon as the information or emotion has landed. Trim the breath before the first word; the first word starts in frames 0-6.
- Long-form: deliver value within 30 s, with no intro over 15 s. Add chapter or pattern breaks every 20-40 s.
- Cut on action, and mid-movement for whip and match cuts.
- Frame rate: project fps = the majority source fps. Never mix 25 and 30 in one timeline without Optical Flow retiming. Match the recorded rate on YouTube [O].

---

## 5. Export and file naming

**Free Resolve on Linux can't encode or decode H.264/HEVC.** Transcode sources to ProRes, render a **ProRes 422 HQ master** with 48 kHz/24-bit PCM, then encode deliverables with ffmpeg. Loudness should already be mixed to target in Fairlight before the master is rendered.

**Template: social vertical / YouTube** (set `-g` to fps/2: 15 at 30p, 30 at 60p)
```
ffmpeg -i master.mov -c:v libx264 -profile:v high -pix_fmt yuv420p -preset slow -crf 17 \
  -maxrate 20M -bufsize 40M -g 15 -bf 2 -x264-params open-gop=0 \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 320k -ar 48000 -movflags +faststart out.mp4
```
- X: same command, but cap `-maxrate 12M` and keep AAC-LC (ffmpeg's default AAC encoder is LC).

**Template: hero loop** (no audio; WebM listed first in the HTML)
```
ffmpeg -i loop.mov -an -vf scale=1920:-2 -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 26 -preset slow -movflags +faststart hero.mp4
ffmpeg -i loop.mov -an -vf scale=1920:-2 -c:v libvpx-vp9 -b:v 0 -crf 36 -row-mt 1 hero.webm
```

**Loudness QA:** `ffmpeg -i out.mp4 -af ebur128=peak=true -f null -` and read I (integrated), LRA and True peak from the summary. Fail anything off target by more than ±1 LU or over -1 dBTP.

**File naming** [C]: `YYYYMMDD_project_piece_platform_WxH_fps_vNN.ext`
- Lowercase, no spaces, ISO date, zero-padded version. Never "final".
- Example: `20261029_launch_hype_reels_1080x1920_30p_v03.mp4`
- Masters take `_master_prores` in place of `platform`. Caption sidecars use the same stem with `.srt`.

**Pre-export checklist** [C]
- [ ] Safe-zone overlay check on every text, logo and CTA frame
- [ ] Frame 1 is a strong still
- [ ] No black or flash frames, and no single-frame gaps (check edit points)
- [ ] Captions spell-checked; names and brand terms correct
- [ ] Loudness -14 LUFS / -1 dBTP; no clicks at edits
- [ ] Colour tags BT.709 (1-1-1); no clipped skin
- [ ] PII/secrets blurred in screen recordings
- [ ] Shorts with licensed music are under 60 s
- [ ] File name follows the convention

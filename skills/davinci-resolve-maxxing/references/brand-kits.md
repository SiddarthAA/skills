# Brand kits

The skill is brand-neutral. A video picks a kit; the kit decides fonts, colours, logo, look and end card.
Add a kit by copying the template section below. Fonts must be visible to Fusion: install them into
`~/.local/share/fonts/`, then `rv 'return R.has_font("<Family>")'` (the family name Fusion reports can differ
from the file name).

## Kit template
```
name:          <kit>
fonts:         headline <Family>/<Style>, body <Family>/<Style>   (as Fusion names them)
colours:       primary #hex (r,g,b 0-1), accent #hex, background #hex
text rules:    case, tracking, max words per card
shadows:       e.g. hard offset only / soft allowed
logo:          path (PNG with alpha for overlays)
look:          LUT (agent/<look>.cube) or "none"
end card:      layout, duration, CTA wording style
voice:         tone rules for on-screen copy
```

## Kit: failproof-ai (Failproof AI / fpai)
Source of truth: the `fpai-design` skill (`~/.claude/skills/fpai-design/`). Its rules win if they disagree with this.

| Item | Value |
|---|---|
| Fonts | Display: **Architype Stedelijk** (file `assets/fonts/architype-stedelijk.ttf` in fpai-design; Fusion family `ArchitypeStedelijkW00`, style `Regular`). Body: Inter or Open Sans |
| Text rules | Display type **always lowercase**, letter-spacing 0.11em (Text+ `CharacterSpacing` about 1.1, `R.title{tracking = 0.1}`). Blunt, technical, second person ("your agent"), **never "we"**. **No emoji** (use `->`, `[ ]`, block characters) |
| Colours | Pink `#e4587d` = {0.894, 0.345, 0.490}; mint `#66d1b5` = {0.400, 0.820, 0.710}; charcoal background `#131316` = {0.075, 0.075, 0.086}; bone text `#f0ece4` = {0.941, 0.925, 0.894}. **No third hue** |
| Shadows | Hard pixel offset only (e.g. 6 px, pink-dark `#a83a5a`). Never a blurred shadow. In Text+: a second shading element with an offset and no softness, or bake with prep |
| Logo | `~/.claude/skills/fpai-design/assets/logo/wordmark.png` (2260x720, light on dark). For overlays, key the dark background out: `ffmpeg -loop 1 -i wordmark.png -t 3 -vf "colorkey=0x0e0e10:0.12:0.05,format=yuva444p10le" -c:v prores_ks -profile:v 4 wordmark.mov` |
| Look | `agent/moody.cube` for hype/event, `agent/clean.cube` for demos |
| End card (2-3 s) | Charcoal background with faint pink/mint glows, wordmark centred, lowercase event/CTA line below in Architype, a row of pink/mint squares (the LED-wall motif). Pop the wordmark in over 5 frames; bass impact on its first frame |
| Event motifs | `[ building quality agents ]` style bracketed taglines; pink/mint pixel squares |

Shipped example: the Hacktober Hack event reel (Oct 2026) used this kit.

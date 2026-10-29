<div align="center">

<br>

# `skill`

**A personal arsenal of Claude skills — tuned workflows for shipping banger work.**

<br>

![Claude Code](https://img.shields.io/badge/Claude_Code-skills-D97757?style=flat-square&labelColor=1a1a1a)
![Status](https://img.shields.io/badge/status-shipping-2ea043?style=flat-square&labelColor=1a1a1a)
![Repo](https://img.shields.io/badge/repo-private-8b949e?style=flat-square&labelColor=1a1a1a)

<br>

[Skills](#skills) · [Install](#install) · [New skill](#new-skill) · [Anatomy](#anatomy)

</div>

<br>

## Skills

| Skill | What it does |
| :-- | :-- |
| *coming soon* | First drop incoming. |

## Install

```bash
gh repo clone SiddarthAA/skill ~/skill
mkdir -p ~/.claude/skills
ln -sf ~/skill/skills/* ~/.claude/skills/
```

`git pull` updates everything in place. Re-run the `ln` after adding a skill.

## New skill

```bash
cp -r template skills/<name>
```

Fill in `SKILL.md`, add a row to the table above, ship.

## Anatomy

```
skill/
├── skills/
│   └── <name>/
│       ├── SKILL.md       # frontmatter + instructions (required)
│       ├── scripts/       # helpers the skill runs (optional)
│       └── references/    # docs loaded on demand (optional)
└── template/
    └── SKILL.md           # copy me
```

<br>

<div align="center">
<sub>crafted with Claude · shipped by <a href="https://github.com/SiddarthAA">SiddarthAA</a></sub>
</div>

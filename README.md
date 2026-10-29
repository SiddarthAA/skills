<div align="center">

# skills

**skills to make fucking bag.**

<sub>harness-agnostic · plain markdown · drop-in</sub>

</div>

---

### Skills

| Skill | What it does |
| :-- | :-- |
| *soon* | First drop incoming. |

### Use

Each skill is a folder with a `SKILL.md`. Point any agent harness at it.

```bash
gh repo clone SiddarthAA/skills ~/skills
ln -sf ~/skills/skills/* ~/.claude/skills/   # or your harness's skills dir
```

### Add

```bash
cp -r template skills/<name>
```

### Layout

```
skills/<name>/
├── SKILL.md       # frontmatter + instructions
├── scripts/       # optional
└── references/    # optional
```

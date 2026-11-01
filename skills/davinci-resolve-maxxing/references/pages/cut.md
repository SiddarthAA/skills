# Cut page

A streamlined editor on the **same timelines** as the Edit page (manual ch. 33-39). Nothing on it is exclusive to the API: an agent builds
the same edits with `R.place`, `R.keep`, `AddTransition` and `R.fx` and never needs this page. Use it only to look, or when a human asks for it.

| Cut-page feature | Agent equivalent |
|---|---|
| Source Tape (every clip as one long tape), smart insert / append / ripple overwrite / close-up / place on top / source overwrite | `R.place` with explicit `at`/`from`/`len`, `R.keep` for back-to-back selects |
| Sync Bin (multicam-style angle picking) | `R.sync` + cut angles as clips (`pages/edit.md` > Multicam) |
| Dual timeline (upper overview + lower detail), trimming by dragging edits | Exact frames in code; check with `R.dump()` and `R.stills` |
| Transitions, Titles, Effects browsers | `AddTransition`, `R.title` / title templates, `R.fx` |
| Audio Mixer, Ducker (Inspector) | `pages/fairlight.md` |
| Smart Reframe, AI tools | Studio (`SmartReframe()` returns false on free). Use `R.frame` per cut |
| Timeline Resolution quick menu (vertical layouts) | `R.timeline(name, {w = 1080, h = 1920})` |
| Quick Export (top-right) | API `RenderWithQuickExport` did nothing in our tests: use `R.render` + `finish.py` |
| Bypass grades/Fusion, export current frame | `R.still` (Edit page grab; works for every page's result) |

Open with Shift+3 or `resolve:OpenPage("cut")`. Its layout differs from the Edit page: screenshot before any click (`references/gui.md`).
The Photo page (Shift+2, new in 21) is for stills grading/tethering and isn't used for video work.

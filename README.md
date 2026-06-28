<div align="center">

<img src="icon.svg" width="120" height="120" alt="DCKit logo" />

<h1>DCKit</h1>

<p><strong>A modular developer console framework for Godot 4</strong></p>

[![GDScript](https://img.shields.io/badge/GDScript-Godot%204-0b39e4?style=flat-square&logoColor=white)](https://godotengine.org)
[![License](https://img.shields.io/badge/License-MIT-26dbc2?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-fa3c91?style=flat-square)]()

---

```
> player.warp (vec3 12 0 8)   ↵
✓ warped to (12, 0, 8) in 0.3 ms
```

</div>

---

DCKit gives Godot 4 projects a full-featured in-game developer console — from the parser that reads what you type, to the syntax-highlighted input field that shows it, to the command pipeline that runs it.

Everything is modular. Drop in the commands you need, skip the ones you don't, and extend without touching the core.

## What's inside

**Pipeline** — Lexer → Parser → Semantic Analyzer → Executor, all wired together. Lazy argument evaluation means control flow commands (`if`, `try`, `while`, `repeat`) short-circuit naturally with no special handling.

**Input** — `CodeEdit`-backed command field with inline token coloring, chip backgrounds, color previews, and squiggly error underlines drawn at the pixel level.

**Registry** — Segment-aware command lookup with ranked prefix search. `var`, `var.set`, and `var.get` are all distinct, searchable keys.

**Docs** — Per-command BBCode descriptions, parameter hints, aliases, and deprecation notices rendered in a collapsible info panel — updated live as you type.

**Safety** — Independent argument-depth and execution-depth caps. Constructor type system with multi-signature support. Session logger with full call-stack ancestry on every entry.

## Quick start

```gdscript
# Register a command
_registry.register(
    DCDefinition.new(
        "player.warp",
        func(ctx: DCContext) -> DCResult:
            var pos = await ctx.arg(0)
            player.global_position = pos.as_vector3()
            return DCResult.ok("warped to %s" % pos),
        "Teleport the player to a [b]Vector3[/b] position.",
        [DCParam.new("position").describe("Target world-space position.")]
    )
)

# Open / close from anywhere
DCKit.toggle_console()
```

---

<div align="center">
<sub>Built for Godot 4 · GDScript · MIT License</sub>
</div>

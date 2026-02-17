# Refactored build (script replacements)

This zip contains targeted script replacements to reduce runtime reflection and make spell identity / Pack-a-Punch / HUD updates deterministic.

## Replaced / added scripts
- `Scripts/NodeUtil.gd` (new)
- `Scripts/SpellCaster.gd` (replaced)
- `PackAPunchService.gd` (replaced; autoload name should remain `PackAPunch`)
- `Scripts/PackAPunchMachine.gd` (replaced)
- `Scripts/HUD.gd` (replaced)
- `Scripts/SpellUtil.gd` (replaced)
- `Scripts/PlayerHealth.gd` (replaced)

## Required scene contract (damage)
For consistent damage application:
- Enemies should have a child node named `Health` with a script that implements `apply_damage(amount, hit?)`.

If your enemy colliders are children, `SpellUtil` will also check the collider's parent for `Health`.

## Spell identity
Set your SpellData resources:
- `spell_key` should be one of: `fireball`, `chainlightning`, `magicmissile`.
- `delivery_kind` should be the same (for compatibility).

## Folder cleanup
This zip does **not** move folders to avoid breaking scene/script paths.
Once this build is stable, you can reorganize by moving scripts and updating references in:
- scenes (`.tscn`), resources (`.tres`), and `project.godot`.

A safe target layout is:
- `Scripts/Util`
- `Scripts/UI`
- `Scripts/Gameplay`
- `Scripts/Systems`

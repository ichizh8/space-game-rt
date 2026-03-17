# Agent Task: v93

Implement 3 changes to the space game. This is a WebGL/WASM Godot 4 game.
WASM safety rule: never add_child/queue_free/hide from _process or signal callbacks — always use call_deferred.

---

## Change 1: localStorage saves for WebGL

In `scripts/save_manager.gd`, replace the IDBFS/FileAccess approach for Web builds with localStorage.
localStorage is synchronous and survives tab close reliably.

Replace the entire file with this approach:
- For `OS.get_name() == "Web"`: use localStorage via JavaScriptBridge
- For non-Web: keep FileAccess as-is
- Remove `_sync_web_fs()` entirely

Use base64 encoding to safely store JSON (avoids quote escaping issues in JS):

```gdscript
func _web_save(slot: int, json_string: String) -> void:
    var bytes: PackedByteArray = json_string.to_utf8_buffer()
    var b64: String = Marshalls.raw_to_base64(bytes)
    JavaScriptBridge.eval("localStorage.setItem('save_slot_%d', '%s');" % [slot, b64], true)

func _web_load(slot: int) -> String:
    var result = JavaScriptBridge.eval("localStorage.getItem('save_slot_%d') || '';" % slot, true)
    if result == null or str(result).is_empty():
        return ""
    var bytes: PackedByteArray = Marshalls.base64_to_raw(str(result))
    return bytes.get_string_from_utf8()

func _web_has_save(slot: int) -> bool:
    var result = JavaScriptBridge.eval("localStorage.getItem('save_slot_%d') !== null;" % slot, true)
    if result == null:
        return false
    return bool(result)
```

Update `save_game()`, `load_game()`, `has_save()`, `get_slot_summary()`, `delete_save()` to branch on `OS.get_name() == "Web"` and call the appropriate helpers.

For delete_save on Web:
```gdscript
JavaScriptBridge.eval("localStorage.removeItem('save_slot_%d');" % slot, true)
```

---

## Change 2: Death respawn at nearest station + credit penalty

In `scripts/game_state.gd`, update `on_player_death()`:

1. Add credit penalty: `credits = int(credits * 0.75)` (lose 25%)
2. After setting hull/fuel/resources, find nearest station and set `saved_player_pos`
3. Emit `credits_changed` signal

Add a new method `_find_nearest_station_pos() -> Vector2`:
- Load sector script: `var sector_script = load("res://data/sector_%d.gd" % current_sector)`
- Instantiate: `var sector_node := Node.new(); sector_node.set_script(sector_script)`
- Get stations: `var stations: Array = sector_node.get("STATIONS"); sector_node.free()`
- Find station closest to `saved_player_pos` (or Vector2.ZERO if no saved pos)
- Return that station's Vector2(pos_x, pos_y)
- If no stations found, return Vector2.ZERO

In `on_player_death()` call this:
```gdscript
var respawn: Vector2 = _find_nearest_station_pos()
if respawn != Vector2.ZERO:
    saved_player_pos = respawn
```

In `scripts/space_world.gd`, `_on_player_died()`:
- Replace `ship.global_position = Vector2.ZERO` with `ship.global_position = GameState.saved_player_pos`
- Keep `SaveManager.save_game()` (this now saves the post-death state with respawn position)

---

## Change 3: Consolidate saves in menus

In `scripts/planet_menu.gd`:
- Find the close/exit function (likely `_do_close()` or similar)
- Remove ALL `SaveManager.save_game()` calls from action handlers (building, trading, quests, etc.)
- Keep ONLY one `SaveManager.save_game()` call in the close function

In `scripts/station_menu.gd`:
- Same: remove all inline saves, keep only on close

In `scripts/cockpit.gd`:
- Same: remove all inline saves, keep only on close

This reduces save spam. The autosave (90s) and warp save cover the rest.

---

## After changes

Run parse check:
```
for f in scripts/*.gd; do /Applications/Godot.app/Contents/MacOS/Godot --headless --check-only --script "$f" 2>&1 | grep -i "parse error" && echo "ERROR in $f"; done
```

Fix any parse errors.

Commit:
```
git add -A && git commit -m "v93: localStorage saves for WebGL, respawn at nearest station, credit penalty on death, consolidated saves"
```

Export:
```
/Applications/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" web-export/index.html 2>&1 | tail -5
```

Deploy to gh-pages (worktree at /tmp/gh-pages-deploy):
```
cp web-export/index.html web-export/index.js web-export/index.pck web-export/index.wasm /tmp/gh-pages-deploy/ 2>/dev/null || cp web-export/* /tmp/gh-pages-deploy/
cd /tmp/gh-pages-deploy && git add -A && git commit -m "v93" && git push
```

When completely finished, run:
```
openclaw system event --text "Done: v93 deployed - localStorage saves, nearest station respawn, credit penalty on death" --mode now
```

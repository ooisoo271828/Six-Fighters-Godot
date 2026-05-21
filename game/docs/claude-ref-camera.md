# Camera System Reference

Full design doc: `docs/camera_system_design.md`

## Architecture: Anchor-Follow System

```
Player Input → CameraAnchor → Camera2D (child, hard follow)
                    ↓ soft follow (350px radius)
               Heroes (formation offset + AI offset)
```

- **CameraAnchor** (`scripts/dev/camera_anchor.gd`) — Node2D controlled by WASD/joystick, moves at 250 px/s
- **Camera2D** — child of CameraAnchor, smoothing 5.0, `current = true`
- **Soft follow radius**: 350px — heroes can freely move within this circle around the anchor
- **Hard limit**: 480px — hero teleports back to anchor position if exceeded
- **Emergency catch-up**: lerp speed 8.0/s when outside 350px (normal is 3.0/s)

## Direction Systems (Decoupled)

| System | Directions | Detail |
|--------|-----------|--------|
| Character facing | **4 directions** (up/down/left/right) | Quantized from movement vector; 2+2 fallback supported |
| Projectile flight | **360 degree free** | Not constrained by character facing; full mathematical freedom |

## Scene Layout (Portrait 540x960)

```
Y: 0~350   Enemy zone     ← targets/dummies appear here
Y: 200~750 Combat zone    ← projectile flight space
Y: 600~960 Hero zone      ← caster/heroes positioned here
```

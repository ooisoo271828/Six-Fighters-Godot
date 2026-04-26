# Six Fighters — Godot

A vertical (9:16 portrait) top-down 2D fighter game built with Godot 4.x, developed via VibeCoding.

## Repository Structure

```
Six-Fighters-Godot/
├── game/                        # Godot game project
│   ├── project.godot            # Main project file
│   ├── scenes/                  # Game scenes (arena, hub, dev tools...)
│   ├── scripts/                 # GDScript game logic
│   ├── addons/                  # Godot editor plugins (HasturOperationGD)
│   ├── assets/                  # Game assets (textures, etc.)
│   ├── resources/               # Data resources (.tres skill definitions)
│   ├── tools/                   # Python dev tooling (editor_call.py, hastur.py)
│   └── docs/                    # Game design documents
├── broker/                      # Broker server + plugin source
│   └── hastur-operation-plugin-main/
│       ├── broker-server/       # Node.js broker (localhost:5301 TCP / 5302 HTTP)
│       ├── addons/              # Godot plugin source
│       ├── godot-docs/          # Plugin documentation
│       └── openspec/            # OpenAPI specification
└── docs/                        # Top-level project documents
    └── HasturOperationGD-Technical-Whitepaper.md
```

## Getting Started

### Prerequisites
- Godot 4.x Editor
- Node.js 18+ (for broker server)

### Quick Start

1. Clone the repo
2. Open `game/` in Godot Editor
3. Enable the HasturOperationGD plugin (Project → Plugins)
4. Start the broker: `cd broker/hastur-operation-plugin-main/broker-server && npm install && npm run dev`
5. Play!

## Key Systems

- **Camera System**: CameraAnchor soft-follow system — player controls the camera center, heroes follow within a 350px radius. See `game/docs/camera_system_design.md`.
- **Skill System**: Modular skill effects (projectile, area, burst, status) + modifier pipeline (scatter, bounce, fission, curved path...). See `game/docs/`.
- **AI Integration**: HasturOperationGD plugin allows AI agents to execute GDScript in the editor via REST API for rapid prototyping.

## Development

Use the Python CLI tools in `game/tools/`:
```bash
python tools/hastur.py status   # Check broker + Godot connection
python tools/editor_call.py --health  # Quick health check
```

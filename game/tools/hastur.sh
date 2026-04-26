#!/bin/bash
# =============================================================================
# Hastur CLI — thin wrapper around hastur.py (Python 3.12)
# =============================================================================
# Usage:
#   ./tools/hastur.sh health              — Check broker health
#   ./tools/hastur.sh executors           — List connected executors
#   ./tools/hastur.sh exec '<code>'       — Execute GDScript code
#   ./tools/hastur.sh scene-tree          — Get current scene tree
#   ./tools/hastur.sh start/stop/restart  — Manage broker-server
#   ./tools/hastur.sh status              — Full status overview (default)
# =============================================================================

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
exec python "$DIR/hastur.py" "$@"

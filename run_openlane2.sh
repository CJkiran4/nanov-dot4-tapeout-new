#!/usr/bin/env bash
# Run the project's exploratory OpenLane 2 SKY130 RTL-to-GDSII flow.
# Prerequisites: Docker daemon available and OpenLane 2 installed in the current PATH.
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="$REPO_ROOT/nanov_dot4_project_v6.tar.gz"
WORK_ROOT="${WORK_ROOT:-$HOME/work/nanov_dot4_openlane}"
PROJECT="$WORK_ROOT/nanov_dot4"
RUN_STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$WORK_ROOT/logs"
LOG_FILE="$LOG_DIR/openlane2_$RUN_STAMP.log"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$ARCHIVE" ]] || die "Missing archive: $ARCHIVE"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v openlane >/dev/null 2>&1 || die "OpenLane 2 is not in PATH. Activate your OpenLane virtual environment first."
command -v docker >/dev/null 2>&1 || die "Docker CLI not found. Install Docker or Docker Desktop + WSL integration."
docker info >/dev/null 2>&1 || die "Docker daemon is not reachable. Start Docker and verify 'docker info'."

mkdir -p "$WORK_ROOT" "$LOG_DIR"

# Re-extract to a dedicated work folder; do not change the cloned Git repository.
tar -xzf "$ARCHIVE" -C "$WORK_ROOT"
[[ -f "$PROJECT/openlane/config.json" ]] || die "Expected OpenLane config not found under $PROJECT/openlane"
[[ -f "$PROJECT/openlane/run_openlane.sh" ]] || die "OpenLane runner script is missing"

export PDK="${PDK:-sky130A}"
export PDK_ROOT="${PDK_ROOT:-$HOME/.volare}"

echo "Project: $PROJECT"
echo "PDK: $PDK"
echo "PDK_ROOT: $PDK_ROOT"
echo "Log: $LOG_FILE"

echo
echo "===== Sync and validate Tiny Tapeout RTL copies ====="
(
  cd "$PROJECT"
  bash scripts/sync_tt_src.sh
)

# OpenLane 2 restricts JSON-configured source globs to files inside DESIGN_DIR.
# The archive originally points to ../tt/src/*.v, which OpenLane rejects.
# Stage a fresh copy inside openlane/src and adjust only the extracted working copy.
SOURCE_DIR="$PROJECT/openlane/src"
mkdir -p "$SOURCE_DIR"
find "$SOURCE_DIR" -maxdepth 1 -type f \
  \( -name '*.v' -o -name '*.sv' -o -name '*.vh' -o -name '*.svh' \) -delete
shopt -s nullglob
RTL_FILES=( "$PROJECT/tt/src/"*.v )
shopt -u nullglob
[[ ${#RTL_FILES[@]} -gt 0 ]] || die "No .v source files found under $PROJECT/tt/src"
cp -f "${RTL_FILES[@]}" "$SOURCE_DIR/"
echo "Staged ${#RTL_FILES[@]} Verilog source files inside $SOURCE_DIR"

python3 - "$PROJECT/openlane/config.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
cfg = json.loads(path.read_text())
cfg["VERILOG_FILES"] = "dir::src/*.v"
path.write_text(json.dumps(cfg, indent=2) + "\n")
print("Prepared working config: VERILOG_FILES=dir::src/*.v")
PY

echo
echo "===== Verify OpenLane design config and top module ====="
python3 - "$PROJECT/openlane/config.json" "$PROJECT/tt/src/tt_um_nanov_dot4_accel.v" <<'PY'
import json
import re
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
top_path = Path(sys.argv[2])
cfg = json.loads(config_path.read_text())
design = cfg.get("DESIGN_NAME")
source_text = top_path.read_text()
if not design:
    raise SystemExit("ERROR: DESIGN_NAME missing in config.json")
if not re.search(r'\bmodule\s+' + re.escape(design) + r'\b', source_text):
    raise SystemExit(f"ERROR: DESIGN_NAME={design!r} not declared in {top_path.name}")
print(f"DESIGN_NAME={design} matches the top module source.")
print(f"CLOCK_PORT={cfg.get('CLOCK_PORT')}; CLOCK_PERIOD={cfg.get('CLOCK_PERIOD')} ns")
print(f"FP_SIZING={cfg.get('FP_SIZING')}; FP_CORE_UTIL={cfg.get('FP_CORE_UTIL')}")
PY

echo
echo "===== Run OpenLane 2 ====="
set +e
(
  cd "$PROJECT/openlane"
  bash ./run_openlane.sh
) 2>&1 | tee "$LOG_FILE"
rc=${PIPESTATUS[0]}
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "OpenLane failed with exit code $rc. Log: $LOG_FILE" >&2
  echo "Inspect the first error in the log before changing RTL or constraints." >&2
  exit "$rc"
fi

echo
echo "===== GDSII outputs ====="
mapfile -t GDS_FILES < <(find "$PROJECT/openlane/runs" -type f -name '*.gds' -print 2>/dev/null | sort)
if [[ ${#GDS_FILES[@]} -eq 0 ]]; then
  echo "OpenLane returned success, but no .gds file was found; inspect run metrics and logs." >&2
  exit 20
fi
printf '%s\n' "${GDS_FILES[@]}"

echo
echo "===== Metrics, timing and physical-check reports ====="
find "$PROJECT/openlane/runs" -type f \
  \( -name 'metrics.json' -o -name '*.rpt' -o -iname '*drc*' -o -iname '*lvs*' -o -iname '*antenna*' \) \
  -print 2>/dev/null | sort || true

echo
echo "GDS file(s) were produced. This exploratory relative-floorplan run is not by itself proof of Tiny Tapeout fit or tapeout signoff."
echo "Review the final metrics for timing, route completion, DRC, LVS, antenna checks and area."

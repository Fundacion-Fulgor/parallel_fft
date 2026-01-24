#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Description:
#   Sync only the selected RTL + minimal LibreLane files into the Docker shared
#   folder, avoiding heavy artifacts and LibreLane runs. Then  start
#   the Docker/X11 IC design tools environment with `make start`.
#
# Usage:
#   ./sync_and_start.sh
#
# Environment overrides:
#   PROJECT_SRC=/path/to/parallel_fft \
#   TOOLS_DIR=/path/to/uniccass-icdesign-tools \
#   SHARED_DIR=/path/to/shared_xserver \
#   DEST_DIR=/path/to/shared_xserver/FFT/parallel_fft \
#   START_DOCKER=1 \
#   CLEAN_OLD_CONTAINERS=1 \
#   ./sync_and_start.sh
# ------------------------------------------------------------------------------

# ===== CONFIG =====
PROJECT_SRC="${PROJECT_SRC:-$HOME/Escritorio/parallel_fft}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/uniccass-icdesign-tools}"
SHARED_DIR="${SHARED_DIR:-$TOOLS_DIR/shared_xserver}"
DEST_DIR="${DEST_DIR:-$SHARED_DIR/FFT/parallel_fft}"

# These are just informational for the user (mount point inside container)
CONTAINER_SHARED_ROOT="${CONTAINER_SHARED_ROOT:-/home/designer/shared}"
DEST_IN_CONTAINER="${DEST_IN_CONTAINER:-$CONTAINER_SHARED_ROOT/FFT/parallel_fft}"

# Start docker environment after syncing?
START_DOCKER="${START_DOCKER:-1}"

# Prevent "container name already in use" by removing old tool containers first?
CLEAN_OLD_CONTAINERS="${CLEAN_OLD_CONTAINERS:-1}"

# ===== CHECKS =====
if [[ ! -d "$PROJECT_SRC" ]]; then
  echo "ERROR: PROJECT_SRC does not exist: $PROJECT_SRC"
  exit 1
fi

if [[ ! -d "$PROJECT_SRC/design/rtl" || ! -d "$PROJECT_SRC/librelane" ]]; then
  echo "ERROR: PROJECT_SRC does not look like the expected repo layout."
  echo "Expected: $PROJECT_SRC/design/rtl and $PROJECT_SRC/librelane"
  exit 1
fi

if [[ ! -d "$TOOLS_DIR" ]]; then
  echo "ERROR: TOOLS_DIR does not exist: $TOOLS_DIR"
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "ERROR: rsync is not installed."
  echo "  sudo apt-get update && sudo apt-get install -y rsync"
  exit 1
fi

mkdir -p "$DEST_DIR"

# ===== EXACT RTL FILE LIST (matching your VERILOG_FILES) =====
RTL_FILES=(
  # Top / FFT
  "design/rtl/top_chip.v"
  "design/rtl/fft32.v"
  "design/rtl/fft8.v"
  "design/rtl/fft4.v"

  # Datapath helpers
  "design/rtl/buffer_parallel2serial.v"
  "design/rtl/clip_round.v"
  "design/rtl/round.v"
  "design/rtl/shift_r2.v"
  "design/rtl/shift_r4.v"

  # MDC8P
  "design/rtl/fft_mdc_8p/fft_mdc_8p.v"
  "design/rtl/fft_mdc_8p/ctrl_in/mdc8p_ctrl_in.v"
  "design/rtl/fft_mdc_8p/ctrl_out/mdc8p_ctrl_out.v"
  "design/rtl/fft_mdc_8p/stages/mdc8p_stage1.v"
  "design/rtl/fft_mdc_8p/stages/mdc8p_stage2.v"
  "design/rtl/fft_mdc_8p/stages/mdc8p_stage3.v"

  # Twiddles
  "design/rtl/twiddle_interface/twiddle_interface.v"

  # Common modules
  "design/rtl/common_modules/btfly_2.v"
  "design/rtl/common_modules/btfly_4.v"
  "design/rtl/common_modules/btfly_8.v"
  "design/rtl/common_modules/complex_multiplier.v"
  "design/rtl/common_modules/ds_switch.v"
  "design/rtl/common_modules/rx_serializer.v"
  "design/rtl/common_modules/tx_serializer.v"
  "design/rtl/common_modules/xfft_cell.v"
  "design/rtl/common_modules/signal_generator.v"

  # Debug / CDC / SPI (use THIS one)
  "design/rtl/debug_unit/debug_system.v"
  "design/rtl/debug_unit/debug_unit.v"
  #"design/rtl/debug_unit/cdc_snapshot.v"
  "design/rtl/debug_unit/spi_slave_mode0.v"
)

# Minimal extra files (small + useful)
EXTRA_PATHS=(
  "librelane/config.yaml"
  "librelane/constraints/" 
  "librelane/irdrop/vpwr.csv"
  "librelane/irdrop/vgnd.csv"  
  "project.yml"
  "README.md"
  "constraints/"
  "librelane/scripts/"
)


# ===== SYNC (minimal) =====
echo "==> Syncing ONLY the selected VERILOG_FILES + minimal config into: $DEST_DIR"

tmp_list="$(mktemp)"
{
  for p in "${EXTRA_PATHS[@]}"; do echo "$p"; done
  for f in "${RTL_FILES[@]}"; do echo "$f"; done
} > "$tmp_list"

# rsync options
RSYNC_EXTRA=()
if rsync --help 2>/dev/null | grep -q -- '--ignore-missing-args'; then
  RSYNC_EXTRA+=(--ignore-missing-args)
fi

rsync -a --delete --prune-empty-dirs "${RSYNC_EXTRA[@]}" \
  --files-from="$tmp_list" \
  --exclude 'librelane/**/runs/' \
  --exclude 'runs/' \
  --exclude 'build/' \
  --exclude '*.vcd' \
  --exclude '*.vvp' \
  --exclude '__pycache__/' \
  --exclude '.pytest_cache/' \
  "$PROJECT_SRC"/ "$DEST_DIR"/

rm -f "$tmp_list"

# ===== Helper script to run LibreLane inside the container (your preferred style) =====
cat > "$DEST_DIR/run_librelane.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Project root (this script lives in the project root)
DESIGN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default config inside the synced project
CONFIG_PATH="${CONFIG_PATH:-$DESIGN_DIR/librelane/config.yaml}"

# Default PDK (override with PDK_NAME=... or PDK=...)
PDK_NAME="${PDK_NAME:-${PDK:-ihp-sg13g2}}"

# If the first arg looks like a yaml path, treat it as config path (to match your habit)
# Examples:
#   ./run_librelane.sh
#   ./run_librelane.sh librelane/config.yaml
#   ./run_librelane.sh librelane/config.yaml --last-run --flow OpenInOpenROAD
if [[ "${1:-}" == *.yaml || "${1:-}" == *.yml ]]; then
  CONFIG_PATH="$DESIGN_DIR/$1"
  shift
fi

exec librelane --pdk "$PDK_NAME" --design-dir "$DESIGN_DIR" "$CONFIG_PATH" "$@"
EOF
chmod +x "$DEST_DIR/run_librelane.sh"

echo "==> Done."
echo "Host (shared) project path: $DEST_DIR"
echo "Container project path (expected): $DEST_IN_CONTAINER"
echo ""
echo "Inside the container you can run:"
echo "  cd $DEST_IN_CONTAINER"
echo "  ./run_librelane.sh"
echo "  ./run_librelane.sh --last-run --flow OpenInOpenROAD"
echo "  ./run_librelane.sh --last-run --flow OpenInKLayout"
echo ""

# ===== RUN DOCKER =====
if [[ "$START_DOCKER" == "1" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed or not in PATH."
    exit 1
  fi

  if [[ "$CLEAN_OLD_CONTAINERS" == "1" ]]; then
    # Remove any existing unic-cass-tools containers to avoid name conflicts
    existing="$(docker ps -a --format '{{.Names}}' | grep -E '^unic-cass-tools-' || true)"
    if [[ -n "$existing" ]]; then
      echo "==> Removing existing unic-cass-tools containers to avoid name conflicts:"
      echo "$existing"
      while read -r n; do
        [[ -n "$n" ]] && docker rm -f "$n" >/dev/null
      done <<< "$existing"
    fi
  fi

  echo "==> Starting Docker environment (make start)..."
  cd "$TOOLS_DIR"
  make start
else
  echo "==> START_DOCKER=0 set, so I won't run make start."
fi

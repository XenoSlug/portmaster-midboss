#!/bin/bash
# ==============================================================================
# PortMaster Launch Script for MidBoss
# ==============================================================================

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
source "$controlfolder/tasksetter"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Dynamic GAMEDIR Detection
GAMEDIR=""
for dir in \
  "$directory/ports/midboss" \
  "/mnt/mmc/ports/midboss" \
  "/mnt/sdcard/ports/midboss" \
  "/roms/ports/midboss" \
  "/userdata/roms/ports/midboss" \
  "$(dirname "$0")/midboss"; do
  if [ -d "$dir" ]; then
    GAMEDIR="$dir"
    break
  fi
done
[ -z "$GAMEDIR" ] && GAMEDIR="/$directory/ports/midboss"

cd "$GAMEDIR"
mkdir -p "$GAMEDIR/gamedata"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Auto-copy boxart & preview to muOS catalogue if running on muOS
for cat_dir in "/mnt/mmc/MUOS/info/catalogue" "/mnt/sdcard/MUOS/info/catalogue"; do
  if [ -d "$cat_dir" ]; then
    for pdir in "Ports" "PORTS" "ports"; do
      mkdir -p "$cat_dir/$pdir/box" "$cat_dir/$pdir/preview" 2>/dev/null
      [ -f "$GAMEDIR/cover.png" ] && cp -f "$GAMEDIR/cover.png" "$cat_dir/$pdir/box/MidBoss.png" 2>/dev/null
      [ -f "$GAMEDIR/screenshot.png" ] && cp -f "$GAMEDIR/screenshot.png" "$cat_dir/$pdir/preview/MidBoss.png" 2>/dev/null
    done
  fi
done

$ESUDO chmod +x "$GAMEDIR/tools/patchscript" 2>/dev/null || true
$ESUDO chmod +x "$GAMEDIR/tools/splash" 2>/dev/null || true

# Setup Mono runtime
monodir="$HOME/mono"
monofile="$controlfolder/libs/mono-6.12.0.122-aarch64.squashfs"

# Process state & cleanup trap
GPTOKEYB_PID=""

cleanup() {
  echo "[MidBoss] Cleaning up..."
  if [ -n "$GPTOKEYB_PID" ]; then
    kill "$GPTOKEYB_PID" 2>/dev/null
    wait "$GPTOKEYB_PID" 2>/dev/null
  fi
  if [ -d "$monodir" ]; then
    $ESUDO umount "$monodir" 2>/dev/null || true
  fi
  if [ -f "$controlfolder/control.txt" ]; then
    pm_finish
  fi
}
trap cleanup EXIT INT TERM

if [ ! -f "$monofile" ] && [ -f "$controlfolder/harbourmaster" ]; then
  echo "Runtime mono missing, downloading via harbourmaster..."
  $controlfolder/harbourmaster --quiet --no-check runtime_check "mono-6.12.0.122-aarch64.squashfs"
fi

if [ -f "$monofile" ]; then
  $ESUDO mkdir -p "$monodir"
  $ESUDO umount "$monofile" 2>/dev/null || true
  $ESUDO mount "$monofile" "$monodir"
else
  pm_message "Mono runtime missing! Please update PortMaster runtimes."
  sleep 5
  exit 1
fi

# Check if game needs setup / patching
if [ ! -f "$GAMEDIR/gamedata/MidBoss.exe" ]; then
  if [ -f "$controlfolder/utils/patcher.txt" ]; then
    export PATCHER_FILE="$GAMEDIR/tools/patchscript"
    export PATCHER_GAME="MidBoss"
    export PATCHER_TIME="1 to 2 minutes"
    source "$controlfolder/utils/patcher.txt"
  else
    echo "Running patchscript directly..."
    bash "$GAMEDIR/tools/patchscript"
  fi
fi

if [ ! -f "$GAMEDIR/gamedata/MidBoss.exe" ]; then
  echo "Error: MidBoss.exe not found in $GAMEDIR/gamedata!"
  pm_message "MidBoss files missing! Place MidBoss-Linux-142-bin in ports/midboss/gamedata/"
  sleep 5
  exit 1
fi

# Setup saves
mkdir -p "$GAMEDIR/savedata"
bind_directories ~/.local/share/MidBoss "$GAMEDIR/savedata"

cd "$GAMEDIR/gamedata"

# Remove bundled old Mono/System assemblies and old FNA in favor of PortMaster modern FNA and runtime
rm -f mscorlib.dll System*.dll Mono*.dll FNA.dll FNA.dll.config monoconfig monomachineconfig 2>/dev/null || true
rm -rf lib lib64 lib32 2>/dev/null || true

# Environment variables for FNA & Mono
export MONO_IOMAP=all
export FNA_SDL2_FORCE_BASE_PATH=0
export MONO_PATH="$GAMEDIR/dlls:$GAMEDIR/gamedata"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$monodir/lib:$LD_LIBRARY_PATH"
export PATH="$monodir/bin:$PATH"
export FNA3D_FORCE_DRIVER=OpenGL
export FNA3D_OPENGL_FORCE_ES3=1
export FNA3D_OPENGL_FORCE_VBO_DISCARD=1

# Display loading splash
if [ -f "$GAMEDIR/tools/splash" ] && [ -f "$GAMEDIR/splash.png" ]; then
  $ESUDO "$GAMEDIR/tools/splash" "$GAMEDIR/splash.png" 4000 &
fi

# Launch gptokeyb
$GPTOKEYB "mono" -c "$GAMEDIR/midboss.gptk" &
GPTOKEYB_PID=$!
pm_platform_helper "$monodir/bin/mono" >/dev/null

$TASKSET mono --ffast-math -O=all MidBoss.exe -novsync 2>&1 | tee "$GAMEDIR/log.txt" /dev/tty0

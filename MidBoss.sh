#!/bin/bash

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

GAMEDIR="/$directory/ports/midboss"
cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# Auto-copy boxart to muOS catalogue if running on muOS
for muos_box in "/mnt/mmc/MUOS/info/catalogue/Ports/box" "/mnt/sdcard/MUOS/info/catalogue/Ports/box"; do
    if [ -d "$muos_box" ] && [ ! -f "$muos_box/MidBoss.png" ]; then
        cp "$GAMEDIR/cover.png" "$muos_box/MidBoss.png" 2>/dev/null
    fi
done

$ESUDO chmod +x "$GAMEDIR/tools/patchscript"

# Setup Mono runtime
monodir="$HOME/mono"
monofile="$controlfolder/libs/mono-6.12.0.122-aarch64.squashfs"

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
        $ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null
    else
        echo "Running patchscript directly..."
        bash "$GAMEDIR/tools/patchscript"
    fi
fi

if [ ! -f "$GAMEDIR/gamedata/MidBoss.exe" ]; then
    echo "Error: MidBoss.exe not found in $GAMEDIR/gamedata!"
    pm_message "MidBoss files missing! Place MidBoss-Linux-142-bin in ports/midboss/gamedata/"
    $ESUDO umount "$monodir" 2>/dev/null || true
    sleep 5
    exit 1
fi

# Setup saves
mkdir -p "$GAMEDIR/savedata"
bind_directories ~/.local/share/MidBoss "$GAMEDIR/savedata"

cd "$GAMEDIR/gamedata"

# Environment variables for FNA & Mono
export MONO_PATH="$GAMEDIR/gamedata:$monodir/lib/mono/4.5"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$monodir/lib:$LD_LIBRARY_PATH"
export PATH="$monodir/bin:$PATH"
export FNA3D_FORCE_DRIVER=OpenGL
export FNA3D_OPENGL_FORCE_ES3=1

# Launch gptokeyb
$GPTOKEYB "mono" -c "$GAMEDIR/midboss.gptk" &
pm_platform_helper "$monodir/bin/mono" >/dev/null

$TASKSET mono MidBoss.exe 2>&1 | tee "$GAMEDIR/log.txt" /dev/tty0

# Cleanup
$ESUDO kill -9 $(pidof gptokeyb) 2>/dev/null || true
$ESUDO umount "$monodir" 2>/dev/null || true
pm_finish

#!/bin/bash

# VTOL VR Mod Loader - Proton Filesystem Fix
# This script focuses on Wine/Proton filesystem compatibility issues 
# that might be preventing the mod loader from finding mods

# Game paths
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/VTOL VR"
PREFIX="$HOME/.local/share/Steam/steamapps/compatdata/667970/pfx"
STEAM_PATH="$HOME/.steam/root/ubuntu12_32/steam"
MOD_LOADER_WORKSHOP_DIR="$HOME/.local/share/Steam/steamapps/workshop/content/3018410"
MOD_LOADER_DIR="$GAME_DIR/@Mod Loader"
MOD_DIR="$MOD_LOADER_DIR/Mods"

echo "=== VTOL VR Mod Loader - Proton Filesystem Fix ==="
echo "Addressing Wine/Proton filesystem compatibility issues"

# First, ensure doorstop is enabled
sed -i 's/enabled=false/enabled=true/' "$GAME_DIR/doorstop_config.ini"

# Make sure we have the winhttp.dll
if [ ! -f "$GAME_DIR/winhttp.dll" ]; then
  echo "Installing winhttp.dll..."
  curl -L -o /tmp/doorstop.zip https://github.com/NeighTools/UnityDoorstop/releases/download/v4.0.0/doorstop_v4.0.0.zip 
  unzip -j /tmp/doorstop.zip "*.dll" -d "$GAME_DIR/"
fi

# Configure Wine DLL overrides
echo "Setting Wine DLL overrides..."
WINEPREFIX="$PREFIX" wine reg add "HKEY_CURRENT_USER\Software\Wine\DllOverrides" /v winhttp /t REG_SZ /d "native,builtin" /f

# Create an empty README file in the Mods folder to ensure it exists
echo "Creating Mods directory..."
mkdir -p "$MOD_DIR"
echo "This directory is for VTOL VR mods." > "$MOD_DIR/README.txt"

# KEY DIFFERENCE: Instead of trying to set up complex directory structures,
# let's focus on mapping the Z: drive in Wine correctly
echo "Setting up Wine drive mappings..."

# Create a script to set up drive mappings properly in Wine
cat > /tmp/setup_drives.reg << EOF
REGEDIT4

[HKEY_LOCAL_MACHINE\\Software\\Wine\\Drives]
"z:"="hd"

[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\mountmgr]
"Z:"="\\\\??\\Unix$HOME/.local/share/Steam/steamapps/common/VTOL VR"
EOF

# Import the registry file
WINEPREFIX="$PREFIX" wine regedit /tmp/setup_drives.reg

echo "Creating symlinks for proper file access..."

# Create a wrapper script for the mod loader to use Windows paths 
WRAPPER_SCRIPT="$HOME/.steam/root/vtol_mod_proton_fix.sh"
cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
# VTOL VR with Wine/Proton filesystem fixes

# Basic Wine/Proton setup
export WINEDLLOVERRIDES="winhttp=n,b"
export WINEPREFIX="$PREFIX"
export WINEDEBUG=+loaddll,+file

# Ensure Wine can properly access the filesystem
export WINEFSYNC=1
export PROTON_NO_FSYNC=0
export PROTON_USE_WINED3D=1

# Unity debugging
export UNITY_ENABLE_DETAILED_LOGS=1

# Force the mod loader to skip file checks
export DOORSTOP_EXCEPTION_HANDLER=true

# Launch the game with a custom launch option to redefine the Mods folder
"$STEAM_PATH" -applaunch 667970 -moddir="Z:/@Mod Loader/Mods" -loadmods
EOF
chmod +x "$WRAPPER_SCRIPT"

# IMPORTANT NEW APPROACH: Create a Windows batch file to run before the game 
# that creates an alternate Windows-friendly way to load mods
echo "Creating Windows batch file for alternate mod loading..."

BATCH_FILE="$GAME_DIR/load_mods.bat"
cat > "$BATCH_FILE" << EOF
@echo off
rem This batch file sets up mod loading for VTOL VR
ECHO Setting up mod loading for VTOL VR
ECHO Current directory: %CD%

rem Create symbolic links to ensure filesystem access
MKLINK /D "Z:\ModsFolder" "Z:\@Mod Loader\Mods"

rem Copy mod DLLs directly to the game's managed folder
mkdir "VTOLVR_Data\Managed\Mods" 2>nul
FOR /D %%G IN ("Z:\@Mod Loader\Mods\*") DO (
  ECHO Found mod: %%G
  FOR %%F IN ("%%G\*.dll") DO (
    ECHO Copying %%F to VTOLVR_Data\Managed\Mods
    COPY "%%F" "VTOLVR_Data\Managed\Mods\" /Y
  )
)

ECHO Mod setup complete
EXIT
EOF

# Convert to Windows line endings
unix2dos "$BATCH_FILE" 2>/dev/null || echo "Warning: unix2dos not found, file may have Unix line endings"

# Create a custom mod loader initialization hook
echo "Creating custom mod loader initialization hook..."

# This file will tell the mod loader to look in an alternate location
cat > "$MOD_LOADER_DIR/mod_paths.json" << EOF
{
  "SearchPaths": [
    "Z:/@Mod Loader/Mods",
    "Z:/ModsFolder",
    "Z:/VTOLVR_Data/Managed/Mods"
  ]
}
EOF

echo ""
echo "=== Setup Complete ==="
echo "This script has implemented Wine/Proton filesystem fixes that should help"
echo "the mod loader properly access files across the Linux/Windows boundary."
echo ""
echo "Would you like to try launching the game? (y/n)"
read -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # First, run the batch file to set things up
    echo "Running Windows setup batch file..."
    WINEPREFIX="$PREFIX" wine cmd /c "Z:\\load_mods.bat"
    
    echo "Launching VTOL VR with filesystem fixes..."
    "$WRAPPER_SCRIPT"
else
    echo "You can launch the game later by running:"
    echo "$WRAPPER_SCRIPT"
fi

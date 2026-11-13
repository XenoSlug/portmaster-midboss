#!/usr/bin/env python3
"""
extract_midboss.py - Prepares MidBoss gamedata from any purchase (itch.io, Steam, Humble, GOG)
Supports: MidBoss-Linux-142-bin, Windows zip, Linux tar/zip, loose files, or subfolders
"""
import sys, os, zipfile, tarfile, shutil, tempfile

def find_case_insensitive(directory, target_name):
    """Finds a file or folder matching target_name regardless of case"""
    for root, dirs, files in os.walk(directory):
        for f in files:
            if f.lower() == target_name.lower():
                return os.path.join(root, f)
    return None

def move_tree(src_dir, dst_dir):
    """Safely merges/moves all contents from src_dir into dst_dir"""
    os.makedirs(dst_dir, exist_ok=True)
    for item in os.listdir(src_dir):
        s = os.path.join(src_dir, item)
        d = os.path.join(dst_dir, item)
        if os.path.isdir(s):
            if os.path.exists(d):
                move_tree(s, d)
            else:
                shutil.move(s, d)
        else:
            if os.path.exists(d):
                os.remove(d)
            shutil.move(s, d)

def cleanup_incompatibilities(gamedata_dir):
    """Removes x86 binaries and old Mono/FNA assemblies so PortMaster's modern ARM64 runtime is used"""
    for f in ["MidBoss.bin.x86", "MidBoss.bin.x86_64", "MidBoss", "mscorlib.dll", "FNA.dll", "FNA.dll.config", "monoconfig", "monomachineconfig"]:
        fp = os.path.join(gamedata_dir, f)
        if os.path.exists(fp):
            try:
                os.remove(fp)
            except Exception:
                pass

    # Remove System*.dll and Mono*.dll
    for f in os.listdir(gamedata_dir):
        fl = f.lower()
        if (fl.startswith("system") or fl.startswith("mono")) and fl.endswith(".dll"):
            try:
                os.remove(os.path.join(gamedata_dir, f))
            except Exception:
                pass

    for d in ["lib64", "lib32", "lib", "share"]:
        dp = os.path.join(gamedata_dir, d)
        if os.path.exists(dp) and os.path.isdir(dp):
            try:
                shutil.rmtree(dp)
            except Exception:
                pass

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gamedir = os.path.abspath(os.path.join(script_dir, ".."))
    gamedata_dir = os.path.join(gamedir, "gamedata")
    os.makedirs(gamedata_dir, exist_ok=True)

    print("=== MidBoss Asset Preparation ===")
    print(f"Game directory: {gamedir}")
    print(f"Gamedata directory: {gamedata_dir}")

    # Check 1: Is MidBoss.exe already present inside gamedata or any subfolder?
    found_exe = find_case_insensitive(gamedata_dir, "MidBoss.exe")
    if found_exe:
        print(f"Found existing MidBoss executable: {found_exe}")
        parent_dir = os.path.dirname(found_exe)
        if os.path.abspath(parent_dir) != os.path.abspath(gamedata_dir):
            print(f"Flattening directory structure from {parent_dir} -> {gamedata_dir}")
            move_tree(parent_dir, gamedata_dir)
            try:
                shutil.rmtree(parent_dir)
            except Exception:
                pass

        # Ensure correct case
        target_exe = os.path.join(gamedata_dir, "MidBoss.exe")
        actual_exe = find_case_insensitive(gamedata_dir, "MidBoss.exe")
        if actual_exe and actual_exe != target_exe:
            os.rename(actual_exe, target_exe)

        cleanup_incompatibilities(gamedata_dir)
        print("MidBoss files verified in gamedata!")
        return 0

    # Check 2: Search for installer or archive files
    candidate_archives = []
    search_paths = [gamedata_dir, gamedir]
    for sp in search_paths:
        if os.path.exists(sp):
            for f in os.listdir(sp):
                fp = os.path.join(sp, f)
                fl = f.lower()
                if os.path.isfile(fp):
                    if "midboss" in fl or fl.endswith(".bin") or fl.endswith(".zip") or fl.endswith(".tar.gz") or fl.endswith(".tgz") or fl.endswith(".tar.bz2"):
                        candidate_archives.append(fp)

    with tempfile.TemporaryDirectory(prefix="midboss_patch_") as tmpdir:
        extracted_any = False

        for arch in candidate_archives:
            print(f"Analyzing candidate archive: {arch}")
            # Try tar.gz / tar.bz2 / tar
            if tarfile.is_tarfile(arch):
                print(f"Extracting tar archive: {arch}")
                try:
                    with tarfile.open(arch, "r:*") as tf:
                        tf.extractall(tmpdir)
                    extracted_any = True
                except Exception as e:
                    print(f"Warning: tar extraction failed: {e}")

            # Try zipfile
            elif zipfile.is_zipfile(arch):
                print(f"Extracting zip archive: {arch}")
                try:
                    with zipfile.ZipFile(arch, "r") as zf:
                        zf.extractall(tmpdir)
                    extracted_any = True
                except Exception as e:
                    print(f"Warning: zip extraction failed: {e}")

            # Try MojoSetup / self-extracting zip (.bin)
            else:
                try:
                    with open(arch, "rb") as f:
                        data = f.read()
                    pos = data.find(b"PK\x03\x04")
                    if pos != -1:
                        print(f"Found embedded zip at offset {pos} in {arch}")
                        import io
                        with zipfile.ZipFile(io.BytesIO(data[pos:])) as zf:
                            zf.extractall(tmpdir)
                        extracted_any = True
                except Exception as e:
                    print(f"Warning: embedded zip extraction failed: {e}")

        # Search extracted tmpdir for MidBoss.exe
        extracted_exe = find_case_insensitive(tmpdir, "MidBoss.exe")
        if extracted_exe:
            source_dir = os.path.dirname(extracted_exe)
            print(f"Found MidBoss.exe in extracted directory: {source_dir}")
            move_tree(source_dir, gamedata_dir)

            # Ensure correct case
            target_exe = os.path.join(gamedata_dir, "MidBoss.exe")
            actual_exe = find_case_insensitive(gamedata_dir, "MidBoss.exe")
            if actual_exe and actual_exe != target_exe:
                os.rename(actual_exe, target_exe)

            cleanup_incompatibilities(gamedata_dir)
            print("Successfully extracted and configured MidBoss gamedata!")
            return 0

    print("ERROR: MidBoss.exe was not found in provided files!")
    return 1

if __name__ == "__main__":
    sys.exit(main())

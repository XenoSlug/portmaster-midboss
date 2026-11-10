#!/usr/bin/env python3
"""
extract_midboss.py - Prepares MidBoss gamedata from the Linux or Windows purchase
Usage: python3 extract_midboss.py [path to MidBoss-Linux-142-bin or MidBoss zip]
"""
import sys, os, zipfile, shutil

def main():
    if len(sys.argv) < 2:
        src = "MidBoss-Linux-142-bin"
        if not os.path.exists(src):
            for candidate in ["MidBoss-Linux-142-bin", "../MidBoss-Linux-142-bin", "gamedata/MidBoss-Linux-142-bin"]:
                if os.path.exists(candidate):
                    src = candidate
                    break
    else:
        src = sys.argv[1]

    if not os.path.exists(src):
        print(f"Error: file '{src}' not found!")
        sys.exit(1)

    print(f"Extracting MidBoss assets from: {src}")
    gamedata_dir = "gamedata"
    os.makedirs(gamedata_dir, exist_ok=True)

    with open(src, "rb") as f:
        data = f.read()

    pos = data.find(b"PK\x03\x04")
    if pos == -1:
        print("Error: Could not find embedded zip data!")
        sys.exit(1)

    import io
    with zipfile.ZipFile(io.BytesIO(data[pos:])) as zf:
        # Extract files from data/ prefix into gamedata
        for member in zf.infolist():
            if member.filename.startswith("data/"):
                rel_path = member.filename[5:]
                if not rel_path:
                    continue
                # Skip x86 Linux binaries
                if rel_path in ["MidBoss.bin.x86", "MidBoss.bin.x86_64", "MidBoss"] or rel_path.startswith("lib64/"):
                    continue
                target_path = os.path.join(gamedata_dir, rel_path)
                if member.is_dir():
                    os.makedirs(target_path, exist_ok=True)
                else:
                    os.makedirs(os.path.dirname(target_path), exist_ok=True)
                    with zf.open(member) as source, open(target_path, "wb") as target:
                        shutil.copyfileobj(source, target)

    print(f"Extraction complete! Files are ready in '{gamedata_dir}/'.")

if __name__ == "__main__":
    main()

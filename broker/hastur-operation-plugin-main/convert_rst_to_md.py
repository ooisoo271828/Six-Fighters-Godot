import os
import subprocess
import sys

PANDOC = r"C:\Users\imbos\AppData\Local\Pandoc\pandoc.exe"
SRC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "godot-docs", "_sources")
DST_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "godot-md-docs")

converted = 0
failed = 0
errors = []

for root, dirs, files in os.walk(SRC_DIR):
    for f in files:
        if not f.endswith(".rst.txt"):
            continue

        src_path = os.path.join(root, f)
        rel_path = os.path.relpath(src_path, SRC_DIR)
        md_rel_path = rel_path.replace(".rst.txt", ".md")
        dst_path = os.path.join(DST_DIR, md_rel_path)

        os.makedirs(os.path.dirname(dst_path), exist_ok=True)

        result = subprocess.run(
            [PANDOC, src_path, "-t", "markdown", "--wrap=none", "-o", dst_path],
            capture_output=True, text=True, encoding="utf-8"
        )

        if result.returncode == 0:
            converted += 1
            if converted % 100 == 0:
                print(f"  Converted {converted} files...")
        else:
            failed += 1
            errors.append((rel_path, result.stderr[:200]))

print(f"\nDone! Converted: {converted}, Failed: {failed}")
if errors:
    print(f"\nFailed files:")
    for path, err in errors[:20]:
        print(f"  {path}: {err}")

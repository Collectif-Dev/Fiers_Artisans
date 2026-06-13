#!/usr/bin/env python3
"""
Global fusion generator.

Usage:
  ./infrastructure/scripts/generate_global_fusion.py
  python3 infrastructure/scripts/generate_global_fusion.py

Run from any directory. The script finds the repo root by walking up from this
script until it sees a "globaliste" folder.

Output:
  <repo>/globaliste/global_fusion.txt
"""

import datetime
import os
import subprocess
from pathlib import Path

EXCLUDE_DIRS = {
    ".git",
    ".dart_tool",
    ".gradle",
    ".idea",
    ".vscode",
    ".next",
    ".turbo",
    ".cache",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
    "build",
    "dist",
    "out",
    "coverage",
    "venv",
    ".venv",
    "target",
    "Pods",
}

SKIP_EXTS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".webp",
    ".ico",
    ".pdf",
    ".zip",
    ".tar",
    ".gz",
    ".7z",
    ".rar",
    ".mp3",
    ".mp4",
    ".mov",
    ".avi",
    ".mkv",
    ".wav",
    ".ttf",
    ".otf",
    ".woff",
    ".woff2",
    ".pem",
    ".key",
    ".crt",
    ".cer",
    ".p12",
    ".pfx",
    ".jks",
    ".keystore",
    ".der",
    ".db",
    ".sqlite",
    ".sqlite3",
}

SKIP_FILES = {".DS_Store"}


def find_repo_root(start: Path) -> Path:
    for parent in [start] + list(start.parents):
        if (parent / "globaliste").is_dir():
            return parent
    return start


def should_skip_file(path: Path, output_path: Path) -> bool:
    name = path.name
    if path == output_path:
        return True
    if name in SKIP_FILES:
        return True
    if name.startswith(".env") and name != ".env.example":
        return True
    if name == "generate_global_fusion.py":
        return True
    if path.suffix.lower() in SKIP_EXTS:
        return True
    return False


def iter_repo_files(repo_root: Path) -> list[Path]:
    """Return tracked files plus new non-ignored files, never ignored artifacts."""
    command = [
        "git",
        "-C",
        str(repo_root),
        "ls-files",
        "--cached",
        "--others",
        "--exclude-standard",
    ]
    result = subprocess.run(
        command,
        check=True,
        capture_output=True,
        text=True,
    )
    files: list[Path] = []
    for line in result.stdout.splitlines():
        rel_path = line.strip()
        if rel_path:
            files.append(repo_root / rel_path)
    return sorted(files, key=lambda path: path.relative_to(repo_root).as_posix())


def main() -> None:
    script_path = Path(__file__).resolve()
    repo_root = find_repo_root(script_path.parent)
    output_path = (repo_root / "globaliste" / "global_fusion.txt").resolve()

    merged_count = 0
    content = []
    content.append("# GLOBAL FUSION - FIERS ARTISANS")
    content.append(
        f"# Generated at: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    content.append("# Files merged: {count}")
    content.append("")

    for file_path in iter_repo_files(repo_root):
        resolved_path = file_path.resolve()
        if should_skip_file(resolved_path, output_path):
            continue
        if any(part in EXCLUDE_DIRS for part in file_path.relative_to(repo_root).parts):
            continue
        try:
            file_text = file_path.read_text(encoding="utf-8")
        except Exception:
            continue
        file_text = "\n".join(line.rstrip() for line in file_text.splitlines())
        rel_path = file_path.relative_to(repo_root).as_posix()
        merged_count += 1
        content.append("=" * 80)
        content.append(f"PATH: {rel_path}")
        content.append("-" * 80)
        content.append(file_text)
        content.append("")

    content[2] = f"# Files merged: {merged_count}"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(content), encoding="utf-8")
    print(f"Fusion complete. Merged {merged_count} files.")


if __name__ == "__main__":
    main()

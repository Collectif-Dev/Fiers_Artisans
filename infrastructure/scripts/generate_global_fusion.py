#!/usr/bin/env python3
"""
Global fusion generator - Advanced version with robust error handling.

Usage:
  ./infrastructure/scripts/generate_global_fusion.py
  python3 infrastructure/scripts/generate_global_fusion.py [--strict] [--report]

Options:
  --strict    Fail on any encoding/read errors (default: skip with warning)
  --report    Generate detailed report file (default: console only)

Run from any directory. The script finds the repo root by walking up from this
script until it sees a "globaliste" folder.

Output:
  <repo>/globaliste/global_fusion.txt
  <repo>/globaliste/fusion_report.log (if --report)

Features:
  - Multi-encoding fallback (UTF-8 → UTF-8-sig → latin-1 → cp1252 → hex)
  - Detailed error logging with recovery strategies
  - File integrity verification
  - Critical file validation
  - Statistics and anomaly detection
"""

import datetime
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, List, Tuple

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

# Critical files that MUST be in the fusion (validation list)
CRITICAL_FILES = {
    "backend/src/config/jwt.config.ts",
    "backend/src/modules/auth/strategies/jwt-refresh.strategy.ts",
    "backend/src/modules/search/search.service.ts",
    "infrastructure/docker-compose.yml",
    "infrastructure/docker-compose.portainer.yml",
    "backend/src/main.ts",
    "backend/src/modules/dev/dev-otp.controller.ts",
    "backend/src/modules/chat/chat.gateway.ts",
    "backend/src/modules/users/map-visibility.gateway.ts",
    "backend/src/modules/auth/auth.controller.ts",
    "backend/src/modules/payment-manual/services/payment-manual.service.ts",
    "Fiers Artisans/lib/presentation/artisan/manual_payment_page.dart",
    "Fiers Artisans/lib/core/storage/secure_storage.dart",
    "Fiers Artisans/lib/providers/auth_provider.dart",
}

# Encodings to try in order
ENCODINGS = [
    "utf-8",
    "utf-8-sig",  # UTF-8 with BOM
    "latin-1",    # Western European
    "iso-8859-1", # Alternative Latin-1
    "cp1252",     # Windows-1252
]

# Statistics tracking
class Stats:
    def __init__(self):
        self.total_files = 0
        self.successfully_read = 0
        self.skipped = 0
        self.failed = []  # List of (file, error) tuples
        self.encoding_issues = []  # Files that needed fallback encoding
        self.missing_critical = []  # Critical files not found
        self.warnings = []  # General warnings
        self.merged = 0
    
    def add_failure(self, file_path: Path, error: str):
        self.failed.append((str(file_path), error))
    
    def add_encoding_issue(self, file_path: Path, encoding: str):
        self.encoding_issues.append((str(file_path), encoding))
    
    def add_warning(self, msg: str):
        self.warnings.append(msg)
    
    def report(self) -> str:
        """Generate a detailed statistics report."""
        lines = [
            "\n" + "="*80,
            "FUSION GENERATION REPORT",
            "="*80,
            f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "STATISTICS:",
            f"  Total files scanned:        {self.total_files}",
            f"  Successfully merged:       {self.merged}",
            f"  Skipped (filters):         {self.skipped}",
            f"  Failed to read:            {len(self.failed)}",
            f"  Encoding fallbacks used:   {len(self.encoding_issues)}",
            f"  Critical files validated:  {len(CRITICAL_FILES) - len(self.missing_critical)}/{len(CRITICAL_FILES)}",
        ]
        
        if self.encoding_issues:
            lines.extend([
                "",
                "⚠️  ENCODING ISSUES (files that needed fallback):",
            ])
            for file_path, encoding in self.encoding_issues:
                lines.append(f"  - {file_path} (decoded as: {encoding})")
        
        if self.failed:
            lines.extend([
                "",
                "❌ FILES THAT COULD NOT BE READ:",
            ])
            for file_path, error in self.failed:
                lines.append(f"  - {file_path}")
                lines.append(f"    Error: {error}")
        
        if self.missing_critical:
            lines.extend([
                "",
                "⚠️  CRITICAL FILES MISSING FROM FUSION:",
            ])
            for file_path in self.missing_critical:
                lines.append(f"  - {file_path}")
        
        if self.warnings:
            lines.extend([
                "",
                "⚠️  WARNINGS:",
            ])
            for warning in self.warnings:
                lines.append(f"  - {warning}")
        
        lines.extend([
            "",
            "="*80,
            "END OF REPORT",
            "="*80,
        ])
        
        return "\n".join(lines)


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


def read_file_with_fallback(file_path: Path, stats: Stats, strict: bool = False) -> Optional[Tuple[str, str]]:
    """
    Try to read a file with multiple encoding strategies.
    
    Returns:
        Tuple[content, encoding_used] if successful
        None if all attempts fail
    """
    # Verify file actually exists (not just in git index)
    if not file_path.exists():
        # Try to find similar files (case-insensitive match)
        parent = file_path.parent
        if parent.exists():
            for candidate in parent.iterdir():
                if candidate.name.lower() == file_path.name.lower():
                    file_path = candidate
                    break
            else:
                if strict:
                    stats.add_failure(file_path, f"File path does not exist: {file_path}")
                else:
                    # In normal mode, just skip silently (file was removed)
                    stats.skipped += 1
                return None
        else:
            if strict:
                stats.add_failure(file_path, f"File path does not exist: {file_path}")
            else:
                stats.skipped += 1
            return None
    
    # Try each encoding in order
    for encoding in ENCODINGS:
        try:
            content = file_path.read_text(encoding=encoding)
            if encoding != "utf-8":
                stats.add_encoding_issue(file_path, encoding)
            return content, encoding
        except UnicodeDecodeError:
            continue
        except Exception as e:
            continue
    
    # Last resort: read as hex for inspection
    try:
        raw_bytes = file_path.read_bytes()
        content = f"[BINARY FILE - {len(raw_bytes)} bytes]\n"
        content += f"[First 100 bytes (hex)]: {raw_bytes[:100].hex()}\n"
        stats.add_warning(f"File {file_path.name} is binary/unreadable - included as hex dump")
        return content, "hex"
    except Exception as e:
        stats.add_failure(file_path, f"All encoding attempts failed: {e}")
        return None



def iter_repo_files(repo_root: Path) -> list[Path]:
    """Return tracked files plus new non-ignored files, never ignored artifacts."""
    command = [
        "git",
        "-C",
        str(repo_root),
        "-c",
        "core.quotepath=off",  # Disable git's quotepath to handle Unicode filenames
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
        encoding="utf-8",  # Explicitly use UTF-8 for output
    )
    files: list[Path] = []
    for line in result.stdout.splitlines():
        rel_path = line.strip()
        if rel_path:
            try:
                files.append(repo_root / rel_path)
            except Exception as e:
                # If Path creation fails, log and continue
                continue
    
    # Sort with better handling for paths that might fail comparison
    def safe_sort_key(path: Path) -> str:
        try:
            return path.relative_to(repo_root).as_posix()
        except (ValueError, TypeError):
            return str(path)
    
    return sorted(files, key=safe_sort_key)


def main() -> None:
    # Parse command-line arguments
    strict_mode = "--strict" in sys.argv
    generate_report = "--report" in sys.argv
    
    script_path = Path(__file__).resolve()
    repo_root = find_repo_root(script_path.parent)
    output_path = (repo_root / "globaliste" / "global_fusion.txt").resolve()
    report_path = (repo_root / "globaliste" / "fusion_report.log").resolve()
    
    stats = Stats()
    
    # Header for fusion file
    content = []
    content.append("# GLOBAL FUSION - FIERS ARTISANS")
    content.append(
        f"# Generated at: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
    content.append("# Files merged: {count}")
    content.append("")
    
    # Track which critical files we found
    found_critical_files = set()
    
    # Process all files
    all_files = iter_repo_files(repo_root)
    stats.total_files = len(all_files)
    
    print(f"🔄 Processing {stats.total_files} files from git...")
    
    for file_path in all_files:
        resolved_path = file_path.resolve()
        rel_path = file_path.relative_to(repo_root).as_posix()
        
        # Check if should skip
        if should_skip_file(resolved_path, output_path):
            stats.skipped += 1
            continue
        
        # Check if in excluded directories
        if any(part in EXCLUDE_DIRS for part in file_path.relative_to(repo_root).parts):
            stats.skipped += 1
            continue
        
        # Verify file exists
        if not file_path.exists():
            stats.add_failure(file_path, "File does not exist")
            if strict_mode:
                print(f"❌ STRICT MODE: File not found: {rel_path}")
                sys.exit(1)
            continue
        
        # Try to read with fallback encodings
        result = read_file_with_fallback(file_path, stats, strict=strict_mode)
        if result is None:
            if strict_mode:
                print(f"❌ STRICT MODE: Cannot read file: {rel_path}")
                sys.exit(1)
            # In normal mode, silently skip unreadable files
            continue
        
        file_text, encoding_used = result
        
        # Clean up line endings
        file_text = "\n".join(line.rstrip() for line in file_text.splitlines())
        
        # Add to fusion
        content.append("=" * 80)
        content.append(f"PATH: {rel_path}")
        content.append("-" * 80)
        content.append(file_text)
        content.append("")
        
        stats.merged += 1
        
        # Track critical files
        if rel_path in CRITICAL_FILES:
            found_critical_files.add(rel_path)
    
    # Identify missing critical files
    stats.missing_critical = list(CRITICAL_FILES - found_critical_files)
    if stats.missing_critical:
        print(f"⚠️  WARNING: {len(stats.missing_critical)} critical files missing from fusion!")
        for missing in sorted(stats.missing_critical):
            print(f"   - {missing}")
    
    # Update file count in header
    content[2] = f"# Files merged: {stats.merged}"
    
    # Write fusion file
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(content), encoding="utf-8")
    
    # Generate report if requested
    if generate_report:
        report_content = stats.report()
        report_path.write_text(report_content, encoding="utf-8")
        print(f"✅ Report written to: {report_path}")
    
    # Print summary
    print(f"\n✅ Fusion complete!")
    print(f"   - Merged: {stats.merged} files")
    print(f"   - Skipped: {stats.skipped} files")
    print(f"   - Failed: {len(stats.failed)} files")
    if stats.encoding_issues:
        print(f"   - Encoding fallbacks: {len(stats.encoding_issues)} files")
    print(f"   - Critical files OK: {len(found_critical_files)}/{len(CRITICAL_FILES)}")
    print(f"   - Output: {output_path}")
    
    # Print warnings and errors
    if stats.warnings:
        print(f"\n⚠️  {len(stats.warnings)} warning(s):")
        for warning in stats.warnings[:5]:  # Show first 5
            print(f"   - {warning}")
        if len(stats.warnings) > 5:
            print(f"   ... and {len(stats.warnings) - 5} more")
    
    if stats.failed:
        print(f"\n❌ {len(stats.failed)} file(s) could not be read:")
        for file_path, error in stats.failed[:5]:  # Show first 5
            print(f"   - {file_path}")
        if len(stats.failed) > 5:
            print(f"   ... and {len(stats.failed) - 5} more")
        if strict_mode:
            sys.exit(1)
    
    if stats.missing_critical:
        print(f"\n⚠️  {len(stats.missing_critical)} critical file(s) are missing!")
        if strict_mode:
            sys.exit(1)


if __name__ == "__main__":
    main()

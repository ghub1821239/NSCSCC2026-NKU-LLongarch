#!/usr/bin/env python3
"""Shared helpers: convert Verilog comment encoding without changing code logic.

Only non-ASCII text (almost always inside // or /* */ comments) changes byte
representation. ASCII code, identifiers, numbers and operators stay identical.
Line endings (LF / CRLF) and the final newline are preserved.
"""

from __future__ import annotations

import glob
import os
import sys
from pathlib import Path

SRC_ENCODINGS = {
    "gb2312": ("gb2312", "gbk"),
    "gbk": ("gbk", "gb2312"),
    "utf-8": ("utf-8",),
    "utf8": ("utf-8",),
}

DST_ENCODINGS = {
    "gb2312": ("gb2312", "gbk"),  # fall back to gbk for rare punctuation
    "gbk": ("gbk",),
    "utf-8": ("utf-8",),
    "utf8": ("utf-8",),
}

DEFAULT_PATTERNS = ["IP/myCPU/*.v", "IP/myCPU/*.vh"]


def detect_newline(data: bytes) -> bytes:
    if b"\r\n" in data:
        return b"\r\n"
    return b"\n"


def decode_bytes(data: bytes, src_name: str) -> tuple[str, str]:
    """Decode raw bytes. Returns (text, encoding_used)."""
    candidates = SRC_ENCODINGS[src_name]
    errors = []
    for enc in candidates:
        try:
            return data.decode(enc), enc
        except UnicodeDecodeError as exc:
            errors.append(f"{enc}: {exc}")
    raise UnicodeDecodeError(
        src_name,
        data,
        0,
        1,
        " / ".join(errors),
    )


def encode_text(text: str, dst_name: str) -> tuple[bytes, str, list[str]]:
    """Encode text. Returns (bytes, encoding_used, warnings)."""
    candidates = DST_ENCODINGS[dst_name]
    warnings: list[str] = []
    last_err: Exception | None = None
    for enc in candidates:
        try:
            return text.encode(enc), enc, warnings
        except UnicodeEncodeError as exc:
            last_err = exc
            if enc != candidates[-1]:
                warnings.append(
                    f"cannot encode with {enc} ({exc.reason}); trying fallback"
                )
    assert last_err is not None
    # Last resort: replace unencodable chars so the script does not abort.
    enc = candidates[-1]
    warnings.append(
        f"replaced unencodable characters while writing {enc}: {last_err}"
    )
    return text.encode(enc, errors="replace"), enc, warnings


def strip_line_comment_for_check(line: str) -> str:
    """Remove // comment for code-identity check (strings ignored for simplicity)."""
    in_str = False
    i = 0
    while i < len(line) - 1:
        ch = line[i]
        if ch == '"':
            in_str = not in_str
        elif not in_str and line[i : i + 2] == "//":
            return line[:i]
        i += 1
    return line


def code_fingerprint(text: str) -> list[str]:
    """Normalized non-comment code lines, used to assert logic is unchanged."""
    out: list[str] = []
    in_block = False
    for raw in text.splitlines():
        line = raw
        if in_block:
            end = line.find("*/")
            if end < 0:
                continue
            line = line[end + 2 :]
            in_block = False
        while True:
            start = line.find("/*")
            if start < 0:
                break
            end = line.find("*/", start + 2)
            if end < 0:
                line = line[:start]
                in_block = True
                break
            line = line[:start] + line[end + 2 :]
        code = strip_line_comment_for_check(line).rstrip()
        # collapse whitespace so pure spacing diffs do not false-fail
        collapsed = " ".join(code.split())
        if collapsed:
            out.append(collapsed)
    return out


def convert_file(
    path: Path,
    src_name: str,
    dst_name: str,
    dry_run: bool = False,
) -> dict:
    raw = path.read_bytes()
    newline = detect_newline(raw)
    had_final_nl = raw.endswith(b"\n")

    text, src_used = decode_bytes(raw, src_name)
    before_fp = code_fingerprint(text)

    # Rebuild with original newline style
    body = text.splitlines()
    rebuilt = newline.decode("ascii").join(body)
    if had_final_nl:
        rebuilt += newline.decode("ascii")

    out, dst_used, warnings = encode_text(rebuilt, dst_name)
    after_fp = code_fingerprint(out.decode(dst_used, errors="replace"))

    if before_fp != after_fp:
        raise RuntimeError(
            f"{path}: code fingerprint changed; refused to write "
            f"(src={src_used}, dst={dst_used})"
        )

    already = raw == out
    changed = not already
    if changed and not dry_run:
        path.write_bytes(out)

    return {
        "path": str(path),
        "src_used": src_used,
        "dst_used": dst_used,
        "changed": changed,
        "bytes_in": len(raw),
        "bytes_out": len(out),
        "warnings": warnings,
        "dry_run": dry_run,
    }


def expand_targets(patterns: list[str]) -> list[Path]:
    files: list[Path] = []
    seen = set()
    for pat in patterns:
        p = Path(pat)
        if p.is_file():
            matches = [p]
        else:
            matches = [Path(x) for x in sorted(glob.glob(pat, recursive=True))]
        for m in matches:
            key = str(m.resolve())
            if key in seen:
                continue
            seen.add(key)
            files.append(m)
    return files


def run_cli(src_name: str, dst_name: str, argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    dry_run = False
    patterns: list[str] = []

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            prog = Path(sys.argv[0]).name
            print(
                f"Usage: python3 mytool/{prog} [--dry-run] [FILE|GLOB ...]\n"
                f"Convert Verilog files from {src_name} to {dst_name}.\n"
                f"Only comment (non-ASCII) bytes change; code logic is verified unchanged.\n"
                f"Default targets: {' '.join(DEFAULT_PATTERNS)}"
            )
            return 0
        if arg == "--dry-run":
            dry_run = True
            i += 1
            continue
        patterns.append(arg)
        i += 1

    if not patterns:
        # Resolve relative to repo root (parent of mytool/)
        repo = Path(__file__).resolve().parent.parent
        patterns = [str(repo / p) for p in DEFAULT_PATTERNS]

    files = expand_targets(patterns)
    if not files:
        print("no files matched", file=sys.stderr)
        return 1

    n_changed = 0
    n_ok = 0
    n_fail = 0
    for path in files:
        try:
            info = convert_file(path, src_name, dst_name, dry_run=dry_run)
        except Exception as exc:  # noqa: BLE001 - report per-file and continue
            n_fail += 1
            print(f"[FAIL] {path}: {exc}", file=sys.stderr)
            continue
        n_ok += 1
        if info["changed"]:
            n_changed += 1
            tag = "DRY" if dry_run else "OK"
            print(
                f"[{tag}] {info['path']}: {info['src_used']} -> {info['dst_used']} "
                f"({info['bytes_in']} -> {info['bytes_out']} bytes)"
            )
        else:
            print(f"[SKIP] {info['path']}: already {info['dst_used']}")
        for w in info["warnings"]:
            print(f"  warn: {w}", file=sys.stderr)

    print(
        f"done: {n_ok} ok, {n_changed} changed, {n_fail} failed"
        + (" (dry-run)" if dry_run else "")
    )
    return 1 if n_fail else 0


if __name__ == "__main__":
    print(
        "Use comments_gb2312_to_utf8.py or comments_utf8_to_gb2312.py",
        file=sys.stderr,
    )
    sys.exit(2)

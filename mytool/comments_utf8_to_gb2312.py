#!/usr/bin/env python3
"""Convert Verilog file encoding UTF-8 -> GB2312 (GBK fallback) for comments.

Code logic is left unchanged: ASCII RTL is byte-identical in meaning, and a
code-fingerprint check refuses to write if non-comment code would change.

If a character is outside GB2312, the writer falls back to GBK; if still
impossible, it replaces that character and prints a warning.

Usage:
    # 默认处理 IP/myCPU/*.v *.vh
    python3 mytool/comments_utf8_to_gb2312.py

    # 只预览
    python3 mytool/comments_utf8_to_gb2312.py --dry-run

    # 指定文件
    python3 mytool/comments_utf8_to_gb2312.py IP/myCPU/icache.v IP/myCPU/cache.v
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comment_codec import run_cli  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(run_cli("utf-8", "gb2312"))

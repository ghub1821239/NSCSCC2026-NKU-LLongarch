#!/usr/bin/env python3
"""Convert Verilog file encoding GB2312/GBK -> UTF-8 (comments only in practice).

Code logic is left unchanged: ASCII RTL is byte-identical in meaning, and a
code-fingerprint check refuses to write if non-comment code would change.

Usage:
    # 默认处理 IP/myCPU/*.v *.vh
    python3 mytool/comments_gb2312_to_utf8.py

    # 只预览
    python3 mytool/comments_gb2312_to_utf8.py --dry-run

    # 指定文件
    python3 mytool/comments_gb2312_to_utf8.py IP/myCPU/icache.v IP/myCPU/cache.v
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comment_codec import run_cli  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(run_cli("gb2312", "utf-8"))

#!/usr/bin/env python3
"""Analyze the latest Vivado timing exports into one per-stage summary.

Inputs are auto-detected under --input (default: fpga/.../for_timing_report):
  * NN_<stage>_top60.rpt       per-stage report_timing blocks (old flow)
  * all_paths*.rpt             report_timing -path_type full blocks
  * timing_summary*.rpt        report_timing_summary (WNS/TNS + blocks)
  * design_analysis*.rpt       report_design_analysis table (fanout/global)

Outputs (default: same directory):
  * timing_summary.md          per-stage ranking + worst paths + cross-module
  * timing_paths.csv           every unique parsed path
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


DEFAULT_REPORT_DIR = (
    Path(__file__).resolve().parent.parent
    / "fpga"
    / "nscscc-team"
    / "run_vivado"
    / "result"
    / "for_timing_report"
)
NUMBER = r"[-+]?\d+(?:\.\d+)?"

# Longer tokens first so u_pre_IF1 wins over a generic u_* match.
STAGE_TOKENS = (
    ("preIF1", "u_pre_IF1"),
    ("preIF2", "u_pre_IF2"),
    ("IF", "u_fetch"),
    ("ID", "u_decode"),
    ("EXE1", "u_exe1"),
    ("EXE2", "u_exe2"),
    ("MEM", "u_mem"),
    ("WB", "u_wb"),
    ("icache", "u_Icache"),
    ("icache", "u_icache"),
    ("dcache", "u_Dcache"),
    ("dcache", "u_cache"),
    ("tlb", "u_tlb"),
    ("btb", "u_btb"),
    ("ras", "u_ras"),
    ("bht", "u_bht"),
    ("csr", "u_csr_regfile"),
    ("divider", "u_divider"),
    ("core", "u_mycpu_core"),
)
TOP60_NAME_RE = re.compile(r"^\d+_([^_]+)_top60\.rpt$", re.IGNORECASE)


@dataclass
class TimingPath:
    source: str
    destination: str
    source_stage: str
    dest_stage: str
    slack: float
    requirement: float
    data_delay: float
    logic_delay: float
    route_delay: float
    route_percent: float
    levels: int
    breakdown: str
    fanout: int
    worst_net: str
    report: str

    @property
    def key(self) -> tuple[object, ...]:
        return (
            self.source,
            self.destination,
            round(self.slack, 3),
            round(self.requirement, 3),
            round(self.data_delay, 3),
            self.levels,
        )

    @property
    def frequency(self) -> float:
        return 1000.0 / self.requirement if self.requirement > 0 else 0.0


def detect_stage(name: str) -> str:
    for label, token in STAGE_TOKENS:
        if token in name:
            return label
    return "?"


def shorten_hierarchy(name: str) -> str:
    for prefix in ("u_cpu/u_mycpu_core/", "u_cpu/"):
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def extract(pattern: str, block: str, default: str = "") -> str:
    match = re.search(pattern, block, re.MULTILINE)
    return match.group(1).strip() if match else default


def parse_report_timing_blocks(text: str, report: str,
                               filename_stage: str = "") -> list[TimingPath]:
    """Parse `report_timing` blocks starting with `Slack (MET/VIOLATED)`."""
    starts = list(re.finditer(
        r"^Slack \(([^)]+)\)\s*:\s*(%s)ns" % NUMBER, text, re.MULTILINE))
    paths: list[TimingPath] = []
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[start.start():end]
        data_match = re.search(
            rf"Data Path Delay:\s*({NUMBER})ns\s*"
            rf"\(logic\s+({NUMBER})ns\s*\(({NUMBER})%\)\s*"
            rf"route\s+({NUMBER})ns\s*\(({NUMBER})%\)\)",
            block,
        )
        levels_match = re.search(
            r"Logic Levels:\s*(\d+)\s*(?:\(([^)]*)\))?", block)
        source = extract(r"^\s*Source:\s+(\S+)", block)
        destination = extract(r"^\s*Destination:\s+(\S+)", block)
        requirement = extract(rf"^\s*Requirement:\s*({NUMBER})ns", block)
        path_type = extract(r"^\s*Path Type:\s*(\S+)", block)
        if not (data_match and levels_match and source and destination and requirement):
            continue
        if path_type and "setup" not in path_type.lower():
            continue  # 只统计 setup 路径，忽略 hold / pulse width 段

        fanout = 0
        worst_net = ""
        for fo_match in re.finditer(
                r"net \(fo=(\d+), routed\)\s+(?:%s)\s+(?:%s)\s+(\S+)"
                % (NUMBER, NUMBER), block):
            fo = int(fo_match.group(1))
            if fo > fanout:
                fanout = fo
                worst_net = fo_match.group(2)

        src_stage = filename_stage or detect_stage(source)
        paths.append(TimingPath(
            source=source,
            destination=destination,
            source_stage=src_stage,
            dest_stage=detect_stage(destination),
            slack=float(start.group(2)),
            requirement=float(requirement),
            data_delay=float(data_match.group(1)),
            logic_delay=float(data_match.group(2)),
            route_delay=float(data_match.group(4)),
            route_percent=float(data_match.group(5)),
            levels=int(levels_match.group(1)),
            breakdown=(levels_match.group(2) or "").strip(),
            fanout=fanout,
            worst_net=worst_net,
            report=report,
        ))
    return paths


def parse_design_analysis(text: str, report: str) -> list[TimingPath]:
    """Parse the compact `report_design_analysis` table."""
    lines = text.splitlines()
    header_idx = -1
    for i, line in enumerate(lines):
        if line.startswith("|") and "Start Point Pin" in line and "Paths" in line:
            header_idx = i
            break
    if header_idx < 0:
        return []

    header = [cell.strip() for cell in lines[header_idx].split("|")]
    col = {name: idx for idx, name in enumerate(header) if name}
    paths: list[TimingPath] = []
    for line in lines[header_idx + 1:]:
        if not line.startswith("| Path #"):
            continue
        cells = [cell.strip() for cell in line.split("|")]

        def cell(name: str) -> str:
            idx = col.get(name)
            return cells[idx] if idx is not None and idx < len(cells) else ""

        def split_pct(value: str) -> tuple[float, float]:
            match = re.match(rf"({NUMBER})\(({NUMBER})%\)", value)
            if match:
                return float(match.group(1)), float(match.group(2))
            return 0.0, 0.0

        logic, logic_pct = split_pct(cell("Logic Delay"))
        net, net_pct = split_pct(cell("Net Delay"))
        slack = float(cell("Slack") or 0)
        requirement = float(cell("Requirement") or 0)
        levels = int(cell("Logic Levels") or 0)
        fanout = int(cell("High Fanout") or 0)
        source = cell("Start Point Pin") or "?"
        destination = cell("End Point Pin") or "?"
        src_stage = detect_stage(source)
        if src_stage == "?":
            src_stage = detect_stage(cell("Logical Path"))
        paths.append(TimingPath(
            source=source,
            destination=destination,
            source_stage=src_stage,
            dest_stage=detect_stage(destination),
            slack=slack,
            requirement=requirement,
            data_delay=logic + net,
            logic_delay=logic,
            route_delay=net,
            route_percent=net_pct or (100.0 - logic_pct),
            levels=levels,
            breakdown="",
            fanout=fanout,
            worst_net="",
            report=report,
        ))
    return paths


def parse_summary_header(text: str) -> dict[str, float | int]:
    info: dict[str, float | int] = {}
    match = re.search(
        r"Setup\s*:\s*(\d+)\s*Failing Endpoints,\s*Worst Slack\s+"
        rf"({NUMBER})ns,\s*Total Violation\s+({NUMBER})ns", text)
    if match:
        info["wns"] = float(match.group(2))
        info["tns"] = float(match.group(3))
        info["failing_endpoints"] = int(match.group(1))
    match = re.search(
        r"Hold\s*:\s*(\d+)\s*Failing Endpoints,\s*Worst Slack\s+"
        rf"({NUMBER})ns,\s*Total Violation\s+({NUMBER})ns", text)
    if match:
        info["whs"] = float(match.group(2))
        info["ths"] = float(match.group(3))
    return info


def diagnosis(path: TimingPath) -> str:
    notes: list[str] = []
    if path.slack < 0:
        notes.append("时序违例")
    elif path.slack < 0.2:
        notes.append("裕量极小")
    elif path.slack < 1.0:
        notes.append("裕量偏小")
    if path.route_percent >= 70:
        notes.append("布线主导")
    elif path.logic_delay > 0 and path.logic_delay / path.data_delay >= 0.5:
        notes.append("逻辑主导")
    if path.levels >= 20:
        notes.append("级数较深")
    if path.fanout >= 50:
        notes.append(f"高扇出({path.fanout})")
    if path.source_stage != path.dest_stage:
        notes.append("跨模块")
    return "、".join(notes) if notes else "裕量充足"


def unique_paths(paths: list[TimingPath]) -> list[TimingPath]:
    seen: dict[tuple[object, ...], TimingPath] = {}
    for path in paths:
        seen.setdefault(path.key, path)
    return list(seen.values())


def write_csv(paths: list[TimingPath], output: Path) -> None:
    fields = [
        "source_stage", "dest_stage", "slack_ns", "requirement_ns",
        "frequency_mhz", "data_delay_ns", "logic_delay_ns",
        "route_delay_ns", "route_percent", "levels", "fanout",
        "diagnosis", "source", "destination", "worst_net", "report",
    ]
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for path in paths:
            writer.writerow({
                "source_stage": path.source_stage,
                "dest_stage": path.dest_stage,
                "slack_ns": f"{path.slack:.3f}",
                "requirement_ns": f"{path.requirement:.3f}",
                "frequency_mhz": f"{path.frequency:.1f}",
                "data_delay_ns": f"{path.data_delay:.3f}",
                "logic_delay_ns": f"{path.logic_delay:.3f}",
                "route_delay_ns": f"{path.route_delay:.3f}",
                "route_percent": f"{path.route_percent:.1f}",
                "levels": path.levels,
                "fanout": path.fanout,
                "diagnosis": diagnosis(path),
                "source": path.source,
                "destination": path.destination,
                "worst_net": path.worst_net,
                "report": path.report,
            })


def write_markdown(paths: list[TimingPath], info: dict[str, float | int],
                   output: Path, top: int) -> None:
    lines = [
        "# 最新时序路径汇总",
        "",
        "由 `analyze_timing_full.py` 自动生成。Slack 越小越优先处理。",
        "",
    ]

    requirements = Counter(round(p.requirement, 3) for p in paths
                           if p.requirement > 0)
    if requirements:
        period = requirements.most_common(1)[0][0]
        worst = min((p.slack for p in paths), default=0.0)
        lines += [
            "| 指标 | 值 |",
            "| --- | ---: |",
            f"| 时钟周期（出现最多的 Requirement） | {period:.3f} ns |",
            f"| 当前主频 | {1000.0 / period:.1f} MHz |" if period > 0 else "| 当前主频 | N/A |",
            f"| 解析路径数（去重） | {len(paths)} |",
            f"| 最差 Slack | {worst:.3f} ns |",
            f"| WNS (setup) | {info.get('wns', 'N/A')} ns |",
            f"| TNS (setup) | {info.get('tns', 'N/A')} ns |",
            f"| WHS (hold) | {info.get('whs', 'N/A')} ns |",
            "",
        ]

    lines += ["", "## 全局最差路径", "",
              "| 排名 | 起点级 | Slack (ns) | Delay (ns) | Route% | Levels | 扇出 | Source → Destination |",
              "| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |"]
    for rank, path in enumerate(sorted(paths, key=lambda p: p.slack)[:top], 1):
        src = shorten_hierarchy(path.source)
        dst = shorten_hierarchy(path.destination)
        lines.append(
            f"| {rank} | {path.source_stage} | {path.slack:.3f} | {path.data_delay:.3f} | "
            f"{path.route_percent:.1f}% | {path.levels} | {path.fanout} | "
            f"`{src}` → `{dst}` |")

    nets: dict[str, int] = {}
    for path in paths:
        if path.worst_net:
            nets[path.worst_net] = max(nets.get(path.worst_net, 0), path.fanout)
    if nets:
        lines += ["", "## 高扇出网络", "",
                  "| 扇出 | 网络 |", "| ---: | --- |"]
        for net, fo in sorted(nets.items(), key=lambda kv: -kv[1])[:15]:
            lines.append(f"| {fo} | `{shorten_hierarchy(net)}` |")

    lines += ["", "## 判断标准", "",
              "- Slack < 0：违例，必须处理；",
              "- 布线占比 ≥ 70%：先查长线/扇出/跨模块，再考虑拆级；",
              "- 逻辑占比 ≥ 50% 或 Levels ≥ 20：组合深度问题，考虑拆级/提前译码；",
              "- 扇出 ≥ 50：复制寄存器或把全局控制改局部。"]
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_all(input_dir: Path) -> tuple[list[TimingPath], dict[str, float | int]]:
    all_paths: list[TimingPath] = []
    info: dict[str, float | int] = {}
    for report_file in sorted(input_dir.glob("*.rpt")):
        text = report_file.read_text(encoding="utf-8", errors="replace")
        name = report_file.name.lower()
        if "design_analysis" in name:
            parsed = parse_design_analysis(text, report_file.name)
        else:
            filename_stage = ""
            top60 = TOP60_NAME_RE.match(report_file.name)
            if top60:
                filename_stage = top60.group(1)
            parsed = parse_report_timing_blocks(text, report_file.name,
                                                filename_stage)
            if "timing_summary" in name:
                info.update(parse_summary_header(text))
        if parsed:
            print(f"{report_file.name}: {len(parsed)} 条路径")
        all_paths.extend(parsed)
    return unique_paths(all_paths), info


def main() -> int:
    parser = argparse.ArgumentParser(description="汇总最新 Vivado 时序导出")
    parser.add_argument("--input", type=Path, default=DEFAULT_REPORT_DIR,
                        help="rpt 文件所在目录")
    parser.add_argument("--output", type=Path, default=None,
                        help="输出目录（默认与输入相同）")
    parser.add_argument("--top", type=int, default=40,
                        help="全局最差路径条数（默认 40）")
    parser.add_argument("--cpu-only", action="store_true",
                        help="只保留 CPU 层次（u_cpu / u_mycpu_core）相关路径")
    args = parser.parse_args()

    input_dir = args.input.resolve()
    if not input_dir.is_dir():
        parser.error(f"输入目录不存在：{input_dir}")
    output_dir = (args.output or input_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    paths, info = load_all(input_dir)
    if not paths:
        parser.error(f"{input_dir} 下没有解析出任何路径")
    if args.cpu_only:
        paths = [p for p in paths
                 if "u_cpu" in p.source or "u_cpu" in p.destination
                 or "u_mycpu_core" in p.source or "u_mycpu_core" in p.destination]
        if not paths:
            parser.error("--cpu-only 过滤后没有路径，确认报告里是否含 u_cpu 层次")
    paths.sort(key=lambda p: (p.slack, -p.data_delay))

    csv_output = output_dir / "timing_paths.csv"
    markdown_output = output_dir / "timing_summary.md"
    write_csv(paths, csv_output)
    write_markdown(paths, info, markdown_output, args.top)
    print(f"\n路径总数: {len(paths)}")
    print(f"CSV: {csv_output}")
    print(f"Markdown: {markdown_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Summarize per-stage Vivado timing reports as CSV and Markdown."""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


# Keep the script runnable from any current working directory. The script is
# stored in <repo>/mytool, while Vivado reports are under <repo>/fpga.
DEFAULT_REPORT_DIR = (
    Path(__file__).resolve().parent.parent
    / "fpga"
    / "nscscc-team"
    / "run_vivado"
    / "result"
    / "for_timing_report"
)
REPORT_NAME_RE = re.compile(r"^(\d+)_([^/]+)_top60\.rpt$", re.IGNORECASE)
NUMBER = r"[-+]?\d+(?:\.\d+)?"


@dataclass(frozen=True)
class TimingPath:
    stage_order: int
    stage: str
    status: str
    slack_ns: float
    source: str
    destination: str
    requirement_ns: float
    data_delay_ns: float
    logic_delay_ns: float
    logic_percent: float
    route_delay_ns: float
    route_percent: float
    logic_levels: int
    logic_breakdown: str

    @property
    def key(self) -> tuple[object, ...]:
        return (
            self.stage,
            self.source,
            self.destination,
            self.slack_ns,
            self.requirement_ns,
            self.data_delay_ns,
            self.logic_levels,
        )


def extract(pattern: str, block: str, default: str = "") -> str:
    match = re.search(pattern, block, re.MULTILINE)
    return match.group(1).strip() if match else default


def parse_report(path: Path) -> list[TimingPath]:
    name_match = REPORT_NAME_RE.match(path.name)
    if not name_match:
        return []

    stage_order = int(name_match.group(1))
    stage = name_match.group(2)
    text = path.read_text(encoding="utf-8", errors="replace")
    starts = list(re.finditer(r"^Slack \(([^)]+)\)\s*:\s*(%s)ns" % NUMBER, text, re.MULTILINE))
    parsed: list[TimingPath] = []

    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[start.start():end]
        data_match = re.search(
            rf"Data Path Delay:\s*({NUMBER})ns\s*"
            rf"\(logic\s+({NUMBER})ns\s*\(({NUMBER})%\)\s*"
            rf"route\s+({NUMBER})ns\s*\(({NUMBER})%\)\)",
            block,
        )
        levels_match = re.search(r"Logic Levels:\s*(\d+)\s*(?:\(([^)]*)\))?", block)
        source = extract(r"^\s*Source:\s*(\S+)", block)
        destination = extract(r"^\s*Destination:\s*(\S+)", block)
        requirement = extract(rf"^\s*Requirement:\s*({NUMBER})ns", block)

        if not (data_match and levels_match and source and destination and requirement):
            continue

        parsed.append(
            TimingPath(
                stage_order=stage_order,
                stage=stage,
                status=start.group(1),
                slack_ns=float(start.group(2)),
                source=source,
                destination=destination,
                requirement_ns=float(requirement),
                data_delay_ns=float(data_match.group(1)),
                logic_delay_ns=float(data_match.group(2)),
                logic_percent=float(data_match.group(3)),
                route_delay_ns=float(data_match.group(4)),
                route_percent=float(data_match.group(5)),
                logic_levels=int(levels_match.group(1)),
                logic_breakdown=(levels_match.group(2) or "").strip(),
            )
        )

    unique: dict[tuple[object, ...], TimingPath] = {}
    for timing_path in parsed:
        unique.setdefault(timing_path.key, timing_path)
    return sorted(unique.values(), key=lambda item: (item.slack_ns, -item.data_delay_ns))


def shorten_hierarchy(name: str) -> str:
    prefixes = (
        "u_cpu/u_mycpu_core/",
        "u_cpu/",
    )
    for prefix in prefixes:
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def diagnosis(path: TimingPath) -> str:
    notes: list[str] = []
    if path.slack_ns < 0:
        notes.append("时序违例")
    elif path.slack_ns < 0.2:
        notes.append("裕量极小")
    elif path.slack_ns < 1.0:
        notes.append("裕量偏小")

    if path.route_percent >= 70:
        notes.append("布线主导")
    elif path.logic_percent >= 50:
        notes.append("逻辑主导")

    if path.logic_levels >= 20:
        notes.append("逻辑级数较深")
    return "、".join(notes) if notes else "裕量充足"


def write_csv(paths: list[TimingPath], output: Path) -> None:
    fields = [
        "stage",
        "rank",
        "status",
        "slack_ns",
        "requirement_ns",
        "data_delay_ns",
        "logic_delay_ns",
        "logic_percent",
        "route_delay_ns",
        "route_percent",
        "logic_levels",
        "diagnosis",
        "source",
        "destination",
        "logic_breakdown",
    ]
    ranks: dict[str, int] = {}
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for item in paths:
            ranks[item.stage] = ranks.get(item.stage, 0) + 1
            writer.writerow(
                {
                    "stage": item.stage,
                    "rank": ranks[item.stage],
                    "status": item.status,
                    "slack_ns": f"{item.slack_ns:.3f}",
                    "requirement_ns": f"{item.requirement_ns:.3f}",
                    "data_delay_ns": f"{item.data_delay_ns:.3f}",
                    "logic_delay_ns": f"{item.logic_delay_ns:.3f}",
                    "logic_percent": f"{item.logic_percent:.3f}",
                    "route_delay_ns": f"{item.route_delay_ns:.3f}",
                    "route_percent": f"{item.route_percent:.3f}",
                    "logic_levels": item.logic_levels,
                    "diagnosis": diagnosis(item),
                    "source": item.source,
                    "destination": item.destination,
                    "logic_breakdown": item.logic_breakdown,
                }
            )


def markdown_escape(text: str) -> str:
    return text.replace("|", "\\|")


def write_markdown(paths: list[TimingPath], output: Path) -> None:
    grouped: dict[str, list[TimingPath]] = {}
    stage_orders: dict[str, int] = {}
    for item in paths:
        grouped.setdefault(item.stage, []).append(item)
        stage_orders[item.stage] = item.stage_order

    worst_by_stage = [items[0] for items in grouped.values()]
    worst_by_stage.sort(key=lambda item: item.slack_ns)

    lines = [
        "# 流水级时序汇总",
        "",
        "按每一级最差 Slack 从小到大排列。Slack 越小，越需要优先处理。",
        "",
        "| 优先级 | 流水级 | 最差 Slack (ns) | 数据延迟 (ns) | 逻辑/布线 (ns) | 布线占比 | Levels | 判断 |",
        "| ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for rank, item in enumerate(worst_by_stage, 1):
        lines.append(
            f"| {rank} | {item.stage} | {item.slack_ns:.3f} | "
            f"{item.data_delay_ns:.3f} | {item.logic_delay_ns:.3f}/{item.route_delay_ns:.3f} | "
            f"{item.route_percent:.1f}% | {item.logic_levels} | {diagnosis(item)} |"
        )

    lines.extend(["", "## 各级最差路径", ""])
    for item in sorted(worst_by_stage, key=lambda value: stage_orders[value.stage]):
        lines.extend(
            [
                f"### {item.stage}",
                "",
                f"- Slack：`{item.slack_ns:.3f} ns`，数据路径：`{item.data_delay_ns:.3f} ns`。",
                f"- 逻辑：`{item.logic_delay_ns:.3f} ns`，布线：`{item.route_delay_ns:.3f} ns`（`{item.route_percent:.1f}%`）。",
                f"- 逻辑级数：`{item.logic_levels}`（{item.logic_breakdown or '无明细'}）。",
                f"- 判断：{diagnosis(item)}。",
                f"- 起点：`{shorten_hierarchy(item.source)}`",
                f"- 终点：`{shorten_hierarchy(item.destination)}`",
                "",
            ]
        )

    lines.extend(
        [
            "## 全局最差 20 条唯一路径",
            "",
            "| 排名 | 流水级 | Slack (ns) | Delay (ns) | Levels | Route | Source | Destination |",
            "| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |",
        ]
    )
    for rank, item in enumerate(sorted(paths, key=lambda value: value.slack_ns)[:20], 1):
        lines.append(
            f"| {rank} | {item.stage} | {item.slack_ns:.3f} | {item.data_delay_ns:.3f} | "
            f"{item.logic_levels} | {item.route_percent:.1f}% | "
            f"`{markdown_escape(shorten_hierarchy(item.source))}` | "
            f"`{markdown_escape(shorten_hierarchy(item.destination))}` |"
        )

    output.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="汇总 Vivado 各流水级 top60 时序报告")
    parser.add_argument("--input", type=Path, default=DEFAULT_REPORT_DIR, help="top60 .rpt 所在目录")
    parser.add_argument("--output", type=Path, default=None, help="汇总文件输出目录，默认与输入目录相同")
    args = parser.parse_args()

    input_dir = args.input.resolve()
    output_dir = (args.output or input_dir).resolve()
    report_files = sorted(input_dir.glob("*_top60.rpt"))
    if not report_files:
        parser.error(f"没有找到报告：{input_dir}/*_top60.rpt")

    all_paths: list[TimingPath] = []
    for report_file in report_files:
        parsed = parse_report(report_file)
        print(f"{report_file.name}: {len(parsed)} 条唯一时序路径")
        all_paths.extend(parsed)

    if not all_paths:
        parser.error("找到了报告文件，但没有解析出有效路径")

    all_paths.sort(key=lambda item: (item.stage_order, item.slack_ns, -item.data_delay_ns))
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_output = output_dir / "timing_paths.csv"
    markdown_output = output_dir / "timing_summary.md"
    write_csv(all_paths, csv_output)
    write_markdown(all_paths, markdown_output)
    print(f"CSV: {csv_output}")
    print(f"Markdown: {markdown_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

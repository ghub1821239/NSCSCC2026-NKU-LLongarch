#!/usr/bin/env python3
"""Summarize per-stage Vivado timing reports as CSV and Markdown."""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass, replace
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
TABLE_HEADER_RE = re.compile(
    r"Location\s+Delay type\s+Incr\(ns\)\s+Path\(ns\)\s+Netlist Resource",
    re.IGNORECASE,
)
DASH_RE = re.compile(r"^\s*-{20,}")
WRAPPED_ARC_RE = re.compile(r"\((?:Prop|Setup|Hold)_[^)]+\)\s*$")
NET_RE = re.compile(
    rf"net\s+\((?P<info>[^)]+)\)\s+(?P<incr>{NUMBER})\s+(?P<cumul>{NUMBER})\s+(?P<name>\S+)",
    re.IGNORECASE,
)
CELL_PROP_RE = re.compile(
    rf"^(?P<loc>\S+)\s+(?P<cell>\S+)\s+\((?P<arc>Prop_[^)]+)\)\s+"
    rf"(?P<incr>{NUMBER})\s+(?P<cumul>{NUMBER})\s+(?:[rf]\s+)?(?P<name>\S+)",
)
CELL_CHECK_RE = re.compile(
    rf"^(?P<loc>\S+)\s+(?P<cell>\S+)\s+\((?P<arc>(?:Setup|Hold)_[^)]+)\)\s+"
    rf"(?P<incr>{NUMBER})\s+(?P<cumul>{NUMBER})",
)
CELL_PIN_RE = re.compile(
    rf"^(?P<loc>\S+)\s+(?P<cell>\S+)\s+[rf]\s+(?P<name>\S+)",
)
CLOCK_MARK_RE = re.compile(r"^\s*\(clock\s+", re.IGNORECASE)
CLOCK_ANNOT_RE = re.compile(
    r"clock pessimism|clock uncertainty|clock reconvergence|data arrival|"
    r"clock arrival|required time|arrival time|relative delay|\bslack\b",
    re.IGNORECASE,
)
FANOUT_RE = re.compile(r"fo\s*=\s*(\d+)", re.IGNORECASE)
LOC_PREFIX_RE = re.compile(r"^\s*(\S+)\s+")
NET_SUM_TOLERANCE_NS = 0.05
NET_SUM_TOLERANCE_RATIO = 0.02


@dataclass(frozen=True)
class PathHop:
    order: int
    hop_type: str
    object_name: str
    delay_ns: float
    cumulative_delay_ns: float
    fanout: int | None
    location: str
    delay_type: str
    path_ns: float | None
    from_pin: str
    to_pin: str


@dataclass(frozen=True)
class TimingPath:
    stage_order: int
    stage: str
    status: str
    slack_ns: float
    source: str
    destination: str
    requirement_ns: float | None
    data_delay_ns: float | None
    logic_delay_ns: float | None
    logic_percent: float | None
    route_delay_ns: float | None
    route_percent: float | None
    logic_levels: int | None
    logic_breakdown: str
    path_id: str = ""
    hops: tuple[PathHop, ...] = ()
    max_fanout: int | None = None
    worst_net: str = ""
    worst_net_delay_ns: float | None = None
    second_worst_net: str = ""
    second_worst_net_delay_ns: float | None = None
    worst_net_ratio: float | None = None
    top2_net_ratio: float | None = None
    warnings: tuple[str, ...] = ()

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


@dataclass
class RawRow:
    location: str
    delay_type: str
    incr: float | None
    path_ns: float | None
    resource: str
    kind: str
    fanout: int | None


def extract(pattern: str, block: str, default: str = "") -> str:
    match = re.search(pattern, block, re.MULTILINE)
    return match.group(1).strip() if match else default


def fmt_num(value: float | None, digits: int = 3) -> str:
    if value is None:
        return ""
    return f"{value:.{digits}f}"


def parse_optional_float(text: str) -> float | None:
    return float(text) if text else None


def logical_table_lines(lines: list[str]) -> list[str]:
    merged: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if WRAPPED_ARC_RE.search(line) and index + 1 < len(lines):
            line = line.rstrip() + " " + lines[index + 1].strip()
            index += 2
        else:
            index += 1
        merged.append(line)
    return merged


def classify_table_line(line: str) -> RawRow | None:
    stripped = line.strip()
    if not stripped or DASH_RE.match(line):
        return None
    if CLOCK_MARK_RE.match(line) or CLOCK_ANNOT_RE.search(stripped):
        return RawRow("", stripped, None, None, "", "clock", None)

    net_match = NET_RE.search(line)
    if net_match:
        loc_match = LOC_PREFIX_RE.match(line)
        location = loc_match.group(1) if loc_match and not loc_match.group(1).lower().startswith("net") else ""
        info = net_match.group("info")
        fanout_match = FANOUT_RE.search(info)
        return RawRow(
            location=location,
            delay_type=f"net ({info})",
            incr=float(net_match.group("incr")),
            path_ns=float(net_match.group("cumul")),
            resource=net_match.group("name"),
            kind="net",
            fanout=int(fanout_match.group(1)) if fanout_match else None,
        )

    prop_match = CELL_PROP_RE.search(stripped)
    if prop_match:
        return RawRow(
            location=prop_match.group("loc"),
            delay_type=f"{prop_match.group('cell')} ({prop_match.group('arc')})",
            incr=float(prop_match.group("incr")),
            path_ns=float(prop_match.group("cumul")),
            resource=prop_match.group("name"),
            kind="cell",
            fanout=None,
        )

    check_match = CELL_CHECK_RE.search(stripped)
    if check_match:
        return RawRow(
            location=check_match.group("loc"),
            delay_type=f"{check_match.group('cell')} ({check_match.group('arc')})",
            incr=float(check_match.group("incr")),
            path_ns=float(check_match.group("cumul")),
            resource="",
            kind="check",
            fanout=None,
        )

    pin_match = CELL_PIN_RE.search(stripped)
    if pin_match:
        return RawRow(
            location=pin_match.group("loc"),
            delay_type=pin_match.group("cell"),
            incr=None,
            path_ns=None,
            resource=pin_match.group("name"),
            kind="pin",
            fanout=None,
        )

    number_match = re.search(
        rf"({NUMBER})\s+({NUMBER})\s+(?:[rf]\s+)?(\S+)$", stripped
    )
    if number_match and not stripped.startswith("("):
        return RawRow(
            location="",
            delay_type=stripped,
            incr=float(number_match.group(1)),
            path_ns=float(number_match.group(2)),
            resource=number_match.group(3),
            kind="unknown",
            fanout=None,
        )
    return None


def split_table_sections(rows: list[RawRow], dash_before: list[bool]) -> list[list[RawRow]]:
    """Split parsed rows using the dash separators that originally bounded them."""
    sections: list[list[RawRow]] = []
    current: list[RawRow] = []
    for row, new_section in zip(rows, dash_before):
        if new_section and current:
            sections.append(current)
            current = []
        current.append(row)
    if current:
        sections.append(current)
    return sections


def net_delay_sum(rows: list[RawRow]) -> float:
    return sum(row.incr or 0.0 for row in rows if row.kind == "net")


def close_enough(actual: float, expected: float) -> bool:
    if expected <= 0:
        return actual <= NET_SUM_TOLERANCE_NS
    return abs(actual - expected) <= max(NET_SUM_TOLERANCE_NS, expected * NET_SUM_TOLERANCE_RATIO)


def source_q_name(source: str) -> str:
    if source.endswith("/C"):
        return source[:-2] + "/Q"
    return source


def slice_q_to_destination(rows: list[RawRow], source: str, destination: str) -> list[RawRow]:
    start = None
    q_name = source_q_name(source)
    for index, row in enumerate(rows):
        if row.kind != "cell":
            continue
        if row.resource == q_name or row.resource == source:
            start = index
            break
    if start is None:
        for index, row in enumerate(rows):
            if row.kind == "cell" and row.resource.endswith("/Q"):
                start = index
                break
    if start is None:
        return []

    end = len(rows) - 1
    if destination:
        for index in range(start, len(rows)):
            row = rows[index]
            if row.resource == destination:
                end = index
                break
            if row.kind == "clock":
                end = index - 1
                break
    return [row for row in rows[start:end + 1] if row.kind != "clock"]


def choose_data_path_rows(
    sections: list[list[RawRow]],
    all_rows: list[RawRow],
    source: str,
    destination: str,
    route_delay_ns: float | None,
) -> tuple[list[RawRow], str]:
    """Pick the Data Path rows. Prefer dash-bounded sections validated by Route Delay."""
    candidates: list[tuple[str, list[RawRow]]] = []
    if len(sections) >= 3:
        candidates.append(("dash_middle", sections[1]))
    for index, section in enumerate(sections):
        if any(row.kind == "cell" for row in section) and any(row.kind == "net" for row in section):
            candidates.append((f"dash_{index}", section))
    q_slice = slice_q_to_destination(all_rows, source, destination)
    if q_slice:
        candidates.append(("q_to_d", q_slice))

    if route_delay_ns is not None:
        scored: list[tuple[float, str, list[RawRow]]] = []
        seen: set[tuple[tuple[str, str, float | None], ...]] = set()
        for label, rows in candidates:
            key = tuple((row.kind, row.resource, row.incr) for row in rows)
            if key in seen:
                continue
            seen.add(key)
            scored.append((abs(net_delay_sum(rows) - route_delay_ns), label, rows))
        if scored:
            scored.sort(key=lambda item: item[0])
            error, label, rows = scored[0]
            expected = route_delay_ns
            if close_enough(net_delay_sum(rows), expected):
                return rows, label

    if q_slice:
        return q_slice, "q_to_d_unvalidated"
    if len(sections) >= 3:
        return sections[1], "dash_middle_unvalidated"
    return [], "missing"


def rows_to_hops(rows: list[RawRow]) -> tuple[PathHop, ...]:
    hops: list[PathHop] = []
    cumulative = 0.0
    pending_from = ""
    last_net_index: int | None = None
    for row in rows:
        if row.kind == "pin":
            if last_net_index is not None and hops[last_net_index].to_pin == "":
                hops[last_net_index] = replace(hops[last_net_index], to_pin=row.resource)
            if not pending_from:
                pending_from = row.resource
            continue
        if row.kind not in {"cell", "net", "unknown"}:
            continue
        if row.incr is None:
            if row.kind == "cell" and not pending_from:
                pending_from = row.resource
            continue
        hop_type = {
            "cell": "CELL",
            "net": "NET",
            "unknown": "UNKNOWN",
        }[row.kind]
        cumulative += row.incr
        hops.append(
            PathHop(
                order=len(hops) + 1,
                hop_type=hop_type,
                object_name=row.resource,
                delay_ns=row.incr,
                cumulative_delay_ns=round(cumulative, 3),
                fanout=row.fanout,
                location=row.location,
                delay_type=row.delay_type,
                path_ns=row.path_ns,
                from_pin=pending_from if hop_type == "NET" else "",
                to_pin="",
            )
        )
        if hop_type == "NET":
            last_net_index = len(hops) - 1
        elif hop_type == "CELL":
            pending_from = row.resource
            if last_net_index is not None and hops[last_net_index].to_pin == "":
                hops[last_net_index] = replace(hops[last_net_index], to_pin=row.resource)
    return tuple(hops)


def parse_data_path_table(
    block: str,
    source: str,
    destination: str,
    route_delay_ns: float | None,
) -> tuple[tuple[PathHop, ...], list[str]]:
    warnings: list[str] = []
    header_match = TABLE_HEADER_RE.search(block)
    if not header_match:
        warnings.append("未找到 Data Path 表格（Location / Delay type / Incr(ns)）")
        return (), warnings

    table_text = block[header_match.start():]
    stop = re.search(
        r"^\s*(required time|data arrival|slack)\b", table_text, re.MULTILINE | re.IGNORECASE
    )
    if stop:
        table_text = table_text[:stop.start()]

    raw_lines = logical_table_lines(table_text.splitlines())
    rows: list[RawRow] = []
    dash_before: list[bool] = []
    pending_section = False
    seen_header = False
    for line in raw_lines:
        if TABLE_HEADER_RE.search(line):
            seen_header = True
            pending_section = False
            continue
        if not seen_header:
            continue
        if DASH_RE.match(line):
            pending_section = True
            continue
        row = classify_table_line(line)
        if row is None:
            continue
        rows.append(row)
        dash_before.append(pending_section)
        pending_section = False

    if not rows:
        warnings.append("Data Path 表格存在，但没有解析出任何 Cell/Net 行")
        return (), warnings

    sections = split_table_sections(rows, dash_before)
    data_rows, how = choose_data_path_rows(sections, rows, source, destination, route_delay_ns)
    if not data_rows:
        warnings.append("无法从表格中隔离 Data Path（未找到 Q→D 段）")
        return (), warnings

    hops = rows_to_hops(data_rows)
    if not hops:
        warnings.append(f"已定位 Data Path（{how}），但没有带 Incr 的 CELL/NET 行")
        return (), warnings

    net_sum = sum(hop.delay_ns for hop in hops if hop.hop_type == "NET")
    if route_delay_ns is not None and not close_enough(net_sum, route_delay_ns):
        warnings.append(
            f"Data Path net Incr 之和 {net_sum:.3f} ns 与 Route Delay {route_delay_ns:.3f} ns 不一致（{how}）"
        )
    unknown = [hop.object_name for hop in hops if hop.hop_type == "UNKNOWN"]
    if unknown:
        warnings.append("存在无法区分 CELL/NET 的行，已标记为 UNKNOWN: " + ", ".join(unknown[:4]))
    return hops, warnings


def net_anatomy(hops: tuple[PathHop, ...], route_delay_ns: float | None) -> dict[str, object]:
    nets = [hop for hop in hops if hop.hop_type == "NET"]
    nets_sorted = sorted(nets, key=lambda hop: hop.delay_ns, reverse=True)
    worst = nets_sorted[0] if nets_sorted else None
    second = nets_sorted[1] if len(nets_sorted) > 1 else None
    denom = route_delay_ns if route_delay_ns and route_delay_ns > 0 else (
        sum(hop.delay_ns for hop in nets) or None
    )
    fanouts = [hop.fanout for hop in nets if hop.fanout is not None]
    worst_ratio = None
    top2_ratio = None
    if denom:
        if worst:
            worst_ratio = 100.0 * worst.delay_ns / denom
        if worst and second:
            top2_ratio = 100.0 * (worst.delay_ns + second.delay_ns) / denom
        elif worst:
            top2_ratio = worst_ratio
    return {
        "max_fanout": max(fanouts) if fanouts else None,
        "worst_net": worst.object_name if worst else "",
        "worst_net_delay_ns": worst.delay_ns if worst else None,
        "second_worst_net": second.object_name if second else "",
        "second_worst_net_delay_ns": second.delay_ns if second else None,
        "worst_net_ratio": worst_ratio,
        "top2_net_ratio": top2_ratio,
    }


def parse_path_block(
    block: str,
    stage_order: int,
    stage: str,
    status: str,
    slack_ns: float,
    report_name: str,
    path_index: int,
) -> TimingPath | None:
    warnings: list[str] = []
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
    path_type = extract(r"^\s*Path Type:\s*(\S+)", block)

    if path_type and "setup" not in path_type.lower() and "max" not in path_type.lower():
        return None
    if not source or not destination:
        warnings.append(f"{report_name} 第 {path_index} 条路径缺少 Source/Destination，已跳过")
        print(f"WARNING: {warnings[-1]}")
        return None
    if not data_match:
        warnings.append(f"{report_name} {source} -> {destination}: 缺少 Data Path Delay")
        print(f"WARNING: {warnings[-1]}")

    data_delay = float(data_match.group(1)) if data_match else None
    logic_delay = float(data_match.group(2)) if data_match else None
    logic_percent = float(data_match.group(3)) if data_match else None
    route_delay = float(data_match.group(4)) if data_match else None
    route_percent = float(data_match.group(5)) if data_match else None
    logic_levels = int(levels_match.group(1)) if levels_match else None
    logic_breakdown = (levels_match.group(2) or "").strip() if levels_match else ""
    if not levels_match:
        warnings.append(f"{report_name} {source} -> {destination}: 缺少 Logic Levels")
        print(f"WARNING: {warnings[-1]}")
    if not requirement:
        warnings.append(f"{report_name} {source} -> {destination}: 缺少 Requirement")
        print(f"WARNING: {warnings[-1]}")

    hops, table_warnings = parse_data_path_table(block, source, destination, route_delay)
    for message in table_warnings:
        full = f"{report_name} {source} -> {destination}: {message}"
        warnings.append(full)
        print(f"WARNING: {full}")
    anatomy = net_anatomy(hops, route_delay)

    return TimingPath(
        stage_order=stage_order,
        stage=stage,
        status=status,
        slack_ns=slack_ns,
        source=source,
        destination=destination,
        requirement_ns=parse_optional_float(requirement),
        data_delay_ns=data_delay,
        logic_delay_ns=logic_delay,
        logic_percent=logic_percent,
        route_delay_ns=route_delay,
        route_percent=route_percent,
        logic_levels=logic_levels,
        logic_breakdown=logic_breakdown,
        hops=hops,
        max_fanout=anatomy["max_fanout"],  # type: ignore[arg-type]
        worst_net=str(anatomy["worst_net"]),
        worst_net_delay_ns=anatomy["worst_net_delay_ns"],  # type: ignore[arg-type]
        second_worst_net=str(anatomy["second_worst_net"]),
        second_worst_net_delay_ns=anatomy["second_worst_net_delay_ns"],  # type: ignore[arg-type]
        worst_net_ratio=anatomy["worst_net_ratio"],  # type: ignore[arg-type]
        top2_net_ratio=anatomy["top2_net_ratio"],  # type: ignore[arg-type]
        warnings=tuple(warnings),
    )


def parse_report(path: Path) -> tuple[list[TimingPath], int]:
    name_match = REPORT_NAME_RE.match(path.name)
    if not name_match:
        print(f"WARNING: 跳过不符合 NN_<stage>_top60.rpt 命名的文件：{path.name}")
        return [], 1

    stage_order = int(name_match.group(1))
    stage = name_match.group(2)
    text = path.read_text(encoding="utf-8", errors="replace")
    starts = list(re.finditer(r"^Slack \(([^)]+)\)\s*:\s*(%s)ns" % NUMBER, text, re.MULTILINE))
    if not starts:
        print(f"WARNING: {path.name} 中没有找到 Slack (...) 路径块")
        return [], 1

    parsed: list[TimingPath] = []
    warning_count = 0
    for index, start in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(text)
        block = text[start.start():end]
        try:
            item = parse_path_block(
                block,
                stage_order,
                stage,
                start.group(1),
                float(start.group(2)),
                path.name,
                index + 1,
            )
        except Exception as exc:  # noqa: BLE001 - keep one bad path from aborting the report
            print(f"WARNING: {path.name} 第 {index + 1} 条路径解析失败：{exc}")
            warning_count += 1
            continue
        if item is None:
            continue
        warning_count += len(item.warnings)
        parsed.append(item)

    unique: dict[tuple[object, ...], TimingPath] = {}
    for timing_path in parsed:
        unique.setdefault(timing_path.key, timing_path)
    return sorted(unique.values(), key=lambda item: (item.slack_ns, -(item.data_delay_ns or 0.0))), warning_count


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

    if path.route_percent is not None and path.route_percent >= 70:
        notes.append("布线主导")
    elif path.logic_percent is not None and path.logic_percent >= 50:
        notes.append("逻辑主导")

    if path.logic_levels is not None and path.logic_levels >= 20:
        notes.append("逻辑级数较深")
    if path.top2_net_ratio is not None and path.route_delay_ns:
        if path.top2_net_ratio >= 60:
            notes.append("长线集中")
        elif path.top2_net_ratio < 40:
            notes.append("布线分散")
    return "、".join(notes) if notes else "裕量充足"


def assign_path_ids(paths: list[TimingPath]) -> list[TimingPath]:
    ranked = sorted(paths, key=lambda item: (item.slack_ns, -(item.data_delay_ns or 0.0)))
    return [
        replace(item, path_id=f"P{index:03d}")
        for index, item in enumerate(ranked, 1)
    ]


def write_paths_csv(paths: list[TimingPath], output: Path) -> None:
    fields = [
        "path_id",
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
        "max_fanout",
        "worst_net",
        "worst_net_delay_ns",
        "second_worst_net",
        "second_worst_net_delay_ns",
        "worst_net_ratio",
        "top2_net_ratio",
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
                    "path_id": item.path_id,
                    "stage": item.stage,
                    "rank": ranks[item.stage],
                    "status": item.status,
                    "slack_ns": f"{item.slack_ns:.3f}",
                    "requirement_ns": fmt_num(item.requirement_ns),
                    "data_delay_ns": fmt_num(item.data_delay_ns),
                    "logic_delay_ns": fmt_num(item.logic_delay_ns),
                    "logic_percent": fmt_num(item.logic_percent),
                    "route_delay_ns": fmt_num(item.route_delay_ns),
                    "route_percent": fmt_num(item.route_percent),
                    "logic_levels": "" if item.logic_levels is None else item.logic_levels,
                    "max_fanout": "" if item.max_fanout is None else item.max_fanout,
                    "worst_net": item.worst_net,
                    "worst_net_delay_ns": fmt_num(item.worst_net_delay_ns),
                    "second_worst_net": item.second_worst_net,
                    "second_worst_net_delay_ns": fmt_num(item.second_worst_net_delay_ns),
                    "worst_net_ratio": fmt_num(item.worst_net_ratio, 1),
                    "top2_net_ratio": fmt_num(item.top2_net_ratio, 1),
                    "diagnosis": diagnosis(item),
                    "source": item.source,
                    "destination": item.destination,
                    "logic_breakdown": item.logic_breakdown,
                }
            )


def write_nets_csv(paths: list[TimingPath], output: Path) -> int:
    fields = [
        "path_id",
        "stage",
        "order",
        "type",
        "object",
        "delay_ns",
        "cumulative_delay_ns",
        "path_ns",
        "fanout",
        "from_pin",
        "to_pin",
        "location",
        "delay_type",
    ]
    count = 0
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for item in paths:
            for hop in item.hops:
                writer.writerow(
                    {
                        "path_id": item.path_id,
                        "stage": item.stage,
                        "order": hop.order,
                        "type": hop.hop_type,
                        "object": hop.object_name,
                        "delay_ns": f"{hop.delay_ns:.3f}",
                        "cumulative_delay_ns": f"{hop.cumulative_delay_ns:.3f}",
                        "path_ns": fmt_num(hop.path_ns),
                        "fanout": "" if hop.fanout is None else hop.fanout,
                        "from_pin": hop.from_pin,
                        "to_pin": hop.to_pin,
                        "location": hop.location,
                        "delay_type": hop.delay_type,
                    }
                )
                count += 1
    return count


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
        "| 优先级 | 流水级 | 最差 Slack (ns) | 数据延迟 (ns) | 逻辑/布线 (ns) | 布线占比 | Levels | 最长 Net (ns) | Top2 Net | 判断 |",
        "| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for rank, item in enumerate(worst_by_stage, 1):
        lines.append(
            f"| {rank} | {item.stage} | {item.slack_ns:.3f} | "
            f"{fmt_num(item.data_delay_ns)} | {fmt_num(item.logic_delay_ns)}/{fmt_num(item.route_delay_ns)} | "
            f"{fmt_num(item.route_percent, 1)}% | {item.logic_levels if item.logic_levels is not None else ''} | "
            f"{fmt_num(item.worst_net_delay_ns)} | {fmt_num(item.top2_net_ratio, 1)}% | {diagnosis(item)} |"
        )

    lines.extend(["", "## 各级最差路径", ""])
    for item in sorted(worst_by_stage, key=lambda value: stage_orders[value.stage]):
        lines.extend(
            [
                f"### {item.stage}",
                "",
                f"- Path ID：`{item.path_id}`。",
                f"- Slack：`{item.slack_ns:.3f} ns`，数据路径：`{fmt_num(item.data_delay_ns)} ns`。",
                f"- 逻辑：`{fmt_num(item.logic_delay_ns)} ns`，布线：`{fmt_num(item.route_delay_ns)} ns`"
                f"（`{fmt_num(item.route_percent, 1)}%`）。",
                f"- 逻辑级数：`{item.logic_levels if item.logic_levels is not None else 'N/A'}`"
                f"（{item.logic_breakdown or '无明细'}）。",
                f"- 最长 Net：`{item.worst_net or 'N/A'}`（`{fmt_num(item.worst_net_delay_ns)} ns`，"
                f"`{fmt_num(item.worst_net_ratio, 1)}%`）。",
                f"- 次长 Net：`{item.second_worst_net or 'N/A'}`（`{fmt_num(item.second_worst_net_delay_ns)} ns`）。",
                f"- Top2 Net / Route Delay：`{fmt_num(item.top2_net_ratio, 1)}%`。",
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
            "| 排名 | ID | 流水级 | Slack (ns) | Delay (ns) | Levels | Route | 最长 Net (ns) | Top2 | Source | Destination |",
            "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
        ]
    )
    for rank, item in enumerate(sorted(paths, key=lambda value: value.slack_ns)[:20], 1):
        lines.append(
            f"| {rank} | {item.path_id} | {item.stage} | {item.slack_ns:.3f} | {fmt_num(item.data_delay_ns)} | "
            f"{item.logic_levels if item.logic_levels is not None else ''} | {fmt_num(item.route_percent, 1)}% | "
            f"{fmt_num(item.worst_net_delay_ns)} | {fmt_num(item.top2_net_ratio, 1)}% | "
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
    warning_count = 0
    for report_file in report_files:
        parsed, report_warnings = parse_report(report_file)
        warning_count += report_warnings
        print(f"{report_file.name}: {len(parsed)} 条唯一时序路径")
        all_paths.extend(parsed)

    if not all_paths:
        parser.error("找到了报告文件，但没有解析出有效路径")

    all_paths.sort(key=lambda item: (item.stage_order, item.slack_ns, -(item.data_delay_ns or 0.0)))
    all_paths = assign_path_ids(all_paths)
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_output = output_dir / "timing_paths.csv"
    nets_output = output_dir / "timing_nets.csv"
    markdown_output = output_dir / "timing_summary.md"
    write_paths_csv(all_paths, csv_output)
    net_count = write_nets_csv(all_paths, nets_output)
    write_markdown(all_paths, markdown_output)
    print(f"读取报告数量: {len(report_files)}")
    print(f"解析路径数量: {len(all_paths)}")
    print(f"解析 net/cell 行数量: {net_count}")
    print(f"warning 数量: {warning_count}")
    print(f"CSV: {csv_output}")
    print(f"Nets CSV: {nets_output}")
    print(f"Markdown: {markdown_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

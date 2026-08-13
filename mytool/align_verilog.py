#!/usr/bin/env python3
"""Whitespace-only Verilog alignment for IP/myCPU style RTL.

Rules (all changes are spaces only; comments, strings, identifiers and line
endings are preserved byte-for-byte):
  1. Consecutive wire/reg/integer/genvar declarations, single/multi-line
     assign statements and parameter/localparam lines form one block, grouped
     within banner-comment delimited sections (----/***/=== comments split).
     Type column, packed-range column, signal-name column and unpacked-array
     column (`[ISSUE-1:0]`) are aligned using the longest member; for
     statements with '=' the operator is aligned too.
  2. Continuation lines of a multi-line statement are re-indented so they line
     up with the RHS column (the text after '='). If the RHS opens with `{` or
     `(`, body lines are indented one extra space so they sit inside the wrap;
     a closer-only line (`};` / `);` / `} = ...`) stays at the `{`/`(` column.
     Nested `?:` wrapped in `()` use a tab (4 spaces) per paren level instead
     of flattening to the RHS column.
     Multi-line `{...}` concatenations (pack or unpack) align comma-separated
     fields into a table, like the `|` OR tables.
  3. Inside each always block, 'lhs <= rhs;' / 'lhs = rhs;' statements are
     aligned together: LHS padded to the longest name, operator column fixed.
  4. Each module instantiation is aligned as one block: every '.port(...)'
     connection (parameter list included) has the '.'/name field padded so the
     '(' column is fixed and the signal field is padded so the ')' column is
     fixed as well.
  5. Module port lists are aligned as one block (direction/type/range/name).

Usage:
    # 默认格式化 IP/myCPU/*.v
    python3 mytool/align_verilog.py

    # 先看会改多少行，不写入
    python3 mytool/align_verilog.py --dry-run

    # 自定义范围
    python3 mytool/align_verilog.py 'IP/myCPU/MEM.v' 'chip/soc_demo/nscscc-team/*.v'

Default pattern: IP/myCPU/*.v
"""

import glob
import re
import sys

KEY_ASSIGN = b'assign'
KEY_PARAMS = (b'parameter', b'localparam')
KEY_DECLS = (b'wire', b'reg', b'integer', b'genvar')
KEY_PORTS = (b'input', b'output', b'inout')
IDENT_RE = re.compile(rb'[A-Za-z_][A-Za-z0-9_$]*')
BEGIN_RE = re.compile(rb'\bbegin\b')
END_RE = re.compile(rb'\bend\b')
TAB_WIDTH = 4
EXCLUDED_FIRST = {
    b'if', b'else', b'case', b'casez', b'casex', b'endcase', b'begin', b'end',
    b'for', b'while', b'repeat', b'forever', b'always', b'initial', b'module',
    b'endmodule', b'generate', b'endgenerate', b'default', b'assign', b'wire',
    b'reg', b'integer', b'genvar', b'input', b'output', b'inout', b'parameter',
    b'localparam', b'return', b'break', b'continue', b'function', b'endfunction',
    b'task', b'endtask',
}


def starts_with(rest, words):
    for w in words:
        if rest.startswith(w):
            after = rest[len(w):]
            if after and after[0:1] in b' \t':
                return w
    return None


def split_comment(rest):
    i = rest.find(b'//')
    if i < 0:
        return rest, b''
    return rest[:i], rest[i:]


def skip_ws(code, pos):
    while pos < len(code) and code[pos:pos + 1] in b' \t':
        pos += 1
    return pos


def parse_unpacked(code, pos):
    """Packed-array `[ISSUE-1:0]` after a signal name; empty if none."""
    pos = skip_ws(code, pos)
    if pos < len(code) and code[pos:pos + 1] == b'[':
        rng, npos = parse_range(code, pos)
        if rng is not None:
            return rng, npos
    return b'', pos


def parse_range(code, pos):
    depth = 0
    for i in range(pos, len(code)):
        c = code[i:i + 1]
        if c == b'[':
            depth += 1
        elif c == b']':
            depth -= 1
            if depth == 0:
                return code[pos:i + 1], i + 1
    return None, pos


def parse_conn(code):
    """Parse a single '.name(signal)' connection line; None if not one."""
    m = re.match(rb'^\.([A-Za-z_][A-Za-z0-9_$]*)\s*\(', code)
    if not m:
        return None
    pos = m.end() - 1
    depth = 0
    end = -1
    for i in range(pos, len(code)):
        c = code[i:i + 1]
        if c == b'(':
            depth += 1
        elif c == b')':
            depth -= 1
            if depth == 0:
                end = i
                break
    if end < 0:
        return None
    rest = code[end + 1:]
    if b'.' in rest and b'(' in rest:
        return None  # multiple connections on one line
    return {'name': b'.' + m.group(1),
            'signal': code[pos + 1:end].strip(),
            'tail': rest}


def is_banner(stripped):
    c = stripped[2:]
    return (b'---' in c) or (b'***' in c) or (b'===' in c)


def code_part_of(body):
    st = body.lstrip(b' \t')
    if not st or st.startswith(b'//'):
        return b''
    code, _ = split_comment(st)
    return code


def analyze(body, cr, in_always):
    stripped = body.lstrip(b' \t')
    if not stripped:
        return 'blank', None
    if stripped.startswith(b'//'):
        return ('banner' if is_banner(stripped) else 'comment'), None
    indent = body[:len(body) - len(stripped)]
    if b'"' in stripped:
        return 'skip', None
    code, comment = split_comment(stripped)
    if not code.strip():
        return ('banner' if is_banner(stripped) else 'comment'), None

    kw = starts_with(code, (KEY_ASSIGN,))
    if kw:
        m = re.match(rb'assign\s+', code)
        eq = code.find(b'=')
        if m and eq > m.end():
            lhs = code[m.end():eq].rstrip()
            if lhs:
                semi = code.rstrip().rfind(b';')
                if semi > eq:
                    return 'assign', {'kind': 'assign', 'kw': kw, 'indent': indent,
                                      'name': lhs, 'range': b'', 'has_eq': True,
                                      'rhs': code[eq + 1:semi].strip(),
                                      'tail': code[semi:] + comment,
                                      'multi': False, 'cont': [], 'cr': cr}
                return 'assign', {'kind': 'assign', 'kw': kw, 'indent': indent,
                                  'name': lhs, 'range': b'', 'has_eq': True,
                                  'rhs': code[eq + 1:].lstrip().rstrip(),
                                  'tail': comment, 'multi': True, 'cont': [], 'cr': cr}
        rest = code[m.end():].lstrip() if m else b''
        if m and rest.startswith(b'{') and eq < 0:
            return 'assign', {'kind': 'assign', 'kw': kw, 'indent': indent,
                              'name': b'', 'range': b'', 'has_eq': False,
                              'concat_lhs': True,
                              'rhs': rest.rstrip(),
                              'tail': comment, 'multi': True, 'cont': [], 'cr': cr}
        return 'other', None

    kw = starts_with(code, KEY_PARAMS)
    if kw:
        m = re.match(rb'(?:parameter|localparam)\s+', code)
        eq = code.find(b'=')
        if m and eq > m.end():
            lhs = code[m.end():eq].rstrip()
            if lhs:
                trimmed = code.rstrip()
                term = -1
                for ch in (b';', b','):
                    p = trimmed.rfind(ch)
                    if p > term:
                        term = p
                if term < 0:
                    term = len(trimmed)
                return 'param', {'kind': 'param', 'kw': kw, 'indent': indent,
                                 'name': lhs, 'range': b'', 'has_eq': True,
                                 'rhs': code[eq + 1:term].strip(),
                                 'tail': code[term:] + comment,
                                 'multi': False, 'cont': [], 'cr': cr}
        return 'other', None

    kw = starts_with(code, KEY_DECLS)
    if kw:
        m = re.match(rb'(?:wire|reg|integer|genvar)\s+', code)
        if m:
            pos = m.end()
            range_ = b''
            if pos < len(code) and code[pos:pos + 1] == b'[':
                rng, pos = parse_range(code, pos)
                if rng is None:
                    return 'other', None
                range_ = rng
            while pos < len(code) and code[pos:pos + 1] in b' \t':
                pos += 1
            mm = IDENT_RE.match(code, pos)
            if not mm:
                return 'other', None
            name = mm.group()
            unpacked, pos = parse_unpacked(code, mm.end())
            eq = code.find(b'=', pos)
            if eq >= 0:
                semi = code.rstrip().rfind(b';')
                if semi > eq:
                    return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                    'name': name, 'range': range_, 'unpacked': unpacked,
                                    'has_eq': True,
                                    'rhs': code[eq + 1:semi].strip(),
                                    'tail': code[semi:] + comment,
                                    'multi': False, 'cont': [], 'cr': cr}
                return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                'name': name, 'range': range_, 'unpacked': unpacked,
                                'has_eq': True,
                                'rhs': code[eq + 1:].lstrip().rstrip(),
                                'tail': comment, 'multi': True, 'cont': [], 'cr': cr}
            if b';' in code:
                return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                'name': name, 'range': range_, 'unpacked': unpacked,
                                'has_eq': False,
                                'rhs': b'', 'tail': code[pos:] + comment,
                                'multi': False, 'cont': [], 'cr': cr}
        return 'other', None

    kw = starts_with(code, KEY_PORTS)
    if kw:
        m = re.match(rb'(?:input|output|inout)\s+', code)
        if m:
            pos = m.end()
            type_ = b''
            mm = IDENT_RE.match(code, pos)
            if mm and mm.group() in (b'wire', b'reg'):
                type_ = mm.group()
                pos = mm.end()
            while pos < len(code) and code[pos:pos + 1] in b' \t':
                pos += 1
            range_ = b''
            if pos < len(code) and code[pos:pos + 1] == b'[':
                rng, pos = parse_range(code, pos)
                if rng is None:
                    return 'other', None
                range_ = rng
            while pos < len(code) and code[pos:pos + 1] in b' \t':
                pos += 1
            mm = IDENT_RE.match(code, pos)
            if not mm:
                return 'other', None
            unpacked, pos = parse_unpacked(code, mm.end())
            return 'port', {'kind': 'port', 'indent': indent, 'direction': kw,
                            'type': type_, 'range': range_, 'name': mm.group(),
                            'unpacked': unpacked,
                            'tail': code[pos:] + comment, 'cr': cr}
        return 'other', None

    if in_always:
        first = IDENT_RE.match(code, 0)
        if first and first.group() in EXCLUDED_FIRST:
            return 'other', None
        # A real assignment statement starts with an identifier or a
        # concatenation '{'; continuation lines such as '(a != b)' must never
        # be treated as assignments (their '=' belongs to a comparison).
        if not (first or code[:1] == b'{'):
            return 'other', None
        op_pos = code.find(b'<=')
        op = b'<='
        if op_pos < 0:
            op_pos = code.find(b'=')
            op = b'='
        if op_pos > 0:
            prev = code[op_pos - 1:op_pos]
            nxt = code[op_pos + len(op):op_pos + len(op) + 1]
            if prev in b'!<>=&|' or nxt == b'=':
                return 'other', None
            lhs = code[:op_pos].rstrip()
            if lhs and lhs[:1] not in b' \t':
                semi = code.rstrip().rfind(b';')
                if semi > op_pos:
                    return 'always_assign', {'kind': 'always_assign',
                                             'indent': indent, 'name': lhs, 'op': op,
                                             'rhs': code[op_pos + len(op):semi].strip(),
                                             'tail': code[semi:] + comment,
                                             'multi': False, 'cont': [], 'cr': cr}
                if b';' not in code:
                    return 'always_assign', {'kind': 'always_assign',
                                             'indent': indent, 'name': lhs, 'op': op,
                                             'rhs': code[op_pos + len(op):].lstrip().rstrip(),
                                             'tail': comment,
                                             'multi': True, 'cont': [], 'cr': cr}
        return 'other', None

    return 'other', None


def wrap_delta(code):
    """Net `()` / `{}` depth change, ignoring bit-select `[]`."""
    delta = 0
    i = 0
    while i < len(code):
        c = code[i:i + 1]
        if c == b'[':
            depth = 1
            i += 1
            while i < len(code) and depth:
                if code[i:i + 1] == b'[':
                    depth += 1
                elif code[i:i + 1] == b']':
                    depth -= 1
                i += 1
            continue
        if c == b'(' or c == b'{':
            delta += 1
        elif c == b')' or c == b'}':
            delta -= 1
        i += 1
    return delta


def is_wrap_opener(rhs):
    """True when `{` / `(` wraps the rest of the statement, not a same-line group."""
    s = rhs.lstrip()
    if s[:1] not in (b'{', b'('):
        return False
    if s.strip() in (b'{', b'('):
        return True
    return wrap_delta(s) > 0


def is_nested_ternary_wrap(rec):
    """Paren-wrapped nested `?:`, with `)` / `:` / `(` as structural lines."""
    bodies = [rec.get('rhs', b'')]
    for _ci, st, _ccr in rec.get('cont', []):
        bodies.append(split_comment(st)[0])
    if not any(b'?' in code for code in bodies):
        return False
    structural = {b'(', b')', b');', b':', b'};', b'}'}
    return any(code.strip() in structural for code in bodies)


def next_tab_stop(col):
    return (col // TAB_WIDTH + 1) * TAB_WIDTH


def nested_ternary_cont_col(depth_start, depth_after, rest, wrap_base):
    if not rest:
        return 0
    code, _ = split_comment(rest)
    token = code.strip()
    if token[:1] in (b')', b'}'):
        level = max(depth_after, 0)
    else:
        level = max(depth_start, 1)
    return wrap_base + (level - 1) * TAB_WIDTH


def wrap_continuation_col(rhs, rest, rhs_col):
    """Indent inside a `{` / `(` wrap: body +1, closer-only line at opener."""
    if not is_wrap_opener(rhs) or not rest:
        return rhs_col
    code, _ = split_comment(rest)
    token = code.strip()
    if token[:1] in (b'}', b')'):
        return rhs_col
    return rhs_col + 1


def rewrite_continuations(rec, rhs_col, out):
    nested = is_nested_ternary_wrap(rec)
    wrap_base = next_tab_stop(rhs_col) if nested else None
    depth = wrap_delta(rec.get('rhs', b'')) if nested else 0
    for ci, rest, ccr in rec['cont']:
        if not rest:
            out[ci] = rest + ccr
            continue
        if rec.get('ternary_chain'):
            out[ci] = b' ' * rhs_col + rest + ccr
            continue
        if nested:
            code, _ = split_comment(rest)
            d0 = depth
            depth += wrap_delta(code)
            col = nested_ternary_cont_col(d0, depth, rest, wrap_base)
        else:
            col = wrap_continuation_col(rec['rhs'], rest, rhs_col)
        out[ci] = b' ' * col + rest + ccr


def rewrite_decl_assign(run, out):
    recs = [rec for _, rec in run]
    type_col = max(len(r['kw']) for r in recs)
    range_col = max([len(r['range']) for r in recs] + [0])
    name_col = type_col + 1 + range_col + 1
    name_w = max(len(r['name']) for r in recs)
    rhs_col = len(recs[0]['indent']) + name_col + name_w + 3
    for rec in recs:
        if rec['multi']:
            align_multiline_table(rec)
    for idx, rec in run:
        field = rec['kw'].ljust(type_col) + b' ' + rec['range'].ljust(range_col) + b' '
        unpacked = rec.get('unpacked', b'')
        if rec.get('concat_lhs'):
            out[idx] = (rec['indent'] + rec['kw'].ljust(type_col) + b' ' +
                        rec['rhs'] + rec['tail'] + rec['cr'])
            opener_col = len(rec['indent']) + type_col + 1
            if rec['multi']:
                rewrite_continuations(rec, opener_col, out)
            continue
        if rec['has_eq']:
            sep = b' = ' if rec['rhs'] else b' ='
            name_part = rec['name'].ljust(name_w) + unpacked
            out[idx] = (rec['indent'] + field + name_part + sep +
                        rec['rhs'] + rec['tail'] + rec['cr'])
            if rec['multi']:
                rewrite_continuations(rec, rhs_col, out)
        elif unpacked:
            out[idx] = (rec['indent'] + field + rec['name'].ljust(name_w) +
                        unpacked + rec['tail'] + rec['cr'])
        else:
            out[idx] = rec['indent'] + field + rec['name'] + rec['tail'] + rec['cr']


def align_multiline_table(rec):
    """Align operators inside a multi-line statement.

    Prefer a `|` table (OR-of-many-terms, possibly only on continuation
    lines after a first line of `&`). Else a `,` table for `{...}`
    concatenations (pack or unpack). Fall back to lining up a shared
    first single-char operator (e.g. `&`) plus a trailing `|` column.
    """
    bodies = [(rec['rhs'], rec['tail'])]
    for _ci, st, _ccr in rec['cont']:
        code, comment = split_comment(st)
        bodies.append((code, comment))
    if any(not code.strip() for code, _ in bodies):
        return
    if is_nested_ternary_wrap(rec):
        return
    if is_ternary_chain(rec):
        if align_ternary_chain(rec):
            return

    pipe_idxs = [i for i, (code, _) in enumerate(bodies)
                 if len(find_or_positions(code)) >= 1]
    if len(pipe_idxs) >= 2:
        codes = [bodies[i][0] for i in pipe_idxs]
        aligned_codes = align_pipe_codes(codes)
        if aligned_codes is not None:
            for i, new_code in zip(pipe_idxs, aligned_codes):
                bodies[i] = (new_code, bodies[i][1])
            rec['rhs'] = bodies[0][0]
            rec['tail'] = bodies[0][1]
            rec['cont'] = [
                (ci, code + comment, ccr)
                for (ci, _st, ccr), (code, comment) in zip(rec['cont'], bodies[1:])
            ]
            return

    if rec.get('concat_lhs') or rec['rhs'].lstrip()[:1] == b'{':
        field_idxs = [i for i, (code, _) in enumerate(bodies)
                      if concat_line_kind(code) == 'field']
        if len(field_idxs) >= 2:
            codes = [bodies[i][0] for i in field_idxs]
            aligned_codes = align_comma_codes(codes)
            if aligned_codes is not None:
                for i, new_code in zip(field_idxs, aligned_codes):
                    bodies[i] = (new_code, bodies[i][1])
                rec['rhs'] = bodies[0][0]
                rec['tail'] = bodies[0][1]
                rec['cont'] = [
                    (ci, code + comment, ccr)
                    for (ci, _st, ccr), (code, comment) in zip(rec['cont'], bodies[1:])
                ]
                return

    ops = [first_candidate(code) for code, _ in bodies]
    if any(o is None for o in ops):
        return
    op = ops[0][1]
    if any(o[1] != op for o in ops):
        return

    max_pre = max(p for p, _ in ops)
    aligned = []
    for (code, comment), (p, _) in zip(bodies, ops):
        aligned.append((code[:p].ljust(max_pre) + op + code[p + 1:], comment))

    has_pipe = [code.rstrip().endswith(b'|') for code, _ in aligned]
    if any(has_pipe):
        def pipe_start(code):
            t = len(code.rstrip()) - 1
            if t > 0 and code[t - 1:t] == b'|':
                t -= 1  # '||' is one token; align its start, never split it
            return t
        max_t = max(pipe_start(code)
                    for (code, _), hp in zip(aligned, has_pipe) if hp)
        final = []
        for (code, comment), hp in zip(aligned, has_pipe):
            if hp:
                t = pipe_start(code)
                code = code[:t].ljust(max_t) + code[t:]
            final.append((code, comment))
        aligned = final

    rec['rhs'] = aligned[0][0]
    rec['tail'] = aligned[0][1]
    rec['cont'] = [
        (ci, code + comment, ccr)
        for (ci, _st, ccr), (code, comment) in zip(rec['cont'], aligned[1:])
    ]


def find_or_positions(code):
    """Byte offsets of OR `|` (not `||`) outside `[]`."""
    pos = []
    depth = 0
    i = 0
    while i < len(code):
        c = code[i:i + 1]
        if c == b'[':
            depth += 1
        elif c == b']':
            depth -= 1
        elif depth == 0 and c == b'|':
            if code[i + 1:i + 2] == b'|':
                i += 2
                continue
            pos.append(i)
        i += 1
    return pos


def depth0_operator(code, op):
    """Byte offset of a single-char operator at paren/brace depth 0.

    Bit-select `[]` is skipped so a range `:` or select never matches.
    String literals are skipped too.
    """
    brace = bracket = paren = 0
    i = 0
    while i < len(code):
        c = code[i:i + 1]
        if c == b'"':
            i += 1
            while i < len(code) and code[i:i + 1] != b'"':
                i += 1
            i += 1
            continue
        if c == b'{':
            brace += 1
        elif c == b'}':
            brace -= 1
        elif c == b'[':
            bracket += 1
        elif c == b']':
            bracket -= 1
        elif c == b'(':
            paren += 1
        elif c == b')':
            paren -= 1
        elif brace == 0 and bracket == 0 and paren == 0 and c == op:
            return i
        i += 1
    return None


def last_depth0_colon(code, start):
    """Byte offset of the last `:` at paren/brace depth 0 after `start`."""
    brace = bracket = paren = 0
    pos = None
    i = start
    while i < len(code):
        c = code[i:i + 1]
        if c == b'"':
            i += 1
            while i < len(code) and code[i:i + 1] != b'"':
                i += 1
            i += 1
            continue
        if c == b'{':
            brace += 1
        elif c == b'}':
            brace -= 1
        elif c == b'[':
            bracket += 1
        elif c == b']':
            bracket -= 1
        elif c == b'(':
            paren += 1
        elif c == b')':
            paren -= 1
        elif brace == 0 and bracket == 0 and paren == 0 and c == b':':
            pos = i
        i += 1
    return pos


def is_ternary_chain(rec):
    """True for a multi-line `cond ? val :` chain (not a paren-wrapped one)."""
    if is_nested_ternary_wrap(rec):
        return False
    bodies = [rec.get('rhs', b'')]
    for _ci, st, _ccr in rec.get('cont', []):
        bodies.append(split_comment(st)[0])
    return any(depth0_operator(code, b'?') is not None for code in bodies)


def align_ternary_chain(rec):
    """Align `?` / `:` columns of a multi-line ternary chain.

    Each line is one of:
      - `cond ? val :`  (a complete ternary segment),
      - a wrapped condition line followed by a `?`-only line,
      - a final `val;` line, indented to the value column.
    Returns False (and leaves the record untouched) when the shape is not a
    clean chain; the caller then falls back to the table/operator rules.
    """
    bodies = [(rec['rhs'], rec['tail'])]
    for _ci, st, _ccr in rec['cont']:
        code, comment = split_comment(st)
        bodies.append((code, comment))
    if any(not code.strip() for code, _ in bodies):
        return False

    items = []
    last = len(bodies) - 1
    for idx, (code, comment) in enumerate(bodies):
        q = depth0_operator(code, b'?')
        if q is not None:
            colon = last_depth0_colon(code, q + 1)
            if colon is None:
                return False
            items.append({'kind': 'tern',
                          'cond': code[:q].rstrip(),
                          'value': code[q + 1:colon].strip(),
                          'tail': code[colon + 1:],
                          'comment': comment})
        elif idx == last:
            items.append({'kind': 'else',
                          'value': code.strip(),
                          'comment': comment})
        else:
            items.append({'kind': 'plain', 'code': code, 'comment': comment})

    tern_count = sum(1 for it in items if it['kind'] == 'tern')
    if tern_count < 1:
        return False
    for k, it in enumerate(items):
        if it['kind'] == 'plain':
            nxt = items[k + 1] if k + 1 < len(items) else None
            if nxt is None or nxt['kind'] != 'tern' or nxt['cond']:
                return False
        elif it['kind'] == 'tern' and not it['cond']:
            prev = items[k - 1] if k > 0 else None
            if prev is None or prev['kind'] != 'plain':
                return False
        elif it['kind'] == 'else' and k != len(items) - 1:
            return False

    cond_lens = [len(it['cond']) for it in items
                 if it['kind'] == 'tern' and it['cond']]
    cond_lens += [len(it['code']) for it in items if it['kind'] == 'plain']
    values = [it['value'] for it in items if it['kind'] == 'tern']
    if not cond_lens or not values or any(v == b'' for v in values):
        return False
    max_cond = max(cond_lens)
    max_val = max(len(v) for v in values)

    rebuilt = []
    for it in items:
        if it['kind'] == 'tern':
            if it['cond']:
                line = (it['cond'].ljust(max_cond) + b' ? ' +
                        it['value'].ljust(max_val) + b' :' + it['tail'])
            else:
                line = (b' ' * (max_cond + 1) + b'? ' +
                        it['value'].ljust(max_val) + b' :' + it['tail'])
        elif it['kind'] == 'plain':
            line = it['code']
        else:
            line = b' ' * (max_cond + 3) + it['value']
        if it['comment']:
            line = line.rstrip() + b' ' + it['comment']
        rebuilt.append(line)

    rec['rhs'] = rebuilt[0]
    rec['tail'] = b''
    rec['cont'] = [
        (ci, code, ccr)
        for (ci, _st, ccr), code in zip(rec['cont'], rebuilt[1:])
    ]
    rec['ternary_chain'] = True
    return True


def split_or_fields(code):
    pipes = find_or_positions(code)
    trailing = bool(pipes) and code.rstrip().endswith(b'|')
    if not pipes:
        return [code], False
    fields = []
    start = 0
    for p in pipes:
        fields.append(code[start:p])
        start = p + 1
    last = code[start:]
    if trailing:
        if last.strip():
            fields.append(last)
    else:
        fields.append(last)
    return fields, trailing


def concat_line_kind(code):
    t = code.strip()
    if not t:
        return 'empty'
    if t in (b'{', b'('):
        return 'opener'
    if t[:1] in (b'}', b')'):
        return 'closer'
    return 'field'


def split_off_concat_closer(s):
    """Split trailing `} = bus;` / `);` off a concat field line."""
    brace = bracket = paren = 0
    i = 0
    while i < len(s):
        c = s[i:i + 1]
        if c == b'{':
            brace += 1
        elif c == b'}':
            if brace == 0 and bracket == 0 and paren == 0:
                return s[:i].rstrip(), s[i:]
            brace -= 1
        elif c == b'[':
            bracket += 1
        elif c == b']':
            bracket -= 1
        elif c == b'(':
            paren += 1
        elif c == b')':
            if paren == 0 and brace == 0 and bracket == 0:
                return s[:i].rstrip(), s[i:]
            paren -= 1
        i += 1
    return s, b''


def unwrap_concat_line(code):
    s = code.strip()
    prefix = b''
    if s.startswith(b'{'):
        prefix = b'{'
        s = s[1:].lstrip()
    elif s.startswith(b'('):
        prefix = b'('
        s = s[1:].lstrip()
    inner, suffix = split_off_concat_closer(s)
    return prefix, inner, suffix


def find_comma_positions(code):
    """Byte offsets of `,` outside `{}` / `[]` / `()`."""
    pos = []
    brace = bracket = paren = 0
    i = 0
    while i < len(code):
        c = code[i:i + 1]
        if c == b'{':
            brace += 1
        elif c == b'}':
            brace -= 1
        elif c == b'[':
            bracket += 1
        elif c == b']':
            bracket -= 1
        elif c == b'(':
            paren += 1
        elif c == b')':
            paren -= 1
        elif c == b',' and brace == 0 and bracket == 0 and paren == 0:
            pos.append(i)
        i += 1
    return pos


def split_comma_fields(code):
    commas = find_comma_positions(code)
    trailing = bool(commas) and code.rstrip().endswith(b',')
    if not commas:
        return [code], False
    fields = []
    start = 0
    for p in commas:
        fields.append(code[start:p])
        start = p + 1
    last = code[start:]
    if trailing:
        if last.strip():
            fields.append(last)
    else:
        fields.append(last)
    return fields, trailing


def align_comma_codes(codes):
    """Pad comma-separated concat fields so columns line up across rows.

    Rows may have different field counts; only shared columns are aligned.
    A wrapping `{` on the first field line is kept as a one-byte prefix.
    """
    parsed = []
    for c in codes:
        prefix, inner, suffix = unwrap_concat_line(c)
        fields, trailing = split_comma_fields(inner)
        fields = [f.strip() for f in fields]
        if not fields or any(f == b'' for f in fields):
            return None
        parsed.append((prefix, fields, trailing, suffix))

    nmax = max(len(f) for _, f, _, _ in parsed)
    widths = [0] * nmax
    for _, fields, _, _ in parsed:
        for i, f in enumerate(fields):
            widths[i] = max(widths[i], len(f))

    out = []
    for prefix, fields, trailing, suffix in parsed:
        cells = []
        for i, f in enumerate(fields):
            if i == len(fields) - 1 and not trailing:
                cells.append(f)
            else:
                cells.append(f.ljust(widths[i]))
        line = prefix + b', '.join(cells)
        if trailing:
            line += b','
        if suffix:
            line = line.rstrip() + suffix
        out.append(line)
    return out


def align_pipe_codes(codes):
    """Pad `|`-separated fields so OR columns line up across rows.

    Rows may have different field counts; only shared columns are aligned.
    Continuation rows after a wrapping `(` get a leading space so names
    line up with the first row's identifier (not the parenthesis).
    """
    stripped = []
    for c in codes:
        fields, trailing = split_or_fields(c)
        fields = [f.strip() for f in fields]
        if not fields or any(f == b'' for f in fields):
            return None
        stripped.append((fields, trailing))
    nmax = max(len(f) for f, _ in stripped)
    if nmax < 2:
        return None

    any_paren = any(fields[0].startswith(b'(') for fields, _ in stripped)
    widths = [0] * nmax
    inners = []
    prefixes = []
    suffixes = []
    for fields, _tr in stripped:
        row_pref = []
        row_inner = []
        row_suf = []
        for col, f in enumerate(fields):
            suf = b''
            if col == len(fields) - 1:
                tm = re.match(rb'^(.*?)(\)\s*;|;|,)\s*$', f)
                if tm and tm.group(1).strip():
                    f, suf = tm.group(1).rstrip(), tm.group(2)
            if col == 0 and any_paren:
                if f.startswith(b'('):
                    pref, inner = b'(', f[1:]
                else:
                    pref, inner = b' ', f
            else:
                pref, inner = b'', f
            row_pref.append(pref)
            row_inner.append(inner)
            row_suf.append(suf)
            widths[col] = max(widths[col], len(inner))
        prefixes.append(row_pref)
        inners.append(row_inner)
        suffixes.append(row_suf)

    out = []
    for (_fields, trailing), pref, inner, suf in zip(stripped, prefixes, inners, suffixes):
        n = len(inner)
        cells = [pref[c] + inner[c].ljust(widths[c]) + suf[c] for c in range(n)]
        line = b' | '.join(cells)
        if trailing:
            line += b' |'
        out.append(line)
    return out


def rewrite_always(run, out):
    recs = [rec for _, rec in run]
    name_w = max(len(r['name']) for r in recs)
    for idx, rec in run:
        rhs_col = len(rec['indent']) + name_w + 1 + len(rec['op']) + 1
        sep = b' ' + rec['op'] + (b' ' + rec['rhs'] if rec['rhs'] else b'')
        out[idx] = rec['indent'] + rec['name'].ljust(name_w) + sep + rec['tail'] + rec['cr']
        if rec['multi']:
            rewrite_continuations(rec, rhs_col, out)


def first_candidate(code):
    """First column-operator candidate outside bit-range brackets.

    Returns (position, byte) or None. Skips operators inside '[' ']' (e.g.
    the ':' of a range) and two-character operators like '&&', '||' and '**'.
    """
    cand = b'&|?:^+-*/'
    depth = 0
    i = 0
    while i < len(code):
        c = code[i:i + 1]
        if c == b'[':
            depth += 1
        elif c == b']':
            depth -= 1
        elif depth == 0 and c in cand:
            nxt = code[i + 1:i + 2]
            if (c == b'&' and nxt == b'&') or \
               (c == b'|' and nxt == b'|') or \
               (c == b'*' and nxt == b'*'):
                i += 2
                continue
            return i, c
        i += 1
    return None


def rewrite_ports(run, out):
    recs = [rec for _, rec in run]
    max_dir = max(len(r['direction']) for r in recs)
    max_type = max(len(r['type']) for r in recs)
    max_range = max(len(r['range']) for r in recs)
    name_w = max(len(r['name']) for r in recs)
    for idx, rec in run:
        unpacked = rec.get('unpacked', b'')
        name_part = rec['name'].ljust(name_w) + unpacked if unpacked else rec['name']
        out[idx] = (rec['indent'] + rec['direction'].ljust(max_dir) + b' ' +
                    rec['type'].ljust(max_type) + b' ' +
                    rec['range'].ljust(max_range) + b' ' + name_part +
                    rec['tail'] + rec['cr'])


def find_always_ranges(code_parts):
    n = len(code_parts)
    ranges = []
    i = 0
    while i < n:
        if re.match(rb'always\b', code_parts[i]):
            depth = 0
            seen = False
            j = i
            while j < n:
                b = len(BEGIN_RE.findall(code_parts[j]))
                e = len(END_RE.findall(code_parts[j]))
                depth += b - e
                if b:
                    seen = True
                if seen and depth <= 0:
                    break
                j += 1
            if not seen:
                j = i
            ranges.append((i, j))
            i = j + 1
        else:
            i += 1
    return ranges


def find_inst_ranges(code_parts):
    n = len(code_parts)
    ranges = []
    i = 0
    while i < n:
        m = re.match(rb'^[A-Za-z_][A-Za-z0-9_$]*'
                     rb'(\s+[A-Za-z_][A-Za-z0-9_$]*)?\s*(#\s*)?\(',
                     code_parts[i])
        if m:
            first = re.match(rb'[A-Za-z_][A-Za-z0-9_$]*',
                             code_parts[i]).group()
            if first not in EXCLUDED_FIRST:
                j = i
                while j < n:
                    if code_parts[j].rstrip().endswith(b');'):
                        break
                    j += 1
                ranges.append((i, j))
                i = j + 1
                continue
        i += 1
    return ranges


def process(data):
    lines = data.split(b'\n')
    n = len(lines)
    out = list(lines)

    in_block = False
    code_parts = [b''] * n
    for i, line in enumerate(lines):
        body = line[:-1] if line.endswith(b'\r') else line
        if in_block:
            if b'*/' in body:
                in_block = False
            continue
        if b'/*' in body or b'*/' in body:
            if b'/*' in body and b'*/' not in body:
                in_block = True
            continue
        if b'"' in body:
            continue
        code_parts[i] = code_part_of(body)

    always_ranges = find_always_ranges(code_parts)
    in_always_region = [False] * n
    for rs, re_ in always_ranges:
        for k in range(rs, min(re_ + 1, n)):
            in_always_region[k] = True

    kinds = [None] * n
    recs = [None] * n
    in_block = False
    for i, line in enumerate(lines):
        body = line[:-1] if line.endswith(b'\r') else line
        cr = b'\r' if line.endswith(b'\r') else b''
        if in_block:
            if b'*/' in body:
                in_block = False
            kinds[i] = 'blockcomment'
            continue
        if b'/*' in body or b'*/' in body:
            if b'/*' in body and b'*/' not in body:
                in_block = True
            kinds[i] = 'blockcomment'
            continue
        kind, rec = analyze(body, cr, in_always_region[i])
        kinds[i] = kind
        recs[i] = rec

    i = 0
    while i < n:
        kind = kinds[i]
        if kind in ('decl', 'assign', 'param'):
            j = i
            run = []
            while j < n:
                k = kinds[j]
                if k in ('decl', 'assign', 'param'):
                    rec = recs[j]
                    run.append((j, rec))
                    j += 1
                    if rec['multi']:
                        while j < n:
                            line = lines[j]
                            body = line[:-1] if line.endswith(b'\r') else line
                            cr = b'\r' if line.endswith(b'\r') else b''
                            st = body.lstrip(b' \t')
                            if not st:
                                rec['cont'].append((j, b'', cr))
                                j += 1
                                continue
                            code, _ = split_comment(st)
                            rec['cont'].append((j, st, cr))
                            j += 1
                            if code.rstrip().endswith(b';'):
                                break
                elif k in ('blank', 'comment'):
                    j += 1
                else:
                    break
            rewrite_decl_assign(run, out)
            i = j
        elif kind == 'port':
            j = i
            run = []
            while j < n:
                k = kinds[j]
                if k == 'port':
                    run.append((j, recs[j]))
                    j += 1
                elif k in ('comment', 'blank'):
                    j += 1
                else:
                    break
            rewrite_ports(run, out)
            i = j
        else:
            i += 1

    for rs, re_ in always_ranges:
        j = rs
        run = []
        while j <= re_:
            if kinds[j] == 'always_assign':
                rec = recs[j]
                run.append((j, rec))
                j += 1
                if rec['multi']:
                    while j <= re_:
                        line = lines[j]
                        body = line[:-1] if line.endswith(b'\r') else line
                        cr = b'\r' if line.endswith(b'\r') else b''
                        st = body.lstrip(b' \t')
                        if not st:
                            rec['cont'].append((j, b'', cr))
                            j += 1
                            continue
                        code, _ = split_comment(st)
                        rec['cont'].append((j, st, cr))
                        j += 1
                        if code.rstrip().endswith(b';'):
                            break
            else:
                j += 1
        rewrite_always(run, out)

    for rs, re_ in find_inst_ranges(code_parts):
        conns = []
        for j in range(rs, re_ + 1):
            line = lines[j]
            body = line[:-1] if line.endswith(b'\r') else line
            cr = b'\r' if line.endswith(b'\r') else b''
            st = body.lstrip(b' \t')
            if not st or st.startswith(b'//'):
                continue
            code, comment = split_comment(st)
            if not code.startswith(b'.'):
                continue
            pc = parse_conn(code)
            if pc is None:
                continue
            conns.append((j, body, cr, pc, comment))
        if len(conns) < 2:
            continue
        max_name = max(len(pc['name']) for _, _, _, pc, _ in conns)
        max_signal = max(len(pc['signal']) for _, _, _, pc, _ in conns)
        for j, body, cr, pc, comment in conns:
            indent = body[:len(body) - len(body.lstrip(b' \t'))]
            out[j] = (indent + pc['name'].ljust(max_name) + b' ' + b'(' +
                      pc['signal'].ljust(max_signal) + b' ' + b')' +
                      pc['tail'] + comment + cr)

    return b'\n'.join(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry_run = '--dry-run' in sys.argv[1:]
    patterns = args or ['IP/myCPU/*.v']
    files = sorted({fn for pat in patterns for fn in glob.glob(pat)})
    if not files:
        print('no files matched:', patterns)
        return 1

    total = 0
    for fn in files:
        with open(fn, 'rb') as f:
            data = f.read()
        new = process(data)
        if new == data:
            continue
        old_lines = data.split(b'\n')
        new_lines = new.split(b'\n')
        changed = sum(1 for a, b in zip(old_lines, new_lines) if a != b)
        total += changed
        if dry_run:
            print(f'{fn}: {changed} lines would change')
        else:
            with open(fn, 'wb') as f:
                f.write(new)
            print(f'{fn}: {changed} lines changed')
    print(f'total changed lines: {total}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

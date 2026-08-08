#!/usr/bin/env python3
"""Whitespace-only Verilog alignment for IP/myCPU style RTL.

Rules (all changes are spaces only; comments, strings, identifiers and line
endings are preserved byte-for-byte):
  1. Consecutive wire/reg/integer/genvar declarations, single/multi-line
     assign statements and parameter/localparam lines form one block, grouped
     within banner-comment delimited sections (----/***/=== comments split).
     Type column, range column and signal-name column are aligned using the
     longest member; for statements with '=' the operator is aligned too.
  2. Continuation lines of a multi-line statement are re-indented so they line
     up with the RHS column (the text after '=').
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
    python3 mytool/align_verilog.py 'IP/myCPU/*.v' 'chip/soc_demo/nscscc-team/*.v'

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
            eq = code.find(b'=', mm.end())
            if eq >= 0:
                semi = code.rstrip().rfind(b';')
                if semi > eq:
                    return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                    'name': name, 'range': range_, 'has_eq': True,
                                    'rhs': code[eq + 1:semi].strip(),
                                    'tail': code[semi:] + comment,
                                    'multi': False, 'cont': [], 'cr': cr}
                return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                'name': name, 'range': range_, 'has_eq': True,
                                'rhs': code[eq + 1:].lstrip().rstrip(),
                                'tail': comment, 'multi': True, 'cont': [], 'cr': cr}
            if b';' in code:
                return 'decl', {'kind': 'decl', 'kw': kw, 'indent': indent,
                                'name': name, 'range': range_, 'has_eq': False,
                                'rhs': b'', 'tail': code[mm.end():] + comment,
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
            return 'port', {'kind': 'port', 'indent': indent, 'direction': kw,
                            'type': type_, 'range': range_, 'name': mm.group(),
                            'tail': code[mm.end():] + comment, 'cr': cr}
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
        if rec['has_eq']:
            sep = b' = ' if rec['rhs'] else b' ='
            out[idx] = (rec['indent'] + field + rec['name'].ljust(name_w) + sep +
                        rec['rhs'] + rec['tail'] + rec['cr'])
            if rec['multi']:
                for ci, rest, ccr in rec['cont']:
                    out[ci] = (b' ' * rhs_col + rest + ccr) if rest else (rest + ccr)
        else:
            out[idx] = rec['indent'] + field + rec['name'] + rec['tail'] + rec['cr']


def align_multiline_table(rec):
    """Align a repeated operator column inside a multi-line statement.

    If every body line (RHS of the first line plus all continuation lines)
    has the same first single-char operator (e.g. '&'), pad the prefix so
    those operators line up; then re-align a trailing '|' column so the
    line-end ORs stay aligned as well.
    """
    bodies = [(rec['rhs'], rec['tail'])]
    for _ci, st, _ccr in rec['cont']:
        code, comment = split_comment(st)
        bodies.append((code, comment))
    if any(not code.strip() for code, _ in bodies):
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


def rewrite_always(run, out):
    recs = [rec for _, rec in run]
    name_w = max(len(r['name']) for r in recs)
    for idx, rec in run:
        rhs_col = len(rec['indent']) + name_w + 1 + len(rec['op']) + 1
        sep = b' ' + rec['op'] + (b' ' + rec['rhs'] if rec['rhs'] else b'')
        out[idx] = rec['indent'] + rec['name'].ljust(name_w) + sep + rec['tail'] + rec['cr']
        if rec['multi']:
            for ci, rest, ccr in rec['cont']:
                out[ci] = (b' ' * rhs_col + rest + ccr) if rest else (rest + ccr)


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
    for idx, rec in run:
        out[idx] = (rec['indent'] + rec['direction'].ljust(max_dir) + b' ' +
                    rec['type'].ljust(max_type) + b' ' +
                    rec['range'].ljust(max_range) + b' ' + rec['name'] +
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

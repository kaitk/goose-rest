"""Compare the default write_error generated C, assembly, and object bytes.

Usage: python3 tasks/056-aegon-ideas/problem-c.py build/problem-details/c-check
The task file records how to build the inputs.
"""

import difflib
import hashlib
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit('usage: problem-c.py CHECK_DIRECTORY')
here = Path(sys.argv[1])


def c_function(label):
    log = (here / (label + '-build.log')).read_text()
    path = Path(re.search(r'^wrote (.+) \(\d+ bytes\)$', log, re.M)[1])
    text = path.read_text()
    match = re.search(r'^static void rest_write_error[^\n]*\{', text, re.M)
    end = text.index('\n}\n', match.start()) + 2
    code = text[match.start():end]
    aliases = 0
    for m in reversed(list(re.finditer(r'^    rest_NoState_g\d+ \* (st_g_\d+) = st_g;\n', code, re.M))):
        if len(re.findall(r'\b' + m[1] + r'\b', code)) == 1:
            code = code[:m.start()] + code[m.end():]
            aliases += 1
    code, scopes = re.subn(
        r'^    \{\n(        t\d+\.data = [^\n]*http_JSON[^\n]+\n        fields_g = t\d+;\n)    \}\n',
        lambda m: ''.join(line[4:] for line in m[1].splitlines(True)), code, flags=re.M)
    declarations = []
    def declaration(m):
        declarations.append(m[0].strip())
        return ''
    code = re.sub(r'^    \w+(?: \*)? \w+;\n', declaration, code, flags=re.M)
    names = {}
    def rename(m):
        if m[0] not in names:
            names[m[0]] = m[1] + str(sum(v.startswith(m[1]) for v in names.values()))
        return names[m[0]]
    code = re.sub(r'\b(t|L)\d+\b', rename, code)
    declarations = [re.sub(r'\b(t|L)\d+\b', lambda m: names[m[0]], d) for d in declarations]
    normalized = '\n'.join(sorted(declarations)) + '\n' + code
    print(label, 'unused aliases:', aliases, 'constant-header scopes:', scopes)
    return normalized


before, after = c_function('origin'), c_function('current')
print('normalized C identical:', before == after)
print(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True)))[:6000])
assert before == after
print('normalized C SHA-256:', hashlib.sha256(before.encode()).hexdigest())

assembly = []
for label in ('origin', 'current'):
    text = (here / (label + '.s')).read_text()
    start = re.search(r'^_rest_write_error_g4:.*$', text, re.M).start()
    assembly.append(text[start:text.index('\t.cfi_endproc', start)])
print('optimized assembly identical:', assembly[0] == assembly[1])
assert assembly[0] == assembly[1]
print('assembly SHA-256:', hashlib.sha256(assembly[0].encode()).hexdigest())

words = []
for label in ('origin', 'current'):
    text = (here / (label + '-object.txt')).read_text()
    opcodes = re.findall(r'^\s*[0-9a-f]+:\s+([0-9a-f]{8})\s', text, re.M)
    assert opcodes, 'no arm64 instructions found'
    words.append(b''.join(bytes.fromhex(word)[::-1] for word in opcodes))
print('object machine code identical:', words[0] == words[1])
assert words[0] == words[1]
print('machine-code bytes:', len(words[0]))
print('machine-code SHA-256:', hashlib.sha256(words[0]).hexdigest())

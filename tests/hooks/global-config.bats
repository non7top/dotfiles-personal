#!/usr/bin/env bats
# The global pre-commit config (_git/.pre-commit-config.yaml): the fix-unicode-dashes settings,
# exercised with the real texthooks fixer installed in the test image.

load helpers

GLOBAL_CONFIG=${GLOBAL_CONFIG:-$REPO/_git/.pre-commit-config.yaml}

setup() {
    common_setup
}

# config_py <python code>: runs it with the parsed config bound to `cfg`
config_py() {
    python3 -c "
import sys, yaml
cfg = yaml.safe_load(open('$GLOBAL_CONFIG'))
$1"
}

dash_args() {
    config_py "
for repo in cfg['repos']:
    for hook in repo['hooks']:
        if hook['id'] == 'fix-unicode-dashes':
            print(*hook.get('args', []), sep='\n')"
}

@test "fix-unicode-dashes: em dash, en dash, minus and every other dash become one hyphen" {
    mapfile -t args < <(dash_args)
    python3 - "$T/in.txt" <<'EOF'
import sys
cps = "2010 2011 FE63 2012 2013 2212 02D7 2796 FF0D 2014 FE58".split()
open(sys.argv[1], "w", encoding="utf-8").write("".join(f"a{chr(int(c, 16))}b\n" for c in cps))
EOF
    run fix-unicode-dashes "${args[@]}" "$T/in.txt"
    assert_failure
    assert_equal "$(sort -u "$T/in.txt")" "a-b"
    assert_equal "$(wc -l < "$T/in.txt")" 11
}

@test "fix-unicode-dashes: plain ASCII text, including a double hyphen, is left alone" {
    mapfile -t args < <(dash_args)
    printf 'a - b -- c --flag\n' > "$T/in.txt"
    run fix-unicode-dashes "${args[@]}" "$T/in.txt"
    assert_success
    assert_equal "$(cat "$T/in.txt")" 'a - b -- c --flag'
}

@test "fix-unicode-dashes: the configured codepoints cover every dash texthooks handles by default" {
    mapfile -t args < <(dash_args)
    run python3 - "${args[@]}" <<'EOF'
import sys
from texthooks import fix_unicode_dashes as d
opts = dict(a.split("=", 1) for a in sys.argv[1:])
single = set(opts["--single-hyphen-codepoints"].split(","))
double = set(filter(None, opts["--double-hyphen-codepoints"].split(",")))
known = set(d.DEFAULT_SINGLE_HYPHEN_CODEPOINTS) | set(d.DEFAULT_DOUBLE_HYPHEN_CODEPOINTS)
print("missing:", sorted(known - single), "double:", sorted(double))
sys.exit(0 if single == known and not double else 1)
EOF
    assert_success
}

@test "texthooks rev in the config matches the version installed in the test image" {
    config_py "
rev = next(r['rev'] for r in cfg['repos'] if r['repo'].endswith('/texthooks'))
from importlib.metadata import version
assert version('texthooks') == rev, (version('texthooks'), rev)"
}

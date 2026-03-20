# varlint

A static analysis tool for Bash that enforces **variable discipline** and **function purity contracts**.

varlint is opinionated: it doesn't just warn about risky patterns — it enforces architectural constraints. Inside a function, every variable must be explicitly declared `local`. Every side effect must be intentional.

---

## Install

```bash
mush install
```

---

## Usage

```bash
varlint check <file>...
varlint check --strict lib/*.sh
varlint check --enforce-pure script.sh
varlint check --fail-on GLOBAL_WRITE,DYNAMIC_EVAL script.sh
```

### Options

| Flag | Description |
|------|-------------|
| `--strict` | `GLOBAL_READ` and `SIDE_EFFECT_BUILTIN` become errors |
| `--enforce-pure` | All functions treated as `@pure` |
| `--fail-on <rules>` | Exit 1 if specific rules fire (comma-separated) |
| `--no-color` | Disable colored output |

---

## Rules

| Code | Name | Severity | Description |
|------|------|----------|-------------|
| `VL01` | `GLOBAL_WRITE` | error | Assignment to a variable not declared `local` |
| `VL02` | `GLOBAL_READ` | warning | Reading a variable not in local scope |
| `VL03` | `DYNAMIC_EVAL` | error | `eval` prevents static analysis |
| `VL04` | `INDIRECT_EXPANSION` | error | `${!var}` is not statically resolvable |
| `VL05` | `DYNAMIC_SOURCE` | error | `source "$file"` with a variable path |
| `VL06` | `SIDE_EFFECT_BUILTIN` | warning | `cd`, `export`, `read` modify external state |

---

## Output

```
VL01 GLOBAL_WRITE
error: variable 'x' assigned without local declaration in 'foo'
 --> script.sh:12
 hint: add 'local x' before the assignment, or annotate with @allow GLOBAL_WRITE

VL02 GLOBAL_READ
warning: variable '$name' read from global scope in 'foo'
 --> script.sh:14
 hint: pass as argument or declare 'local name', or annotate with @allow GLOBAL_READ
```

---

## Local declarations are never a smell

`local nome=valore` is a valid and encouraged pattern. varlint registers the variable as local-scoped and never flags it:

```bash
init() {
  local count=0       # OK
  local name="world"  # OK
  local -r max=100    # OK
  local a=1 b=2 c=3  # OK — multiple assignments
}
```

---

## Annotations

### `@pure` — enforce full purity

```bash
# @pure
add() {
  local a="$1"
  local b="$2"
  echo $((a + b))
}
```

Inside a `@pure` function, `GLOBAL_READ` and `SIDE_EFFECT_BUILTIN` become errors.

### `@allow` — allow specific rules

```bash
# @allow GLOBAL_READ,DYNAMIC_EVAL
legacy_fn() {
  eval "$cmd"
  echo "$GLOBAL"
}
```

### `@impure` — suppress all violations

```bash
# @impure(reason="wraps legacy shell code")
compat_fn() {
  eval "$cmd"
  cd /tmp
}
```

---

## Ignore mechanisms

### Disable a single line

```bash
RESULT=42  # varlint disable-line=GLOBAL_WRITE
```

### Disable a block

```bash
# varlint disable=GLOBAL_WRITE,DYNAMIC_EVAL
legacy_block() {
  x=1
  eval "$cmd"
}
# varlint enable
```

---

## Strict mode

```bash
varlint check --strict script.sh
```

Promotes warnings to errors:
- `VL02 GLOBAL_READ` → error
- `VL06 SIDE_EFFECT_BUILTIN` → error

---

## Limitations

varlint is a lightweight line-by-line parser, not a full Bash AST. Known limitations:

- Single-line functions (`foo() { :; }`) are not analyzed
- Brace counting can be confused by `{` inside strings or heredocs
- `eval` content is never analyzed
- Bash dynamic scoping means some false positives are possible

Use `# @impure` or `# varlint disable` to acknowledge these cases explicitly.

---

## Running tests

```bash
bash tests/test_rules.sh
```

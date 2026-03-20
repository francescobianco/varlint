# VARLINT — Design Document

## 1. Vision

**varlint** is a static analysis tool for Bash focused on enforcing *variable discipline* and *function purity contracts*.

Unlike traditional linters, varlint is **opinionated**: it does not just warn about risky patterns, but enforces architectural constraints such as:

* No implicit global variable usage
* Explicit declaration of local scope
* Detection of dynamic or non-analyzable constructs
* Optional enforcement of pure functions

---

## 2. Core Philosophy

### 2.1 From Linting to Contracts

varlint introduces the concept of **function contracts**:

* Functions should explicitly declare their behavior
* Side effects must be visible and intentional
* Hidden dependencies are treated as violations

Instead of:

> “this might be risky”

varlint says:

> “this violates the declared contract”

---

### 2.2 Default Rule

> Any construct that prevents reliable static analysis is considered a warning or error unless explicitly allowed.

---

## 3. Analysis Model

### 3.1 Scope Tracking

For each function:

* Build a **local scope set**
* Track:

    * `local` declarations
    * function parameters (`$1`, `$2`, `$@`, `$*`)

Example:

```bash
foo() {
  local a b
  local c=10
}
```

Local scope = `{a, b, c}`

---

### 3.2 Assignment Detection

Pattern:

```bash
x=10
```

Rule:

* If `x` is not declared `local` → **GLOBAL_WRITE**

---

### 3.3 Variable Read Detection

Patterns:

```bash
$x
${x}
```

Rule:

* If variable is:

    * not local
    * not a parameter
    * not explicitly allowed

→ **GLOBAL_READ**

---

### 3.4 Tokenization Strategy

varlint uses a **lightweight parser**, not a full Bash AST.

It detects:

* Function boundaries
* `local` declarations
* Assignments
* Variable expansions

This enables high performance and reasonable accuracy for most scripts.

---

## 4. Rule System

Each rule has:

* Code (e.g., `VL01`)
* Name
* Severity (`error`, `warning`)
* Description
* Suggested fix

---

### 4.1 Rule Categories

#### GLOBAL_WRITE

```bash
x=10
```

* Description: assignment to non-local variable
* Severity: error
* Fix: add `local x`

---

#### GLOBAL_READ

```bash
echo "$x"
```

* Description: implicit dependency on global variable
* Severity: warning (or error in strict mode)
* Fix: pass as argument or declare local

---

#### DYNAMIC_EVAL

```bash
eval "$cmd"
```

* Description: dynamic execution prevents static analysis
* Severity: error

---

#### INDIRECT_EXPANSION

```bash
${!var}
```

* Description: indirect variable reference
* Severity: error

---

#### DYNAMIC_SOURCE

```bash
source "$file"
```

* Description: runtime inclusion of unknown code
* Severity: error

---

#### SIDE_EFFECT_BUILTIN

Examples:

```bash
cd /tmp
export X=1
read x
```

* Description: modifies environment or external state
* Severity: warning

---

## 5. Ignore Mechanism

varlint requires **explicit acknowledgment** of unsafe constructs.

---

### 5.1 Inline Ignore

```bash
# varlint disable=GLOBAL_WRITE
x=10
```

Or:

```bash
x=10  # varlint disable-line=GLOBAL_WRITE
```

---

### 5.2 Block Ignore

```bash
# varlint disable=GLOBAL_READ,DYNAMIC_EVAL
foo() {
  eval "$cmd"
  echo "$x"
}
# varlint enable
```

---

### 5.3 Function-Level Annotations

#### Pure function

```bash
# @pure
sum() {
  local a="$1"
  local b="$2"
  echo $((a + b))
}
```

Constraints:

* No GLOBAL_WRITE
* No GLOBAL_READ
* No dynamic constructs
* No side-effect builtins

---

#### Allowed exceptions

```bash
# @allow GLOBAL_READ,DYNAMIC_EVAL
foo() {
  eval "$cmd"
}
```

---

#### Impure declaration

```bash
# @impure(reason="uses globals and eval")
foo() {
  eval "$cmd"
}
```

---

## 6. Strict Modes

### 6.1 Default Mode

* GLOBAL_WRITE → error
* GLOBAL_READ → warning

---

### 6.2 Strict Mode

```bash
varlint check --strict
```

* GLOBAL_READ → error
* SIDE_EFFECT_BUILTIN → error

---

### 6.3 Pure Enforcement Mode

```bash
varlint check --enforce-pure
```

* All functions treated as `@pure`

---

### 6.4 Rule Filtering

```bash
varlint check --fail-on=GLOBAL_WRITE,DYNAMIC_EVAL
```

---

## 7. Output Format

Example:

```
VL01 GLOBAL_WRITE
error: variable 'x' assigned without local declaration
hint: add 'local x' or annotate with @allow GLOBAL_WRITE

VL02 GLOBAL_READ
warning: variable 'c' used but not defined in local scope
hint: pass as argument or declare local
```

---

## 8. Limitations

varlint is not a full Bash interpreter.

Known limitations:

* `eval` cannot be analyzed
* indirect expansion is not statically resolvable
* dynamic `source` breaks analysis
* Bash uses dynamic scoping

Design choice:

> These cases are explicitly flagged instead of silently ignored.

---

## 9. Future Extensions

* Full AST parser integration (optional)
* IDE integration
* autofix suggestions
* purity scoring
* CI integration

---

## 10. Summary

varlint transforms Bash from a loosely scoped scripting language into a **disciplined, analyzable environment** by:

* enforcing explicit variable scope
* surfacing hidden dependencies
* requiring explicit acknowledgment of dynamic behavior
* introducing function-level contracts

This enables writing Bash code that is:

* more predictable
* more testable
* closer to functional programming principles

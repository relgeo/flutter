# 7. Core Closure Contracts

Status dokumen: `Normative`

Dokumen ini membekukan kontrak v0.5 yang dipakai untuk menutup capability Core
Runtime yang masih partial atau mengalami contract drift. Bab ini tidak
menambah syntax baru; ia mengikat input, output, diagnostic, edge case, dan
compatibility expectation ke kontrak yang sudah tersebar pada bab Core, Syntax,
dan Geometry.

## 7.1 Shared compatibility boundary

Semua kontrak di bab ini mengikuti aturan berikut:

1. `version` yang dihilangkan berarti compatibility line aktif `0.5`.
2. `0.4` tetap supported-legacy; `0.1`–`0.3` tetap regression-only.
3. Future/unknown version ditolak pada `parse` dengan
   `UNSUPPORTED_SPEC_VERSION`; runtime tidak boleh menebak syntax baru.
4. Perubahan v0.5 harus mempertahankan field, code, phase, path, identity, dan
   result ordering yang sudah dibekukan oleh fixture aktif. Field baru atau
   perubahan result mode memerlukan perubahan normative spec dan fixture.
5. `editor` boleh melakukan bounded recovery; `validate` dan `compile` tetap
   strict. Recovery tidak boleh menjadi bukti compile/resolve success.
6. Constraint failure dilaporkan setelah resolve tanpa geometry mutation dan
   tanpa general constraint solver. Raw SVG bytes, style, viewBox, browser UX,
   dan Flutter host behavior bukan bagian dari Core semantic contract.

## 7.2 Closure register

Setiap row memiliki acceptance anchor yang executable. Anchor consumer/host yang
belum tersedia adalah evidence follow-up, bukan alasan menghapus atau
menjadikan capability `not-applicable`.

| ID | Input | Output / success contract | Diagnostic and edge contract | Compatibility / acceptance anchor |
| --- | --- | --- | --- | --- |
| `CORE-INPUT-002` | YAML/source string atau `RelGeoDocument` envelope | Parser mengembalikan structured document; source range boleh tersedia dan bersifat zero-based half-open; semantic path tetap canonical saat range tidak tersedia | Invalid YAML → `INVALID_YAML`/`parse`; incomplete editor input → bounded diagnostic/recovery; strict parse tidak mengklaim resolved scene | v0.5 version gate/default; `parser.test.ts`, `diagnostics.test.ts`, language-service range tests |
| `CORE-MODEL-002` | Typed values, declared object IDs, references, collections, component definitions/instances | Public semantic model mempertahankan type, identity, namespace, collection identity/order, dan component-local scope; no implicit rename or scope leak | Unknown/private reference, wrong member/type, or invalid collection shape → stable code/path/object context; broad untyped input may be accepted only before typed boundary | Existing v0.5 object/type syntax; `component.test.ts`, `structured_parameters.test.ts`, `inherit_resolution.test.ts` |
| `CORE-VALID-003` | References in expressions, anchors, placements, queries, component exports, and dependency edges | Valid references resolve to declared target/export and retain document path/object context | Unknown reference/identifier/anchor/export and illegal dependency are strict failures; no implicit repair; phase is `validate` when statically knowable, otherwise `resolve` | Codes remain catalogued and paths use `objects.<id>...`; `semantic_contract_fixtures.test.ts`, reference/component negatives |
| `CORE-VALID-004` | Closed paths, holes, dimensions, offsets, repeats, boolean operations, and operation modes | Valid topology and mode combinations pass validation without semantic coercion; operation targets are checked against the v0.5 geometry compatibility boundary | Open/degenerate paths, invalid holes, non-finite/fractional counts, invalid spacing/offset/mode, or non-geometry operation targets → stable actionable code before corrupt output | v0.5 supported topology/result modes and operation target matrix; `validation_v04_spec.test.ts`, `path_holes.test.ts`, `boolean.test.ts`, repeat/split negatives, `structured_errors.test.ts` |
| `CORE-ERROR-001` | Incomplete source through `mode: editor` | Bounded placeholder/partial scene and ordered diagnostics preserve editable identity; strict modes remain unchanged | Unsupported recovery is explicit; diagnostics are not dropped; editor fallback never becomes compile success | Editor-only tolerance is v0.5 behavior; `tolerant_resolver.test.ts`, `v05-invalid-incomplete-editor` |
| `CORE-ERROR-002` | Strict parse/validate/resolve/compile request | Valid source yields resolved/compile output; invalid source fails at its originating phase | `parse` → YAML/version; `validate` → schema/type/reference; `resolve` → graph/expression/object; `runtime` → operational result; `constraint` → post-resolve violation. Strict output is absent on hard failure | Phase/code/path remain stable across CLI and Core; `validation_modes.test.ts`, `structured_errors.test.ts`, invalid/runtime fixtures |
| `CORE-RESOLVE-003` | Repeat, divide, split, boolean, collection access, and single/multi result requests | Declared identity and semantic order are preserved; repeat/divide/split collections expose stable indexed children; boolean `single` returns one shape and `multi` returns ordered collection | Empty/multipart single result and invalid collection access are explicit runtime failures; no topology auto-repair; closed uniform-t repeat excludes duplicate endpoint | v0.5 result modes and fixture statuses remain unchanged; `repeat_divide.test.ts`, `split.test.ts`, `boolean.test.ts`, fixtures 19/20/22/24 |
| `CORE-RESOLVE-005` | `ResolvedScene` from successful Core resolution | Versioned renderer-neutral projection includes schema metadata, explicit order arrays, canonical objects/values/bounds/violations/views/sheets | Non-finite numbers or invalid snapshot input fail with `INVALID_RESOLVED_SCENE`/`INVALID_SEMANTIC_SNAPSHOT`; map key sorting must not reorder semantic arrays | Schema `relgeo.resolved-scene`, version `1`, line `0.5`, 12-decimal numbers, `-0` → `0`; `projection.test.ts`, CLI/renderer comparators |
| `CORE-CONSTRAINT-002` | Resolved geometry plus declared post-resolve constraints | Violations retain resolved scene and expose constraint path, involved objects, type, severity, origin/phase, expected/actual, and declaration order | Failure is `CONSTRAINT_VIOLATION` at `constraint`; no geometry mutation, graph feedback, or general solving; degenerate relation inputs remain structured failures | Existing v0.5 violation fields and fixture 14 remain compatible; `constraints_diagnostics.test.ts`, `v05-runtime-align-violation` |
| `CORE-DIAG-001` | Any public parser/validator/resolver/runtime/constraint failure | Boundary returns `code`, `message`, `phase`, `severity`; path/object/range/dependency context is retained when known; code prefix is removed from message | Unknown internal code/text normalizes to registered code or `UNKNOWN_ERROR`; raw exception/stack does not cross boundary; source range never replaces semantic path | Stable `UPPER_SNAKE_CASE` catalog and five phases; `diagnostics.test.ts`, `structured_errors.test.ts`, fixture diagnostics |
| `CORE-DIAG-002` | Source/document plus optional `maxDiagnostics` and resolution flag | `collectDiagnostics` returns deterministic, deduplicated, bounded list; strict resolver semantics are unchanged | Sort phase → range → path → code → message; truncate after sort; parse remains parse-only; independent local faults may aggregate | v0.5 ordering and default max 100; `diagnostics.test.ts`, incomplete-editor aggregation fixture |
| `CORE-ERROR-003` | Any emitted runtime/evaluator/resolver failure | Every actionable emitted code is in the public catalog or is normalized through the documented fallback; materially different causes remain distinguishable | No raw evaluator/validator/resolver `Error` crosses public boundary; runtime codes include distinct empty/multipart/collection/path/query cases | Adding/changing a code requires this catalog, `types.ts`, normalization, and fixture/test update; structured-error tests and fixtures 13/17–22 |
| `CORE-DET-002` | Same source, compatibility line, and runtime contract | Repeated resolution/projection preserves IDs, graph order, collection order, normalized numbers, tolerance decisions, diagnostics, and paths | Any nondeterministic order or numeric/path drift is a contract failure; semantic arrays retain result order | Local replay is required; Node 24/cross-host parity is separate evidence; `projection.test.ts`, graph/repeat/diagnostic tests |
| `CORE-INT-002` | Valid, incomplete, and runtime-error source through language-service/Playground boundary | Core semantics are preserved across edit → diagnostic → resolve → preview → inspect; consumer may reformat but not redefine codes/paths | Incomplete/runtime-error source never becomes false success; browser sequencing/accessibility is consumer evidence | Uses Core v0.5 diagnostics/projection; language-service tests, worker/conformance checks, browser E2E when available |
| `CORE-INT-004` | Selected shared fixtures at TS, renderer, Markdown, and Flutter semantic boundaries | Consumers compare semantic objects, paths, diagnostics, ordering, and projection fields; raw SVG bytes excluded | Mismatch is reported at semantic field/path/order level; host unavailability is `not-verified`, not Core absence | Shared fixture manifest and projection schema v1; renderer/CLI/Markdown tests plus Flutter comparator when host is available |

## 7.3 Contract-to-source ownership

The normative ownership split is:

| Contract area | Normative source | Implementation boundary |
| --- | --- | --- |
| Document envelope, version, parser recovery | `01-overview.md`, `02-document-structure.md`, `06-error-model.md` | `core/src/parser.ts`, parser tests |
| Types, parameters, expressions, units | `syntax/07-type-system.md`, `08-parameters.md`, `12-expressions.md`, `core/03-scene.md` | `core/src/types.ts`, `evaluator.ts`, `units.ts`, validator tests |
| Evaluation order and dependency legality | `04-evaluation-order.md`, `05-semantic-guarantees.md` | `core/src/graph.ts`, resolver/evaluator tests |
| Objects, placement, collections, queries, topology | `geometry/13–20`, `geometry/21-constraints.md` | `core/src/resolver/**`, `geometry/src/**`, semantic/negative fixtures |
| Diagnostics and error taxonomy | `06-error-model.md` and this chapter | `core/src/errors.ts`, `diagnostics.ts`, `types.ts` |
| Canonical semantic projection | `05-semantic-guarantees.md` and this chapter | `core/src/projection.ts`, projection tests, consumer comparators |

An implementation or consumer must not introduce a new public field, code,
phase, result mode, or ordering rule solely in a downstream matrix. Update the
normative chapter first, then implementation and fixtures, then the capability
reconciliation.

## 7.4 Compatibility impact

This freeze is contract clarification for the existing v0.5 line. It does not
change the active version, legacy policy, syntax, result modes, projection
schema version, or diagnostic code names. The only intentional effect is to
make existing behavior testable and to require normalization where current
internal raw throws violate the public boundary. Any future breaking change
must use a new compatibility decision and version line.

[← 6. Error Model](06-error-model.md) · [↑ Core index](README.md)

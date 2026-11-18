// Builds one program per Run/Submit: the user's code plus a driver that
// calls their function once per test and prints, per test, one line
//
//     @@CODEY@@<ordinal>@@{"ok":true,"value":<json>}    or
//     @@CODEY@@<ordinal>@@{"ok":false,"error":"<message>"}
//
// Anything else on stdout is the user's own output (print debugging).
// Arguments are written as language literals (Java and C++ have no JSON
// parser), so only the types below are supported (S45).

export type Language = "swift" | "python" | "java" | "cpp";
export const LANGUAGES: Language[] = ["swift", "python", "java", "cpp"];

export type ValueType =
  | "int" | "long" | "double" | "bool" | "string"
  | "int[]" | "long[]" | "double[]" | "bool[]" | "string[]"
  | "int[][]" | "string[][]";
export const VALUE_TYPES: ValueType[] = [
  "int", "long", "double", "bool", "string",
  "int[]", "long[]", "double[]", "bool[]", "string[]", "int[][]", "string[][]",
];

export interface Param { name: string; type: ValueType }
export interface Signature { functionName: string; params: Param[]; returnType: ValueType }
export interface DriverTest { ordinal: number; args: unknown[] }

export const MARKER = "@@CODEY@@";
/** The line just before the user's code, so errors can be mapped back to it. */
export const USER_START = "@@CODEY-USER-CODE@@";

/** Lines before the user's code in a built program (0 for Python). */
export function userLineOffset(program: string): number {
  const at = program.indexOf(USER_START);
  return at < 0 ? 0 : program.slice(0, at).split("\n").length;
}

/** Piston file name, language and version for each language. */
export const RUNTIMES: Record<Language, { language: string; version: string; file: string }> = {
  python: { language: "python", version: "3.12.0", file: "main.py" },
  java: { language: "java", version: "15.0.2", file: "Main.java" },
  cpp: { language: "c++", version: "10.2.0", file: "main.cpp" },
  swift: { language: "swift", version: "5.3.3", file: "main.swift" },
};

export function buildProgram(language: Language, userCode: string, sig: Signature, tests: DriverTest[]): string {
  for (const t of tests) {
    if (!Array.isArray(t.args) || t.args.length !== sig.params.length) {
      throw new Error(`test ${t.ordinal}: expected ${sig.params.length} args`);
    }
    t.args.forEach((a, i) => checkValue(a, sig.params[i].type, `test ${t.ordinal} arg ${sig.params[i].name}`));
  }
  switch (language) {
    case "python": return python(userCode, sig, tests);
    case "java": return java(userCode, sig, tests);
    case "cpp": return cpp(userCode, sig, tests);
    case "swift": return swift(userCode, sig, tests);
  }
}

// ── Value checks ───────────────────────────────────────────────────────────

export function checkValue(v: unknown, type: ValueType, where: string): void {
  const fail = () => { throw new Error(`${where}: not a valid ${type}`); };
  if (type.endsWith("[]")) {
    if (!Array.isArray(v)) fail();
    (v as unknown[]).forEach((x, i) => checkValue(x, type.slice(0, -2) as ValueType, `${where}[${i}]`));
    return;
  }
  switch (type) {
    case "int": if (!Number.isInteger(v) || (v as number) < -2147483648 || (v as number) > 2147483647) fail(); break;
    case "long": if (!Number.isSafeInteger(v)) fail(); break;
    case "double": if (typeof v !== "number" || !Number.isFinite(v)) fail(); break;
    case "bool": if (typeof v !== "boolean") fail(); break;
    // Control characters other than \n \r \t have no literal that is safe
    // in all four languages; tests don't need them.
    case "string": if (typeof v !== "string" || /[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(v)) fail(); break;
  }
}

const base = (t: ValueType) => t.replace(/\[\]/g, "") as "int" | "long" | "double" | "bool" | "string";
const depth = (t: ValueType) => (t.match(/\[\]/g) ?? []).length;

// ── Python ─────────────────────────────────────────────────────────────────

function python(code: string, sig: Signature, tests: DriverTest[]): string {
  const data = JSON.stringify(tests.map((t) => [t.ordinal, t.args]));
  const name = sig.functionName;
  return `${code}

# ── Codey test driver ──
import json as _cj, sys as _cs, io as _cio, contextlib as _cctx
def _codey_fn():
    if "Solution" in globals() and hasattr(globals()["Solution"], ${JSON.stringify(name)}):
        return getattr(globals()["Solution"](), ${JSON.stringify(name)})
    return globals()[${JSON.stringify(name)}]
_codey_f = _codey_fn()
for _codey_n, _codey_args in _cj.loads(${JSON.stringify(data)}):
    _codey_buf = _cio.StringIO()
    try:
        with _cctx.redirect_stdout(_codey_buf):
            _codey_r = _codey_f(*_codey_args)
        _codey_out = {"ok": True, "value": _codey_r}
    except BaseException as _codey_e:
        if isinstance(_codey_e, (KeyboardInterrupt, SystemExit)):
            raise
        _codey_out = {"ok": False, "error": type(_codey_e).__name__ + ": " + str(_codey_e)}
    _cs.stdout.write(_codey_buf.getvalue())
    try:
        _codey_line = _cj.dumps(_codey_out)
    except (TypeError, ValueError):
        _codey_line = _cj.dumps({"ok": False, "error": "Return value is not a " + ${JSON.stringify(sig.returnType)}})
    print(${JSON.stringify(MARKER)} + str(_codey_n) + "@@" + _codey_line, flush=True)
`;
}

// ── Java ───────────────────────────────────────────────────────────────────

const javaScalar: Record<string, string> = { int: "int", long: "long", double: "double", bool: "boolean", string: "String" };
export const javaType = (t: ValueType) => javaScalar[base(t)] + "[]".repeat(depth(t));

function javaLiteral(v: unknown, t: ValueType): string {
  if (depth(t) > 0) {
    const inner = t.slice(0, -2) as ValueType;
    return `new ${javaType(t)}{${(v as unknown[]).map((x) => javaInner(x, inner)).join(", ")}}`;
  }
  return javaScalarLiteral(v, t);
}
// Inside an array initializer nested arrays may be written as {…}.
function javaInner(v: unknown, t: ValueType): string {
  return depth(t) > 0 ? `{${(v as unknown[]).map((x) => javaInner(x, t.slice(0, -2) as ValueType)).join(", ")}}` : javaScalarLiteral(v, t);
}
function javaScalarLiteral(v: unknown, t: ValueType): string {
  switch (base(t)) {
    case "int": return String(v);
    case "long": return `${v}L`;
    case "double": return doubleLiteral(v as number);
    case "bool": return String(v);
    case "string": return cLikeString(v as string);
  }
}

function java(code: string, sig: Signature, tests: DriverTest[]): string {
  const imports: string[] = [];
  const body = code.split("\n").map((line) => {
    if (/^\s*import\s+[\w.*]+\s*;\s*$/.test(line)) { imports.push(line.trim()); return "" ; }
    return line;
  }).join("\n")
    // Only Main may be public in Main.java.
    .replace(/\bpublic\s+(final\s+)?class\s+Solution\b/, "class Solution");
  const calls = tests.map((t) => {
    const args = t.args.map((a, i) => javaLiteral(a, sig.params[i].type)).join(", ");
    return `        __run(${t.ordinal}, () -> __j(new Solution().${sig.functionName}(${args})));`;
  }).join("\n");
  return `import java.util.*;
import java.io.*;
${imports.join("\n")}

public class Main {
    interface __Call { String call() throws Throwable; }
    static final PrintStream __out = System.out;
    static void __run(int n, __Call c) {
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        System.setOut(new PrintStream(buf, true));
        String line;
        try {
            line = "{\\"ok\\":true,\\"value\\":" + c.call() + "}";
        } catch (Throwable e) {
            line = "{\\"ok\\":false,\\"error\\":" + __q(e.getClass().getSimpleName() + (e.getMessage() == null ? "" : ": " + e.getMessage())) + "}";
        }
        System.setOut(__out);
        __out.print(buf.toString());
        __out.println("${MARKER}" + n + "@@" + line);
        __out.flush();
    }
    static String __q(String s) {
        if (s == null) return "null";
        StringBuilder b = new StringBuilder("\\"");
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"': b.append("\\\\\\""); break;
                case '\\\\': b.append("\\\\\\\\"); break;
                case '\\n': b.append("\\\\n"); break;
                case '\\r': b.append("\\\\r"); break;
                case '\\t': b.append("\\\\t"); break;
                default: if (c < 0x20) b.append(String.format("\\\\u%04x", (int) c)); else b.append(c);
            }
        }
        return b.append('"').toString();
    }
    static String __d(double d) { return Double.isFinite(d) ? Double.toString(d) : "null"; }
    static String __j(int v) { return Integer.toString(v); }
    static String __j(long v) { return Long.toString(v); }
    static String __j(double v) { return __d(v); }
    static String __j(boolean v) { return v ? "true" : "false"; }
    static String __j(String v) { return __q(v); }
    static String __j(int[] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (int x : a) s.add(__j(x)); return s.toString(); }
    static String __j(long[] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (long x : a) s.add(__j(x)); return s.toString(); }
    static String __j(double[] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (double x : a) s.add(__j(x)); return s.toString(); }
    static String __j(boolean[] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (boolean x : a) s.add(__j(x)); return s.toString(); }
    static String __j(String[] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (String x : a) s.add(__j(x)); return s.toString(); }
    static String __j(int[][] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (int[] x : a) s.add(__j(x)); return s.toString(); }
    static String __j(String[][] a) { if (a == null) return "null"; StringJoiner s = new StringJoiner(",", "[", "]"); for (String[] x : a) s.add(__j(x)); return s.toString(); }

    public static void main(String[] args) {
${calls}
    }
}

// ${USER_START}
${body}
`;
}

// ── C++ ────────────────────────────────────────────────────────────────────

const cppScalar: Record<string, string> = { int: "int", long: "long long", double: "double", bool: "bool", string: "string" };
export function cppType(t: ValueType): string {
  let s = cppScalar[base(t)];
  for (let i = 0; i < depth(t); i++) s = `vector<${s}>`;
  return s;
}
function cppLiteral(v: unknown, t: ValueType): string {
  if (depth(t) > 0) {
    const inner = t.slice(0, -2) as ValueType;
    return `${cppType(t)}{${(v as unknown[]).map((x) => cppLiteral(x, inner)).join(", ")}}`;
  }
  switch (base(t)) {
    case "int": return String(v);
    case "long": return `${v}LL`;
    case "double": return doubleLiteral(v as number);
    case "bool": return String(v);
    case "string": return `string(${cLikeString(v as string)})`;
  }
}

function cpp(code: string, sig: Signature, tests: DriverTest[]): string {
  const calls = tests.map((t) => {
    const decls = t.args.map((a, i) => `${cppType(sig.params[i].type)} __a${i} = ${cppLiteral(a, sig.params[i].type)};`).join(" ");
    const args = t.args.map((_, i) => `__a${i}`).join(", ");
    return `    { ${decls} __run(${t.ordinal}, [&]() { Solution __s; return __j(__s.${sig.functionName}(${args})); }); }`;
  }).join("\n");
  return `#include <bits/stdc++.h>
using namespace std;
// ${USER_START}
${code}

// ── Codey test driver ──
static string __q(const string& s) {
    string b = "\\"";
    for (unsigned char c : s) {
        switch (c) {
            case '"': b += "\\\\\\""; break;
            case '\\\\': b += "\\\\\\\\"; break;
            case '\\n': b += "\\\\n"; break;
            case '\\r': b += "\\\\r"; break;
            case '\\t': b += "\\\\t"; break;
            default:
                if (c < 0x20) { char u[8]; snprintf(u, sizeof u, "\\\\u%04x", c); b += u; }
                else b += (char)c;
        }
    }
    return b + "\\"";
}
static string __j(int v) { return to_string(v); }
static string __j(long long v) { return to_string(v); }
static string __j(long v) { return to_string(v); }
static string __j(double v) { if (!isfinite(v)) return "null"; ostringstream o; o << setprecision(17) << v; return o.str(); }
static string __j(bool v) { return v ? "true" : "false"; }
static string __j(const string& v) { return __q(v); }
template <typename T> static string __j(const vector<T>& v) {
    string s = "[";
    for (size_t i = 0; i < v.size(); i++) { if (i) s += ","; s += __j(static_cast<T>(v[i])); }
    return s + "]";
}
template <typename F> static void __run(int n, F f) {
    string line;
    try { line = "{\\"ok\\":true,\\"value\\":" + f() + "}"; }
    catch (const exception& e) { line = "{\\"ok\\":false,\\"error\\":" + __q(string("exception: ") + e.what()) + "}"; }
    catch (...) { line = "{\\"ok\\":false,\\"error\\":\\"exception\\"}"; }
    cout << "${MARKER}" << n << "@@" << line << endl;
}

int main() {
${calls}
    return 0;
}
`;
}

// ── Swift ──────────────────────────────────────────────────────────────────

const swiftScalar: Record<string, string> = { int: "Int", long: "Int", double: "Double", bool: "Bool", string: "String" };
export function swiftType(t: ValueType): string {
  let s = swiftScalar[base(t)];
  for (let i = 0; i < depth(t); i++) s = `[${s}]`;
  return s;
}
function swiftLiteral(v: unknown, t: ValueType): string {
  if (depth(t) > 0) {
    const inner = t.slice(0, -2) as ValueType;
    return `[${(v as unknown[]).map((x) => swiftLiteral(x, inner)).join(", ")}]`;
  }
  switch (base(t)) {
    case "int": case "long": return String(v);
    case "double": return doubleLiteral(v as number);
    case "bool": return String(v);
    case "string": return swiftString(v as string);
  }
}
function swiftString(s: string): string {
  let out = '"';
  for (const ch of s) {
    const c = ch.codePointAt(0)!;
    if (ch === '"') out += '\\"';
    else if (ch === "\\") out += "\\\\";
    else if (ch === "\n") out += "\\n";
    else if (ch === "\r") out += "\\r";
    else if (ch === "\t") out += "\\t";
    else if (c < 0x20) out += `\\u{${c.toString(16)}}`;
    else out += ch;
  }
  return out + '"';
}

function swift(code: string, sig: Signature, tests: DriverTest[]): string {
  const hasSolution = /\b(class|struct)\s+Solution\b/.test(code);
  const callee = hasSolution ? `Solution().${sig.functionName}` : sig.functionName;
  const calls = tests.map((t) => {
    const decls = t.args.map((a, i) => `let __a${i}: ${swiftType(sig.params[i].type)} = ${swiftLiteral(a, sig.params[i].type)}`).join("; ");
    const args = t.args.map((_, i) => `__a${i}`).join(", ");
    return `do { ${decls}; __codeyEmit(${t.ordinal}, __codeyJSON(${callee}(${args}))) }`;
  }).join("\n");
  return `import Foundation
// ${USER_START}
${code}

// ── Codey test driver ──
protocol __CodeyJSON { var __codeyJSON: String { get } }
extension Int: __CodeyJSON { var __codeyJSON: String { String(self) } }
extension Double: __CodeyJSON { var __codeyJSON: String { isFinite ? "\\(self)" : "null" } }
extension Bool: __CodeyJSON { var __codeyJSON: String { self ? "true" : "false" } }
extension String: __CodeyJSON {
    var __codeyJSON: String {
        var s = "\\""
        for u in unicodeScalars {
            switch u {
            case "\\"": s += "\\\\\\""
            case "\\\\": s += "\\\\\\\\"
            case "\\n": s += "\\\\n"
            case "\\r": s += "\\\\r"
            case "\\t": s += "\\\\t"
            default:
                if u.value < 0x20 { s += String(format: "\\\\u%04x", u.value) } else { s.unicodeScalars.append(u) }
            }
        }
        return s + "\\""
    }
}
extension Array: __CodeyJSON where Element: __CodeyJSON {
    var __codeyJSON: String { "[" + map { $0.__codeyJSON }.joined(separator: ",") + "]" }
}
func __codeyJSON<T: __CodeyJSON>(_ v: T) -> String { v.__codeyJSON }
func __codeyEmit(_ n: Int, _ json: String) {
    print("${MARKER}\\(n)@@{\\"ok\\":true,\\"value\\":\\(json)}")
    fflush(stdout)
}

${calls}
`;
}

// ── Shared ─────────────────────────────────────────────────────────────────

function doubleLiteral(n: number): string {
  const s = String(n);
  return /[.eE]/.test(s) ? s : `${s}.0`;
}

/** A Java / C++ string literal (UTF-8 passes through as is). */
function cLikeString(s: string): string {
  let out = '"';
  for (const ch of s) {
    if (ch === '"') out += '\\"';
    else if (ch === "\\") out += "\\\\";
    else if (ch === "\n") out += "\\n";
    else if (ch === "\r") out += "\\r";
    else if (ch === "\t") out += "\\t";
    else out += ch;
  }
  return out + '"';
}

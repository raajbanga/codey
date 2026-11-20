// Turns Piston's reply into the verdict the app shows (FR-70, FR-71).

import { MARKER } from "./drivers.ts";

export type Comparator = "exact" | "unordered" | "float";
export type Status = "accepted" | "wrong_answer" | "compile_error" | "runtime_error" | "time_limit";
export type TestStatus = "passed" | "failed" | "error" | "not_run";

export interface JudgeTest {
  ordinal: number;
  hidden: boolean;
  expected: unknown;
  /** "nums = [2,7], target = 9": shown for example tests only. */
  input: string;
}

export interface TestResult {
  ordinal: number;
  hidden: boolean;
  status: TestStatus;
  input?: string;
  expected?: unknown;
  actual?: unknown;
  error?: string;
}

export interface Verdict {
  status: Status;
  passedCount: number;
  total: number;
  tests: TestResult[];
  stdout: string;
  stderr: string;
  compileOutput: string;
}

export interface PistonStage { stdout?: string; stderr?: string; output?: string; code?: number | null; signal?: string | null }
export interface PistonReply { compile?: PistonStage; run?: PistonStage; message?: string }

const LIMIT = 8000;
const clip = (s: string) => (s.length > LIMIT ? s.slice(0, LIMIT) + "\n… (output cut)" : s);

export function judge(reply: PistonReply, tests: JudgeTest[], comparator: Comparator): Verdict {
  const compile = reply.compile;
  if (compile && compile.code !== 0 && compile.code != null) {
    return {
      status: "compile_error", passedCount: 0, total: tests.length,
      tests: tests.map((t) => shown(t, { ordinal: t.ordinal, hidden: t.hidden, status: "not_run" })),
      stdout: "", stderr: "", compileOutput: clip(cleanPaths(compile.stderr || compile.output || "")),
    };
  }

  const run = reply.run ?? {};
  const results = new Map<number, { ok: boolean; value?: unknown; error?: string }>();
  const userOut: string[] = [];
  for (const line of (run.stdout ?? "").split("\n")) {
    const at = line.indexOf(MARKER);
    if (at < 0) { userOut.push(line); continue; }
    if (at > 0) userOut.push(line.slice(0, at));
    const m = /^(\d+)@@(.*)$/.exec(line.slice(at + MARKER.length));
    if (!m) continue;
    try { results.set(Number(m[1]), JSON.parse(m[2])); } catch { /* a garbled line counts as not run */ }
  }

  const out: TestResult[] = tests.map((t) => {
    const r = results.get(t.ordinal);
    if (!r) return shown(t, { ordinal: t.ordinal, hidden: t.hidden, status: "not_run" });
    if (!r.ok) return shown(t, { ordinal: t.ordinal, hidden: t.hidden, status: "error", error: r.error }, true);
    const passed = matches(r.value, t.expected, comparator);
    return shown(t, { ordinal: t.ordinal, hidden: t.hidden, status: passed ? "passed" : "failed", actual: r.value });
  });

  const passedCount = out.filter((r) => r.status === "passed").length;
  const killed = run.signal === "SIGKILL" || run.signal === "SIGXCPU";
  let status: Status;
  if (passedCount === tests.length) status = "accepted";
  else if (out.some((r) => r.status === "error")) status = "runtime_error";
  else if (out.some((r) => r.status === "not_run")) status = killed ? "time_limit" : "runtime_error";
  else status = "wrong_answer";

  // Interpreted languages report syntax errors at run time: show them like
  // a compile error when nothing ran at all.
  const stderr = cleanPaths(run.stderr ?? "");
  const nothingRan = results.size === 0 && !killed;
  // Java (source mode) and Python report compile/syntax errors at run time.
  if (nothingRan && run.code !== 0 && stderr.trim() !== "") status = "compile_error";
  return {
    status, passedCount, total: tests.length, tests: out,
    stdout: clip(trimEnd(userOut.join("\n"))),
    stderr: nothingRan ? "" : clip(stderr),
    compileOutput: nothingRan ? clip(stderr || reply.message || "") : "",
  };
}

/** Hidden tests never carry their input, expected, or actual value. */
function shown(t: JudgeTest, r: TestResult, keepError = false): TestResult {
  if (t.hidden) return { ordinal: r.ordinal, hidden: true, status: r.status, ...(keepError && r.error ? { error: r.error } : {}) };
  return { ...r, input: t.input, expected: t.expected };
}

export function matches(actual: unknown, expected: unknown, comparator: Comparator): boolean {
  switch (comparator) {
    case "exact": return deepEqual(actual, expected, false);
    case "float": return deepEqual(actual, expected, true);
    case "unordered": {
      if (!Array.isArray(actual) || !Array.isArray(expected) || actual.length !== expected.length) return false;
      const key = (x: unknown) => JSON.stringify(canonical(x));
      const a = actual.map(key).sort();
      const e = expected.map(key).sort();
      return a.every((x, i) => x === e[i]);
    }
  }
}

function deepEqual(a: unknown, b: unknown, tolerant: boolean): boolean {
  if (typeof a === "number" && typeof b === "number") {
    if (!tolerant) return a === b;
    return Math.abs(a - b) <= 1e-6 * Math.max(1, Math.abs(b));
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    return a.length === b.length && a.every((x, i) => deepEqual(x, b[i], tolerant));
  }
  return a === b;
}

/** Sorts nested arrays too, so [[1,2],[3]] matches [[3],[2,1]] under unordered. */
function canonical(x: unknown): unknown {
  if (!Array.isArray(x)) return x;
  return x.map(canonical).sort((p, q) => (JSON.stringify(p) < JSON.stringify(q) ? -1 : 1));
}

function trimEnd(s: string) { return s.replace(/\s+$/, ""); }

const FILES: [RegExp, string][] = [
  [/\bmain\.cpp(?:\.cpp)?/g, "solution.cpp"], [/\bMain\.java(?:\.java)?/g, "Solution.java"],
  [/\bmain\.swift\b/g, "solution.swift"], [/\bmain\.py\b/g, "solution.py"],
];

/** Points compiler and runtime messages at the user's own lines and file. */
export function remapLines(text: string, offset: number): string {
  let out = text;
  if (offset > 0) {
    out = out
      .replace(/\b(main\.cpp(?:\.cpp)?|Main\.java(?:\.java)?|main\.swift):(\d+)/g, (_, f, n) => `${f}:${Math.max(1, Number(n) - offset)}`)
      .replace(/(\s)(\d+)( \| )/g, (_, a, n, b) => `${a}${Number(n) - offset > 0 ? Number(n) - offset : n}${b}`);
  }
  for (const [re, name] of FILES) out = out.replace(re, name);
  return out;
}
function cleanPaths(s: string) { return s.replace(/\/piston\/jobs\/[0-9a-f-]+\//g, ""); }

/** "nums = [2,7,11,15], target = 9" */
export function describeInput(names: string[], args: unknown[]): string {
  return names.map((n, i) => `${n} = ${JSON.stringify(args[i])}`).join(", ");
}

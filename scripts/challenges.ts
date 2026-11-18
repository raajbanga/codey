// Coding challenge authoring (S45). One folder per challenge in
// supabase/content/challenges/<id>/: challenge.json + solution.{py,swift,java,cpp}
// (+ optional starter.* to override the generated starter).
//
//   deno run -A scripts/challenges.ts check      schema only (no network)
//   deno run -A scripts/challenges.ts validate   + every solution passes every test
//                                                  and every starter compiles, on the
//                                                  real runner (needs RUNNER_URL, RUNNER_KEY)
//   deno run -A scripts/challenges.ts sql        upsert SQL → stdout (supabase/challenges-seed.sql)
//   deno run -A scripts/challenges.ts bundle     writes codey/Resources/challenges.json
//                                                  (examples only, the app's offline fallback)
//
// Reference solutions never leave the repo: not in the SQL, not in the bundle.

import { buildProgram, checkValue, cppType, javaType, type Language, LANGUAGES, RUNTIMES, type Signature, swiftType, VALUE_TYPES, type ValueType } from "../supabase/functions/run-challenge/drivers.ts";
import { type Comparator, describeInput, judge, type JudgeTest, type PistonReply } from "../supabase/functions/run-challenge/judge.ts";

const ROOT = new URL("..", import.meta.url).pathname;
const DIR = `${ROOT}supabase/content/challenges`;
const EXT: Record<Language, string> = { python: "py", swift: "swift", java: "java", cpp: "cpp" };
const TOPICS = ["topic-algorithms", "topic-data-structures"];

interface Test { args: unknown[]; expected: unknown; example?: boolean; explanation?: string }
interface Challenge {
  id: string; topicId: string; title: string; difficulty: "easy" | "medium" | "hard";
  statement: string; constraints: string[]; hints: string[];
  function: { name: string; params: { name: string; type: ValueType }[]; returns: ValueType };
  comparator: Comparator; editorial: string; tests: Test[];
}
interface Loaded { c: Challenge; sort: number; starters: Record<Language, string>; solutions: Record<Language, string> }

async function load(): Promise<Loaded[]> {
  const names: string[] = [];
  for await (const e of Deno.readDir(DIR)) if (e.isDirectory) names.push(e.name);
  names.sort();
  const out: Loaded[] = [];
  const order: string[] = JSON.parse(await Deno.readTextFile(`${DIR}/order.json`));
  for (const name of names) {
    const c: Challenge = JSON.parse(await Deno.readTextFile(`${DIR}/${name}/challenge.json`));
    const solutions = {} as Record<Language, string>;
    const starters = {} as Record<Language, string>;
    for (const l of LANGUAGES) {
      solutions[l] = await Deno.readTextFile(`${DIR}/${name}/solution.${EXT[l]}`);
      starters[l] = await Deno.readTextFile(`${DIR}/${name}/starter.${EXT[l]}`).catch(() => starter(l, c));
    }
    const sort = order.indexOf(c.id);
    out.push({ c, sort: sort < 0 ? 999 : sort, starters, solutions });
  }
  return out.sort((a, b) => a.sort - b.sort);
}

function check(all: Loaded[]): string[] {
  const errors: string[] = [];
  const seen = new Set<string>();
  for (const { c } of all) {
    const e = (m: string) => errors.push(`${c.id}: ${m}`);
    if (!/^ch-[a-z0-9-]{1,96}$/.test(c.id)) e("id must be ch-<kebab>");
    if (seen.has(c.id)) e("duplicate id"); seen.add(c.id);
    if (!TOPICS.includes(c.topicId)) e(`topicId must be one of ${TOPICS}`);
    if (!["easy", "medium", "hard"].includes(c.difficulty)) e("bad difficulty");
    if (!c.title || c.title.length > 100) e("title 1–100 chars");
    if (!c.statement) e("statement required");
    if (!Array.isArray(c.hints) || c.hints.length !== 2) e("exactly 2 hints");
    if (!["exact", "unordered", "float"].includes(c.comparator)) e("bad comparator");
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(c.function?.name ?? "")) e("bad function name");
    if (!VALUE_TYPES.includes(c.function?.returns)) e("bad return type");
    for (const p of c.function?.params ?? []) if (!VALUE_TYPES.includes(p.type)) e(`bad param type ${p.type}`);
    const examples = c.tests.filter((t) => t.example).length;
    const hidden = c.tests.length - examples;
    if (examples < 2) e("needs at least 2 example tests");
    if (hidden < 5) e("needs at least 5 hidden tests");
    c.tests.forEach((t, i) => {
      try {
        if (t.args.length !== c.function.params.length) throw new Error(`test ${i + 1}: wrong arg count`);
        t.args.forEach((a, j) => checkValue(a, c.function.params[j].type, `test ${i + 1} ${c.function.params[j].name}`));
        checkValue(t.expected, c.function.returns, `test ${i + 1} expected`);
      } catch (err) { e(String((err as Error).message)); }
    });
  }
  return errors;
}

// ── Generated starters ──

const defaults: Record<string, Record<Language, string>> = {
  int: { python: "0", swift: "0", java: "0", cpp: "0" },
  long: { python: "0", swift: "0", java: "0L", cpp: "0" },
  double: { python: "0.0", swift: "0.0", java: "0.0", cpp: "0.0" },
  bool: { python: "False", swift: "false", java: "false", cpp: "false" },
  string: { python: '""', swift: '""', java: '""', cpp: '""' },
};
const pyType = (t: ValueType): string => {
  const b = ({ int: "int", long: "int", double: "float", bool: "bool", string: "str" } as Record<string, string>)[t.replace(/\[\]/g, "")];
  let s = b; for (let i = 0; i < (t.match(/\[\]/g) ?? []).length; i++) s = `List[${s}]`;
  return s;
};
const isArray = (t: ValueType) => t.endsWith("[]");

function starter(l: Language, c: Challenge): string {
  const f = c.function;
  const ret = f.returns;
  const todo = (indent: string, comment: string) => `${indent}${comment} Write your solution here.`;
  switch (l) {
    case "python": {
      const params = f.params.map((p) => `${p.name}: ${pyType(p.type)}`).join(", ");
      return `from typing import List\n\n\ndef ${f.name}(${params}) -> ${pyType(ret)}:\n${todo("    ", "#")}\n    return ${isArray(ret) ? "[]" : defaults[ret].python}\n`;
    }
    case "swift": {
      const params = f.params.map((p) => `_ ${p.name}: ${swiftType(p.type)}`).join(", ");
      return `func ${f.name}(${params}) -> ${swiftType(ret)} {\n${todo("    ", "//")}\n    return ${isArray(ret) ? "[]" : defaults[ret].swift}\n}\n`;
    }
    case "java": {
      const params = f.params.map((p) => `${javaType(p.type)} ${p.name}`).join(", ");
      const value = isArray(ret) ? `new ${javaType(ret).replace(/\[\]/, "[0]")}` : defaults[ret].java;
      return `import java.util.*;\n\nclass Solution {\n    public ${javaType(ret)} ${f.name}(${params}) {\n${todo("        ", "//")}\n        return ${value};\n    }\n}\n`;
    }
    case "cpp": {
      const params = f.params.map((p) => `${cppType(p.type)}${isArray(p.type) || p.type === "string" ? "&" : ""} ${p.name}`).join(", ");
      return `class Solution {\npublic:\n    ${cppType(ret)} ${f.name}(${params}) {\n${todo("        ", "//")}\n        return ${isArray(ret) ? "{}" : defaults[ret].cpp};\n    }\n};\n`;
    }
  }
}

// ── Runner ──

async function runOnRunner(l: Language, code: string, c: Challenge, tests: Test[]) {
  const url = Deno.env.get("RUNNER_URL"), key = Deno.env.get("RUNNER_KEY");
  if (!url || !key) throw new Error("RUNNER_URL and RUNNER_KEY must be set");
  const sig: Signature = { functionName: c.function.name, params: c.function.params, returnType: c.function.returns };
  const program = buildProgram(l, code, sig, tests.map((t, i) => ({ ordinal: i + 1, args: t.args })));
  const rt = RUNTIMES[l];
  const res = await fetch(`${url}/api/v2/execute`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Runner-Key": key },
    body: JSON.stringify({ language: rt.language, version: rt.version, files: [{ name: rt.file, content: program }], run_timeout: 5000, compile_timeout: 20000 }),
  });
  if (!res.ok) throw new Error(`runner HTTP ${res.status}`);
  const reply: PistonReply = await res.json();
  const jt: JudgeTest[] = tests.map((t, i) => ({ ordinal: i + 1, hidden: false, expected: t.expected, input: describeInput(c.function.params.map((p) => p.name), t.args) }));
  return judge(reply, jt, c.comparator);
}

async function pool<T>(items: (() => Promise<T>)[], size: number): Promise<T[]> {
  const out: T[] = []; let i = 0;
  await Promise.all(Array.from({ length: size }, async () => { while (i < items.length) { const k = i++; out[k] = await items[k](); } }));
  return out;
}

// ── SQL ──

const q = (s: string) => `'${s.replaceAll("'", "''")}'`;
const qj = (v: unknown) => `${q(JSON.stringify(v))}::jsonb`;
const qa = (a: string[]) => `array[${a.map(q).join(", ")}]::text[]`;

function sql(all: Loaded[]): string {
  const lines = [
    "-- Generated by scripts/challenges.ts sql. Do not edit; edit supabase/content/challenges/ instead.",
    "-- Upserts by id; tests of these challenges are replaced. Safe to re-run.",
    "begin;",
  ];
  for (const { c, sort, starters } of all) {
    lines.push(`insert into public.content_challenges (id, topic_id, title, difficulty, statement, constraints, hints, function_name, params, return_type, comparator, editorial, sort_index) values (${[
      q(c.id), q(c.topicId), q(c.title), q(c.difficulty), q(c.statement), qa(c.constraints), qj(c.hints),
      q(c.function.name), qj(c.function.params), q(c.function.returns), q(c.comparator), q(c.editorial), String(sort),
    ].join(", ")}) on conflict (id) do update set topic_id = excluded.topic_id, title = excluded.title, difficulty = excluded.difficulty, statement = excluded.statement, constraints = excluded.constraints, hints = excluded.hints, function_name = excluded.function_name, params = excluded.params, return_type = excluded.return_type, comparator = excluded.comparator, editorial = excluded.editorial, sort_index = excluded.sort_index;`);
    for (const l of LANGUAGES) {
      lines.push(`insert into public.content_challenge_starters (challenge_id, language, code) values (${q(c.id)}, ${q(l)}, ${q(starters[l])}) on conflict (challenge_id, language) do update set code = excluded.code;`);
    }
    lines.push(`delete from public.content_challenge_tests where challenge_id = ${q(c.id)};`);
    c.tests.forEach((t, i) => {
      lines.push(`insert into public.content_challenge_tests (id, challenge_id, ordinal, args, expected, is_example, explanation) values (${q(`${c.id}-${i + 1}`)}, ${q(c.id)}, ${i + 1}, ${qj(t.args)}, ${qj(t.expected)}, ${t.example ? "true" : "false"}, ${t.explanation ? q(t.explanation) : "null"});`);
    });
  }
  lines.push("commit;");
  return lines.join("\n") + "\n";
}

// ── Bundle (the app's format; examples only) ──

function bundle(all: Loaded[]) {
  return {
    schemaVersion: 1,
    challenges: all.map(({ c, starters }) => ({
      id: c.id, topicId: c.topicId, title: c.title, difficulty: c.difficulty,
      statement: c.statement, constraints: c.constraints, hints: c.hints,
      functionName: c.function.name, params: c.function.params, returnType: c.function.returns,
      comparator: c.comparator, editorial: c.editorial,
      starters: Object.fromEntries(LANGUAGES.map((l) => [l, starters[l]])),
      examples: c.tests.filter((t) => t.example).map((t) => ({
        input: describeInput(c.function.params.map((p) => p.name), t.args),
        output: JSON.stringify(t.expected),
        explanation: t.explanation ?? null,
      })),
    })),
  };
}

// ── Main ──

const cmd = Deno.args[0];
const all = await load();
const errors = check(all);
if (errors.length) { console.error(errors.join("\n")); Deno.exit(1); }

if (cmd === "check") {
  console.log(`${all.length} challenges OK`);
} else if (cmd === "validate") {
  const only = Deno.args[1];
  const jobs: (() => Promise<string | null>)[] = [];
  for (const { c, solutions, starters } of all.filter((x) => !only || x.c.id === only)) {
    for (const l of LANGUAGES) {
      jobs.push(async () => {
        const v = await runOnRunner(l, solutions[l], c, c.tests);
        if (v.status !== "accepted") {
          const bad = v.tests.filter((t) => t.status !== "passed").slice(0, 2).map((t) => `#${t.ordinal} ${t.status} got ${JSON.stringify(t.actual)} want ${JSON.stringify(t.expected)} ${t.error ?? ""}`);
          return `✗ ${c.id} ${l} solution: ${v.status} ${v.passedCount}/${v.total} ${bad.join("; ")} ${v.compileOutput.slice(0, 400)} ${v.stderr.slice(0, 300)}`;
        }
        const s = await runOnRunner(l, starters[l], c, c.tests.filter((t) => t.example));
        if (s.status === "compile_error") return `✗ ${c.id} ${l} starter does not compile: ${s.compileOutput.slice(0, 400)}`;
        console.log(`✓ ${c.id} ${l}`);
        return null;
      });
    }
  }
  const failures = (await pool(jobs, 3)).filter((x): x is string => x !== null);
  if (failures.length) { console.error(failures.join("\n")); Deno.exit(1); }
  console.log(`All ${jobs.length} solution/language pairs pass; every starter compiles.`);
} else if (cmd === "sql") {
  console.log(sql(all));
} else if (cmd === "bundle") {
  await Deno.writeTextFile(`${ROOT}codey/Resources/challenges.json`, JSON.stringify(bundle(all), null, 2) + "\n");
  console.log(`Wrote ${all.length} challenges to codey/Resources/challenges.json`);
} else {
  console.error("usage: deno run -A scripts/challenges.ts check|validate [id]|sql|bundle");
  Deno.exit(2);
}

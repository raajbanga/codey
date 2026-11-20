// deno test supabase/functions/run-challenge/
import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { buildProgram, checkValue, MARKER } from "./drivers.ts";
import { judge, type JudgeTest, matches } from "./judge.ts";

const ex = (ordinal: number, expected: unknown, hidden = false): JudgeTest => ({ ordinal, hidden, expected, input: hidden ? "" : `x = ${ordinal}` });
const line = (n: number, body: unknown) => `${MARKER}${n}@@${JSON.stringify(body)}`;

Deno.test("all tests pass → accepted, user output kept apart", () => {
  const v = judge({ run: { stdout: `debug 1\n${line(1, { ok: true, value: 3 })}\nhi${line(2, { ok: true, value: 4 })}\n`, code: 0 } },
    [ex(1, 3), ex(2, 4)], "exact");
  assertEquals(v.status, "accepted");
  assertEquals(v.passedCount, 2);
  assertEquals(v.stdout, "debug 1\nhi");
});

Deno.test("a wrong value → wrong_answer with actual shown for examples", () => {
  const v = judge({ run: { stdout: line(1, { ok: true, value: 5 }), code: 0 } }, [ex(1, 3)], "exact");
  assertEquals(v.status, "wrong_answer");
  assertEquals(v.tests[0], { ordinal: 1, hidden: false, status: "failed", actual: 5, input: "x = 1", expected: 3 });
});

Deno.test("hidden tests never carry input, expected, or actual", () => {
  const v = judge({ run: { stdout: line(1, { ok: true, value: 5 }), code: 0 } }, [ex(1, 3, true)], "exact");
  assertEquals(v.tests[0], { ordinal: 1, hidden: true, status: "failed" });
});

Deno.test("compile error → every test not run, compiler output shown without job paths", () => {
  const v = judge({ compile: { code: 1, stderr: "/piston/jobs/ab12-cd/main.cpp:3: error: x" }, run: {} }, [ex(1, 1)], "exact");
  assertEquals(v.status, "compile_error");
  assertEquals(v.compileOutput, "main.cpp:3: error: x");
  assertEquals(v.tests[0].status, "not_run");
});

Deno.test("killed with tests missing → time_limit", () => {
  const v = judge({ run: { stdout: line(1, { ok: true, value: 1 }), signal: "SIGKILL" } }, [ex(1, 1), ex(2, 2)], "exact");
  assertEquals(v.status, "time_limit");
  assertEquals(v.tests[1].status, "not_run");
});

Deno.test("an exception in one test → runtime_error with its message", () => {
  const v = judge({ run: { stdout: line(1, { ok: false, error: "IndexError: list index out of range" }), code: 0 } }, [ex(1, 1)], "exact");
  assertEquals(v.status, "runtime_error");
  assertEquals(v.tests[0].error, "IndexError: list index out of range");
});

Deno.test("a Python syntax error (nothing ran) is a compile error", () => {
  const v = judge({ run: { stdout: "", stderr: "SyntaxError: invalid syntax", code: 1 } }, [ex(1, 1)], "exact");
  assertEquals(v.status, "compile_error");
  assertEquals(v.compileOutput, "SyntaxError: invalid syntax");
});

Deno.test("comparators", () => {
  assertEquals(matches([0, 1], [1, 0], "unordered"), true);
  assertEquals(matches([0, 1], [1, 0], "exact"), false);
  assertEquals(matches([["tan", "nat"], ["bat"]], [["bat"], ["nat", "tan"]], "unordered"), true);
  assertEquals(matches([["a"]], [["a"], ["a"]], "unordered"), false);
  assertEquals(matches(0.1 + 0.2, 0.3, "float"), true);
  assertEquals(matches(0.1 + 0.2, 0.3, "exact"), false);
  assertEquals(matches(true, true, "exact"), true);
});

Deno.test("value checks reject wrong types and out-of-range ints", () => {
  checkValue([[1, 2], [3]], "int[][]", "x");
  assertThrows(() => checkValue(2147483648, "int", "x"));
  assertThrows(() => checkValue(1.5, "int", "x"));
  assertThrows(() => checkValue(["a", 1], "string[]", "x"));
  assertThrows(() => checkValue("a\u0001", "string", "x"));
});

Deno.test("drivers write literals for each language", () => {
  const sig = { functionName: "f", params: [{ name: "a", type: "int[][]" as const }, { name: "s", type: "string" as const }], returnType: "int" as const };
  const tests = [{ ordinal: 1, args: [[[1, 2], []], "q\"\\\n"] }];
  const java = buildProgram("java", "class Solution { int f(int[][] a, String s) { return 0; } }", sig, tests);
  assertEquals(java.includes(`new int[][]{{1, 2}, {}}, "q\\"\\\\\\n"`), true);
  const cpp = buildProgram("cpp", "", sig, tests);
  assertEquals(cpp.includes(`vector<vector<int>> __a0 = vector<vector<int>>{vector<int>{1, 2}, vector<int>{}};`), true);
  const swift = buildProgram("swift", "func f(_ a: [[Int]], _ s: String) -> Int { 0 }", sig, tests);
  assertEquals(swift.includes(`let __a0: [[Int]] = [[1, 2], []]`), true);
  assertEquals(java.indexOf("public class Main") < java.indexOf("class Solution"), true, "Main must be the first class (single-file java)");
  assertThrows(() => buildProgram("python", "", sig, [{ ordinal: 1, args: [[[1]]] }]));
});

Deno.test("compile errors point at the user's own line and file", async () => {
  const { remapLines } = await import("./judge.ts");
  const { userLineOffset } = await import("./drivers.ts");
  const sig = { functionName: "f", params: [{ name: "a", type: "int" as const }], returnType: "int" as const };
  const program = buildProgram("cpp", "class Solution {\npublic:\n    int f(int a) { return a }\n};", sig, [{ ordinal: 1, args: [1] }]);
  const offset = userLineOffset(program);
  assertEquals(program.split("\n")[offset + 2], "    int f(int a) { return a }");
  assertEquals(remapLines(`main.cpp.cpp:${offset + 3}:30: error: expected ';'`, offset), "solution.cpp:3:30: error: expected ';'");
  const java = buildProgram("java", "import java.util.*;\nclass Solution {\n  int f(int a) { return a }\n}", sig, [{ ordinal: 1, args: [1] }]);
  const jo = userLineOffset(java);
  assertEquals(java.split("\n")[jo + 2], "  int f(int a) { return a }");
  assertEquals(remapLines(`Main.java.java:${jo + 3}: error: ';' expected`, jo), "Solution.java:3: error: ';' expected");
});

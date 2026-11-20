// run-challenge (S45): runs a user's code for a coding challenge on the
// Codey runner (runner/SETUP.md) and returns a verdict (FR-70, FR-71).
//
//   POST { challengeId, language, code, mode: "run" | "submit" }
//   run    → the example tests, with inputs, expected and actual values
//   submit → every test; hidden tests report pass/fail only
//
// The runner URL and key are function secrets (RUNNER_URL, RUNNER_KEY): the
// app never sees them (NFR-33). Rate limits per user, or per IP for guests
// (NFR-34). Hidden tests are read with the service role; RLS hides them
// from the app.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { buildProgram, userLineOffset, type Language, LANGUAGES, RUNTIMES, type Signature, VALUE_TYPES, type ValueType } from "./drivers.ts";
import { type Comparator, describeInput, judge, type JudgeTest, type PistonReply, remapLines } from "./judge.ts";

const LIMITS = { runPerMinute: 20, submitPerMinute: 6, perDay: 300 };
const MAX_CODE_BYTES = 64 * 1024;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", ...extra } });
const fail = (status: number, code: string, message: string, extra: Record<string, string> = {}) =>
  json({ status: code, message }, status, extra);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail(405, "bad_request", "POST only");

  let body: { challengeId?: unknown; language?: unknown; code?: unknown; mode?: unknown };
  try { body = await req.json(); } catch { return fail(400, "bad_request", "Body must be JSON"); }
  const { challengeId, language, code, mode } = body;
  if (typeof challengeId !== "string" || !/^ch-[a-z0-9-]{1,96}$/.test(challengeId)) return fail(400, "bad_request", "Unknown challenge");
  if (typeof language !== "string" || !LANGUAGES.includes(language as Language)) return fail(400, "bad_request", "Unknown language");
  if (mode !== "run" && mode !== "submit") return fail(400, "bad_request", "mode must be run or submit");
  if (typeof code !== "string" || code.trim() === "") return fail(400, "bad_request", "Write some code first");
  if (new TextEncoder().encode(code).length > MAX_CODE_BYTES) return fail(413, "bad_request", "Code is over 64 KB");

  const runnerURL = Deno.env.get("RUNNER_URL");
  const runnerKey = Deno.env.get("RUNNER_KEY");
  if (!runnerURL || !runnerKey) return fail(503, "runner_down", "The code runner isn't configured");

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // ── Rate limit (NFR-34) ──
  const subject = await subjectFor(req, admin);
  const now = Date.now();
  const since = (ms: number) => new Date(now - ms).toISOString();
  const [minute, day] = await Promise.all([
    admin.from("challenge_runs").select("id", { count: "exact", head: true })
      .eq("subject", subject).eq("mode", mode).gte("created_at", since(60_000)),
    admin.from("challenge_runs").select("id", { count: "exact", head: true })
      .eq("subject", subject).gte("created_at", since(86_400_000)),
  ]);
  const perMinute = mode === "run" ? LIMITS.runPerMinute : LIMITS.submitPerMinute;
  if ((minute.count ?? 0) >= perMinute) {
    return fail(429, "rate_limited", "Too many runs. Wait a minute and try again.", { "Retry-After": "60" });
  }
  if ((day.count ?? 0) >= LIMITS.perDay) {
    return fail(429, "rate_limited", "That's today's limit of runs. Try again tomorrow.", { "Retry-After": "3600" });
  }
  await admin.from("challenge_runs").insert({ subject, mode });
  if (Math.random() < 0.02) await admin.from("challenge_runs").delete().lt("created_at", since(2 * 86_400_000));

  // ── Challenge and tests ──
  const { data: challenge } = await admin.from("content_challenges")
    .select("id, function_name, params, return_type, comparator").eq("id", challengeId).maybeSingle();
  if (!challenge) return fail(404, "bad_request", "Unknown challenge");
  let testQuery = admin.from("content_challenge_tests")
    .select("ordinal, args, expected, is_example").eq("challenge_id", challengeId).order("ordinal");
  if (mode === "run") testQuery = testQuery.eq("is_example", true);
  const { data: rows, error: testError } = await testQuery;
  if (testError || !rows || rows.length === 0) return fail(500, "runner_down", "This challenge has no tests");

  const params = (challenge.params as { name: string; type: string }[]);
  if (!params.every((p) => VALUE_TYPES.includes(p.type as ValueType))) return fail(500, "runner_down", "Bad challenge signature");
  const sig: Signature = {
    functionName: challenge.function_name,
    params: params as Signature["params"],
    returnType: challenge.return_type as ValueType,
  };

  let program: string;
  try {
    program = buildProgram(language as Language, code, sig, rows.map((r) => ({ ordinal: r.ordinal, args: r.args as unknown[] })));
  } catch (e) {
    console.error("driver", challengeId, String(e));
    return fail(500, "runner_down", "This challenge's tests are broken");
  }

  // ── Run once ──
  const runtime = RUNTIMES[language as Language];
  const started = performance.now();
  let reply: PistonReply;
  try {
    const res = await fetch(`${runnerURL}/api/v2/execute`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Runner-Key": runnerKey },
      body: JSON.stringify({
        language: runtime.language, version: runtime.version,
        files: [{ name: runtime.file, content: program }],
        run_timeout: 5000, compile_timeout: 20000,
      }),
      signal: AbortSignal.timeout(45_000),
    });
    if (!res.ok) {
      console.error("runner", res.status, (await res.text()).slice(0, 300));
      return fail(503, "runner_down", "The code runner is offline. Try again later.");
    }
    reply = await res.json();
  } catch (e) {
    console.error("runner", String(e));
    return fail(503, "runner_down", "The code runner is offline. Try again later.");
  }
  const elapsedMs = Math.round(performance.now() - started);

  const names = params.map((p) => p.name);
  const tests: JudgeTest[] = rows.map((r) => ({
    ordinal: r.ordinal,
    hidden: !r.is_example,
    expected: r.expected,
    input: r.is_example ? describeInput(names, r.args as unknown[]) : "",
  }));
  const verdict = judge(reply, tests, challenge.comparator as Comparator);
  const offset = userLineOffset(program);
  verdict.compileOutput = remapLines(verdict.compileOutput, offset);
  verdict.stderr = remapLines(verdict.stderr, offset);
  return json({ ...verdict, mode, language, elapsedMs });
});

/** "u:<user id>" for a signed-in user, else "ip:<hash>" (no raw IP stored). */
type Auth = { auth: { getUser(token: string): Promise<{ data: { user: { id: string } | null } }> } };
async function subjectFor(req: Request, admin: Auth): Promise<string> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (token) {
    const { data } = await admin.auth.getUser(token);
    if (data?.user?.id) return `u:${data.user.id}`;
  }
  const ip = (req.headers.get("x-forwarded-for") ?? "unknown").split(",")[0].trim();
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`codey-runner:${ip}`));
  return "ip:" + Array.from(new Uint8Array(digest)).slice(0, 12).map((b) => b.toString(16).padStart(2, "0")).join("");
}

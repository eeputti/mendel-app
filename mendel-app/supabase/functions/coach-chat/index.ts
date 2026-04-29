import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const openAIKey = Deno.env.get("OPENAI_API_KEY");
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const coachSystemPrompt = `
You are Kesto Coach, a calm and intelligent hybrid athlete coach.

Your job:
- Give specific, practical training advice.
- Use the Supabase-backed athlete context as the primary source of truth: today's date, recent completed workouts, this week's planned sessions, recovery signals, profile, and recent chat history.
- Client-provided training context is only supplemental context and may be incomplete.
- Sound like a real coach, not a generic wellness chatbot.

How to answer:
- Answer the user's actual question directly in the first line.
- Briefly explain why, using only the most relevant context.
- Give a practical next step with concrete training guidance when appropriate.
- If there is a meaningful risk or tradeoff, add what to watch.
- Be concise. Usually 4 short paragraphs or fewer.
- If the context is incomplete or uncertain, say what is uncertain instead of pretending.
- Use a clean structure when it helps: "Direct answer", "Why", "What to do", "What to watch".

Do not:
- Use filler, pep talk, or empty coaching phrases.
- Say "listen to your body", "recover well", or "stay consistent" unless you tie them to specific context from this athlete.
- Repeat the same point in multiple ways.
- Diagnose illness or injury.
- Invent dates, workouts, health data, or chat history that are not present in the provided context.
- Treat client-provided context as more authoritative than the Supabase-backed context.

Return JSON with a single field: reply.
`.trim();

type CoachChatRole = "user" | "assistant";

type CoachChatRequest = {
  message?: string;
  userId?: string;
  history?: Array<{
    role?: CoachChatRole;
    content?: string;
  }>;
  context?: {
    training?: Record<string, unknown>;
    profile?: Record<string, unknown>;
    onboarding?: Record<string, unknown>;
    plan?: Record<string, unknown>;
  };
  training_context?: Record<string, unknown>;
};

type CoachChatSuccessResponse = {
  reply: string;
};

type CoachChatErrorCode =
  | "method_not_allowed"
  | "invalid_json"
  | "invalid_request"
  | "server_error"
  | "upstream_error"
  | "invalid_response";

type CoachChatErrorResponse = {
  error: {
    code: CoachChatErrorCode;
    message: string;
  };
  request_id: string;
};

Deno.serve(async (request) => {
  const requestId = crypto.randomUUID();

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed", requestId, 405);
  }

  if (!openAIKey) {
    console.error(`[coach-chat][${requestId}] Missing OPENAI_API_KEY`);
    return errorResponse("server_error", "Missing OPENAI_API_KEY", requestId, 500);
  }

  if (!supabaseUrl) {
    console.error(`[coach-chat][${requestId}] Missing SUPABASE_URL`);
    return errorResponse("server_error", "Missing SUPABASE_URL", requestId, 500);
  }

  if (!supabaseServiceRoleKey) {
    console.error(`[coach-chat][${requestId}] Missing SUPABASE_SERVICE_ROLE_KEY`);
    return errorResponse("server_error", "Missing SUPABASE_SERVICE_ROLE_KEY", requestId, 500);
  }

  try {
    const body = await parseRequestBody(request);
    const message = body.message?.trim();
    const userId = body.userId?.trim();
    const history = Array.isArray(body.history) ? body.history : [];
    const context = normalizeClientContext(body);
    const trainingContext = context.training ?? {};

    if (!message) {
      return errorResponse("invalid_request", "Missing message", requestId, 400);
    }

    if (!userId) {
      return errorResponse("invalid_request", "Missing userId", requestId, 400);
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const sanitizedHistory = history
      .filter((item) =>
        (item.role === "user" || item.role === "assistant") &&
        typeof item.content === "string" &&
        item.content.trim().length > 0
      )
      .slice(-8)
      .map((item) => ({
        role: item.role as CoachChatRole,
        content: [{ type: "input_text", text: item.content!.trim() }],
      }));

    const dateContext = getDateContext();
    const serverContext = await loadUserContext({
      supabase,
      userId,
      today: dateContext.today,
      weekStart: dateContext.weekStart,
      weekEnd: dateContext.weekEnd,
      lookbackStart: dateContext.lookbackStart,
      clientTrainingContext: trainingContext,
    });

    console.log(
      `[coach-chat][${requestId}] Incoming message`,
      JSON.stringify({
        userId,
        message,
        history_count: sanitizedHistory.length,
        training_context_keys: Object.keys(trainingContext),
        completed_sessions_count: serverContext.recent_completed_sessions.length,
        planned_sessions_count: serverContext.planned_sessions_this_week.length,
        has_latest_health: serverContext.latest_health !== null,
      }),
    );

    await insertCoachMessage(
      supabase,
      userId,
      "user",
      message,
      { request_id: requestId, source: "edge_function" },
    );

    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAIKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-5.4-mini",
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: coachSystemPrompt,
              },
            ],
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
        text:
                  `Supabase source-of-truth context for this athlete:\n${JSON.stringify(serverContext, null, 2)}\n\nClient supplemental context:\n${JSON.stringify({
                    client_context: context,
                    client_history: history,
                  }, null, 2)}\n\nUse the Supabase context as the source of truth. If data is missing, say what is missing. If history is empty, still answer using the user's current message plus the Supabase context.`,
              },
            ],
          },
          ...sanitizedHistory,
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: message,
              },
            ],
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "coach_chat_reply",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                reply: { type: "string" },
              },
              required: ["reply"],
            },
          },
        },
      }),
    });

    const openAIText = await openAIResponse.text();
    console.log(`[coach-chat][${requestId}] OpenAI status ${openAIResponse.status}`);
    console.log(`[coach-chat][${requestId}] OpenAI body ${openAIText}`);

    if (!openAIResponse.ok) {
      return errorResponse(
        "upstream_error",
        `Upstream model request failed: ${openAIText}`,
        requestId,
        openAIResponse.status,
      );
    }

    const payload = JSON.parse(openAIText);
    const reply = extractReply(payload);

    if (!reply) {
      return errorResponse("invalid_response", "Missing structured output from model", requestId, 502);
    }

    await insertCoachMessage(
      supabase,
      userId,
      "assistant",
      reply,
      { request_id: requestId, source: "edge_function" },
    );

    return jsonResponse({ reply }, 200);
  } catch (error) {
    if (error instanceof SyntaxError) {
      console.error(`[coach-chat][${requestId}] Invalid JSON body`, error);
      return errorResponse("invalid_json", "Request body must be valid JSON", requestId, 400);
    }

    const message = error instanceof Error ? error.message : "Unknown error";
    console.error(`[coach-chat][${requestId}] Unhandled error`, error);
    return errorResponse("server_error", message, requestId, 500);
  }
});

function jsonResponse(body: CoachChatSuccessResponse, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

function errorResponse(
  code: CoachChatErrorCode,
  message: string,
  requestId: string,
  status: number,
) {
  const body: CoachChatErrorResponse = {
    error: { code, message },
    request_id: requestId,
  };

  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

async function parseRequestBody(request: Request): Promise<CoachChatRequest> {
  return await request.json() as CoachChatRequest;
}

function normalizeClientContext(body: CoachChatRequest) {
  return {
    training: body.context?.training ?? body.training_context ?? {},
    profile: body.context?.profile ?? {},
    onboarding: body.context?.onboarding ?? {},
    plan: body.context?.plan ?? {},
  };
}

function extractReply(payload: Record<string, unknown>): string | null {
  if (typeof payload.output_text === "string" && payload.output_text.trim().length > 0) {
    return parseReplyText(payload.output_text);
  }

  const output = Array.isArray(payload.output) ? payload.output : [];

  for (const item of output) {
    if (!item || typeof item !== "object") {
      continue;
    }

    const content = Array.isArray((item as { content?: unknown }).content)
      ? (item as { content: Array<Record<string, unknown>> }).content
      : [];

    for (const part of content) {
      if (part.type === "output_text" && typeof part.text === "string") {
        return parseReplyText(part.text);
      }

      if (part.type === "refusal" && typeof part.refusal === "string") {
        return part.refusal.trim();
      }
    }
  }

  return null;
}

function parseReplyText(text: string): string {
  const trimmed = text.trim();

  try {
    const parsed = JSON.parse(trimmed) as { reply?: unknown };
    if (typeof parsed.reply === "string" && parsed.reply.trim().length > 0) {
      return parsed.reply.trim();
    }
  } catch {
    // Structured outputs may already be flattened into plain text.
  }

  return trimmed;
}

type DateContext = {
  today: string;
  weekStart: string;
  weekEnd: string;
  lookbackStart: string;
};

type UserContext = {
  today: string;
  week_start: string;
  week_end: string;
  profile: Record<string, unknown> | null;
  latest_health: Record<string, unknown> | null;
  recent_completed_sessions: Array<Record<string, unknown>>;
  planned_sessions_this_week: Array<Record<string, unknown>>;
  recent_chat_history: Array<Record<string, unknown>>;
  client_training_context: Record<string, unknown>;
};

function getDateContext(now = new Date()): DateContext {
  const utcNow = new Date(now.toISOString());
  const today = isoDate(utcNow);
  const dayOfWeek = utcNow.getUTCDay();
  const offsetToMonday = (dayOfWeek + 6) % 7;

  const weekStartDate = addDays(startOfUtcDay(utcNow), -offsetToMonday);
  const weekEndDate = addDays(weekStartDate, 6);
  const lookbackStartDate = addDays(startOfUtcDay(utcNow), -13);

  return {
    today,
    weekStart: isoDate(weekStartDate),
    weekEnd: isoDate(weekEndDate),
    lookbackStart: isoDate(lookbackStartDate),
  };
}

async function loadUserContext({
  supabase,
  userId,
  today,
  weekStart,
  weekEnd,
  lookbackStart,
  clientTrainingContext,
}: {
  supabase: SupabaseClient;
  userId: string;
  today: string;
  weekStart: string;
  weekEnd: string;
  lookbackStart: string;
  clientTrainingContext: Record<string, unknown>;
}): Promise<UserContext> {
  const [profile, recentCompletedSessions, plannedSessionsThisWeek, latestHealth, recentChatHistory] =
    await Promise.all([
      fetchSingleRow(supabase, "profiles", userId),
      fetchActivities({
        supabase,
        userId,
        status: "completed",
        from: lookbackStart,
        to: today,
        ascending: false,
      }),
      fetchActivities({
        supabase,
        userId,
        status: "planned",
        from: weekStart,
        to: weekEnd,
        ascending: true,
      }),
      fetchLatestDailyHealth(supabase, userId),
      fetchRecentCoachMessages(supabase, userId),
    ]);

  return {
    today,
    week_start: weekStart,
    week_end: weekEnd,
    profile,
    latest_health: latestHealth,
    recent_completed_sessions: recentCompletedSessions,
    planned_sessions_this_week: plannedSessionsThisWeek,
    recent_chat_history: recentChatHistory,
    client_training_context: clientTrainingContext,
  };
}

async function fetchSingleRow(
  supabase: SupabaseClient,
  table: string,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await supabase
    .from(table)
    .select("*")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load ${table}: ${error.message}`);
  }

  return data as Record<string, unknown> | null;
}

async function fetchActivities({
  supabase,
  userId,
  status,
  from,
  to,
  ascending,
}: {
  supabase: SupabaseClient;
  userId: string;
  status: "completed" | "planned";
  from: string;
  to: string;
  ascending: boolean;
}): Promise<Array<Record<string, unknown>>> {
  const dateColumns = ["date", "scheduled_date", "completed_at", "start_time", "created_at"];

  for (const dateColumn of dateColumns) {
    const query = supabase
      .from("activities")
      .select("*")
      .eq("user_id", userId)
      .eq("status", status)
      .gte(dateColumn, from)
      .lte(dateColumn, to)
      .order(dateColumn, { ascending });

    const { data, error } = await query;

    if (!error) {
      return (data ?? []) as Array<Record<string, unknown>>;
    }

    if (!isMissingColumnError(error)) {
      throw new Error(`Failed to load ${status} activities: ${error.message}`);
    }
  }

  const { data, error } = await supabase
    .from("activities")
    .select("*")
    .eq("user_id", userId)
    .eq("status", status)
    .limit(100);

  if (error) {
    throw new Error(`Failed to load ${status} activities: ${error.message}`);
  }

  return filterRowsByDateRange(
    (data ?? []) as Array<Record<string, unknown>>,
    from,
    to,
    ascending,
  );
}

async function fetchLatestDailyHealth(
  supabase: SupabaseClient,
  userId: string,
): Promise<Record<string, unknown> | null> {
  const orderColumns = ["day", "date", "created_at"];

  for (const orderColumn of orderColumns) {
    const { data, error } = await supabase
      .from("daily_health")
      .select("*")
      .eq("user_id", userId)
      .order(orderColumn, { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!error) {
      return data as Record<string, unknown> | null;
    }

    if (!isMissingColumnError(error)) {
      throw new Error(`Failed to load daily_health: ${error.message}`);
    }
  }

  const { data, error } = await supabase
    .from("daily_health")
    .select("*")
    .eq("user_id", userId)
    .limit(100);

  if (error) {
    throw new Error(`Failed to load daily_health: ${error.message}`);
  }

  const rows = sortRowsByDateValue(
    (data ?? []) as Array<Record<string, unknown>>,
    false,
  );

  return rows[0] ?? null;
}

async function fetchRecentCoachMessages(
  supabase: SupabaseClient,
  userId: string,
): Promise<Array<Record<string, unknown>>> {
  const orderColumns = ["created_at", "timestamp", "inserted_at"];

  for (const orderColumn of orderColumns) {
    const { data, error } = await supabase
      .from("coach_messages")
      .select("*")
      .eq("user_id", userId)
      .order(orderColumn, { ascending: false })
      .limit(10);

    if (!error) {
      return [...((data ?? []) as Array<Record<string, unknown>>)].reverse();
    }

    if (!isMissingColumnError(error)) {
      throw new Error(`Failed to load coach_messages: ${error.message}`);
    }
  }

  const { data, error } = await supabase
    .from("coach_messages")
    .select("*")
    .eq("user_id", userId)
    .limit(50);

  if (error) {
    throw new Error(`Failed to load coach_messages: ${error.message}`);
  }

  return sortRowsByDateValue(
    (data ?? []) as Array<Record<string, unknown>>,
    true,
  ).slice(-10);
}

async function insertCoachMessage(
  supabase: SupabaseClient,
  userId: string,
  role: CoachChatRole,
  content: string,
  metadata: Record<string, unknown>,
): Promise<void> {
  const payloads = [
    { user_id: userId, role, content, metadata },
    { user_id: userId, role, content },
  ];

  let lastError: { message: string } | null = null;

  for (const payload of payloads) {
    const { error } = await supabase.from("coach_messages").insert(payload);
    if (!error) {
      return;
    }
    lastError = error;

    if (!isMissingColumnError(error)) {
      break;
    }
  }

  throw new Error(`Failed to store coach message: ${lastError?.message ?? "unknown error"}`);
}

function filterRowsByDateRange(
  rows: Array<Record<string, unknown>>,
  from: string,
  to: string,
  ascending: boolean,
): Array<Record<string, unknown>> {
  const fromDate = from;
  const toDate = to;

  return sortRowsByDateValue(rows, ascending).filter((row) => {
    const rowDate = extractRowDate(row);
    return rowDate !== null && rowDate >= fromDate && rowDate <= toDate;
  });
}

function sortRowsByDateValue(
  rows: Array<Record<string, unknown>>,
  ascending: boolean,
): Array<Record<string, unknown>> {
  return [...rows].sort((left, right) => {
    const leftDate = extractRowDate(left) ?? "";
    const rightDate = extractRowDate(right) ?? "";
    return ascending ? leftDate.localeCompare(rightDate) : rightDate.localeCompare(leftDate);
  });
}

function extractRowDate(row: Record<string, unknown>): string | null {
  const candidates = ["day", "date", "scheduled_date", "completed_at", "start_time", "created_at", "timestamp"];

  for (const key of candidates) {
    const value = row[key];
    if (typeof value === "string" && value.length >= 10) {
      return value.slice(0, 10);
    }
  }

  return null;
}

function isMissingColumnError(error: { code?: string; message: string }): boolean {
  return error.code === "42703" || error.message.toLowerCase().includes("column");
}

function startOfUtcDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

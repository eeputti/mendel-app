const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json",
};

const openAIKey = Deno.env.get("OPENAI_API_KEY");

type PersonalizationRequest = {
  profile?: Record<string, unknown>;
  derived_profile?: Record<string, unknown>;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!openAIKey) {
    return jsonResponse({ error: "Missing OPENAI_API_KEY" }, 500);
  }

  try {
    const body = await request.json() as PersonalizationRequest;

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
                text:
                  "You are KESTO, a premium Nordic hybrid training product. Write calm, sharp onboarding personalization copy. Avoid hype, fluff, and generic motivation. Return only JSON.",
              },
            ],
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: `Build an onboarding personalization response from this data:\n${JSON.stringify(body, null, 2)}`,
              },
            ],
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "onboarding_personalization",
            strict: true,
            schema: {
              type: "object",
              additionalProperties: false,
              properties: {
                coachProfileSummary: { type: "string" },
                startingFocus: {
                  type: "array",
                  items: { type: "string" },
                  minItems: 3,
                  maxItems: 3,
                },
                welcomeMessage: { type: "string" },
                firstWeekRecommendation: { type: "string" },
                coachStyleLine: { type: "string" },
                whyLine: { type: "string" },
              },
              required: [
                "coachProfileSummary",
                "startingFocus",
                "welcomeMessage",
                "firstWeekRecommendation",
                "coachStyleLine",
                "whyLine",
              ],
            },
          },
        },
      }),
    });

    if (!openAIResponse.ok) {
      return jsonResponse({ error: await openAIResponse.text() }, openAIResponse.status);
    }

    const payload = await openAIResponse.json();
    const outputText = payload.output?.[0]?.content?.find((item: { type: string }) =>
      item.type === "output_text"
    )?.text;

    if (!outputText) {
      return jsonResponse({ error: "Missing structured output" }, 502);
    }

    return jsonResponse(JSON.parse(outputText), 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return jsonResponse({ error: message }, 500);
  }
});

function jsonResponse(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

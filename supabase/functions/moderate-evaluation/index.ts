// supabase/functions/moderate-evaluation/index.ts
// Суурилуулах газар: Supabase Edge Functions
// Триггер: evaluations хүснэгтэд INSERT хийгдэх бүрт автоматаар ажиллана

import { createClient } from "@supabase/supabase-js";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ══════════════════════════════════════
// System Prompt — Модератор
// ══════════════════════════════════════
const SYSTEM_PROMPT = `Чи Монгол хэлний сургуулийн үнэлгээний контент модератор.
Оюутны багшид бичсэн 1 сэтгэгдлийг шалгана.

══ ДОРОМЖЛОЛ ШАЛГАЛТ ══
Шууд доромжлол:
  Монгол: тэнэг, новш, мангар, мунхаг, ганган, өөдгүй, хог, муухай, шаахай, мал, нохой, гахай, солиотой, галзуу, могой, худалч, донтой
  Англи: fuck, shit, bitch, asshole, damn, bastard, dick, pussy, cunt, wtf, stfu, whore, slut, retard, idiot, stupid, dumb, moron, loser
  Нууцалсан: f*ck, sh*t, b*tch, f**k
  Латин Монгол: teneg, muuhai, hog, gangan

Шууд бус доромжлол: "юу ч мэдэхгүй хүн", "хог шиг хичээл", "хамгийн муу багш"
Заналхийлэл: "чамайг алж хаяна", "зодно шүү"

Контекст:
  ✅ "шалгалт намайг алж байна" = ЗӨВ (хэлц)
  ❌ "чамайг алах юм" = ДОРОМЖЛОЛ
  Шүүмжлэл ≠ доромжлол

══ МЭДРЭМЖ ══
positive = талархал, магтаал | negative = гомдол, шүүмжлэл | neutral = төвийг сахисан

══ ХАРИУ ══
Зөвхөн JSON, өөр текст бүү бич:
{"is_inappropriate": true/false, "reason": "тайлбар", "flagged_words": ["үг"], "severity": "high/medium/low/none", "sentiment": "positive/negative/neutral", "sentiment_score": 0.0-1.0, "sentiment_reason": "тайлбар"}`;

// ══════════════════════════════════════
// Groq API дуудах
// ══════════════════════════════════════
async function callGroq(comment: string) {
  const response = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${GROQ_API_KEY}`,
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: `Сэтгэгдэл: ${comment}` },
      ],
      temperature: 0.05,
      max_tokens: 500,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error(`Groq error ${response.status}: ${errText}`);
    return null;
  }

  const data = await response.json();
  const text = data.choices?.[0]?.message?.content ?? "";

  // JSON олох
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    console.error("JSON олдсонгүй:", text);
    return null;
  }

  try {
    return JSON.parse(match[0]);
  } catch {
    console.error("JSON parse error:", text);
    return null;
  }
}

// ══════════════════════════════════════
// Багшийн нэр форматлах
// ══════════════════════════════════════
function formatTeacherName(lastName: string | null, firstName: string | null): string {
  const last = (lastName ?? "").trim();
  const first = (firstName ?? "").trim();
  if (last && first) return `${last[0]}. ${first}`;
  if (first) return first;
  if (last) return last;
  return "Багш";
}

// ══════════════════════════════════════
// Edge Function handler
// ══════════════════════════════════════
Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const payload = await req.json();

    // Database webhook payload-аас шинэ record авах
    const record = payload.record;
    if (!record) {
      return new Response(JSON.stringify({ error: "No record" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const evaluationId = record.id;
    const comment = record.comment;
    const studentId = record.student_id;

    // Хоосон сэтгэгдэл бол алгасах
    if (!comment || comment.trim() === "") {
      return new Response(
        JSON.stringify({ skipped: true, reason: "empty" }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`Шалгаж байна: evaluation #${evaluationId} — "${comment}"`);

    // Supabase client (service role — бүх эрхтэй)
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Groq AI шалгалт ──
    const result = await callGroq(comment);

    if (!result) {
      console.log("AI шалгалт амжилтгүй, алгасав");
      return new Response(
        JSON.stringify({ skipped: true, reason: "ai_failed" }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    console.log("AI үр дүн:", JSON.stringify(result));

    // ── Зөрчилтэй бол → устгах + мэдэгдэл ──
    if (result.is_inappropriate === true) {
      console.log(`⚠️ Зөрчил илэрлээ! Severity: ${result.severity}`);

      // 1) Оюутны user_id авах
      let studentUserId: number | null = null;

      if (studentId) {
        const { data: student, error: studentErr } = await supabase
          .from("Students")
          .select("user_id")
          .eq("id", studentId)
          .single();
        if (studentErr) {
          console.error("Оюутан олдсонгүй:", studentErr.message);
        } else {
          studentUserId = student?.user_id ?? null;
        }
      }

      // 2) Багшийн нэр авах
      let teacherName = "Багш";
      if (record.teacher_id) {
        const { data: teacher } = await supabase
          .from("Teachers")
          .select("first_name, last_name")
          .eq("id", record.teacher_id)
          .single();
        if (teacher) {
          teacherName = formatTeacherName(teacher.last_name, teacher.first_name);
        }
      }

      // 3) Мэдэгдэл илгээх
      if (studentUserId !== null) {
        const flaggedWords: string[] = result.flagged_words ?? [];
        const severity: string = result.severity ?? "medium";

        let severityText = "зөрчил";
        if (severity === "high") severityText = "хүнд зөрчил";
        else if (severity === "medium") severityText = "дунд зөрчил";
        else if (severity === "low") severityText = "бага зөрчил";

        const wordsText =
          flaggedWords.length > 0
            ? ` Илэрсэн үг: ${flaggedWords.join(", ")}.`
            : "";

        const { error: notifError } = await supabase
          .from("notifications")
          .insert({
            user_id: studentUserId,
            title: "⚠️ Үнэлгээ устгагдлаа",
            body:
              `Таны "${teacherName}" багшид бичсэн үнэлгээ доромжлол/харааль агуулсан тул ` +
              `устгагдлаа (${severityText}).${wordsText} ` +
              `Та зөв, боловсон хэлээр дахин үнэлгээ бичнэ үү.`,
            type: "warning",
            is_read: false,
          });

        if (notifError) {
          console.error("Мэдэгдэл алдаа:", notifError.message);
        } else {
          console.log("✅ Мэдэгдэл илгээгдлээ → user_id:", studentUserId);
        }
      } else {
        console.warn("studentUserId олдсонгүй, мэдэгдэл явуулаагүй");
      }

      // 4) Үнэлгээг устгах
      const { error: deleteError } = await supabase
        .from("evaluations")
        .delete()
        .eq("id", evaluationId);

      if (deleteError) {
        console.error("Устгах алдаа:", deleteError.message);
      } else {
        console.log("✅ Үнэлгээ устгагдлаа #", evaluationId);
      }

      return new Response(
        JSON.stringify({
          moderated: true,
          action: "deleted",
          severity: result.severity,
          reason: result.reason,
          flagged_words: result.flagged_words,
          sentiment: result.sentiment,
        }),
        {
          status: 200,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    // ── Зөрчилгүй → зүгээр орхих ──
    console.log(
      `✅ Цэвэр сэтгэгдэл. Sentiment: ${result.sentiment} (${result.sentiment_score})`
    );

    return new Response(
      JSON.stringify({
        moderated: true,
        action: "approved",
        sentiment: result.sentiment,
        sentiment_score: result.sentiment_score,
      }),
      {
        status: 200,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("Edge Function алдаа:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
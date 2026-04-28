// supabase/functions/moderate-evaluation/index.ts
// Суурилуулах газар: Supabase Edge Functions
// Триггер: evaluations хүснэгтэд INSERT хийгдэх бүрт автоматаар ажиллана

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

// ══════════════════════════════════════
// System Prompt — Модератор
// ══════════════════════════════════════
const SYSTEM_PROMPT = `Чи Монгол хэлний сургуулийн үнэлгээний контент модератор.
Оюутны багшид бичсэн 1 сэтгэгдлийг шалгана.

══ ДОРОМЖЛОЛ ШАЛГАЛТ ══
Шууд доромжлол:
  Монгол: тэнэг, мангар, мунхаг, ганган, өөдгүй, хог, муухай, шаахай, мал, нохой, гахай, солиотой, галзуу, могой, худалч, донтой
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
      max_completion_tokens: 500,
    }),
  });

  if (!response.ok) {
    console.error(`Groq error: ${response.status}`);
    return null;
  }

  const data = await response.json();
  const text = data.choices?.[0]?.message?.content ?? "";

  // JSON олох
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;

  try {
    return JSON.parse(match[0]);
  } catch {
    console.error("JSON parse error:", text);
    return null;
  }
}

// ══════════════════════════════════════
// Edge Function handler
// ══════════════════════════════════════
Deno.serve(async (req) => {
  try {
    const payload = await req.json();

    // Database webhook payload-аас шинэ record авах
    const record = payload.record;
    if (!record) {
      return new Response(JSON.stringify({ error: "No record" }), {
        status: 400,
      });
    }

    const evaluationId = record.id;
    const comment = record.comment;
    const studentId = record.student_id;

    // Хоосон сэтгэгдэл бол алгасах
    if (!comment || comment.trim() === "") {
      return new Response(JSON.stringify({ skipped: true, reason: "empty" }), {
        status: 200,
      });
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
        { status: 200 }
      );
    }

    console.log("AI үр дүн:", JSON.stringify(result));

    // ── Зөрчилтэй бол → устгах + мэдэгдэл ──
    if (result.is_inappropriate === true) {
      console.log(`⚠️ Зөрчил илэрлээ! Severity: ${result.severity}`);

      // 1) Оюутны мэдээлэл авах
      let studentUserId: string | null = null;
      let teacherName = "Багш";

      if (studentId) {
        const { data: student } = await supabase
          .from("Students")
          .select("user_id")
          .eq("id", studentId)
          .single();
        studentUserId = student?.user_id ?? null;
      }

      // Багшийн нэр авах
      if (record.teacher_id) {
        const { data: teacher } = await supabase
          .from("Teachers")
          .select("first_name, last_name")
          .eq("id", record.teacher_id)
          .single();
        if (teacher) {
          teacherName =
            `${teacher.last_name ?? ""}. ${teacher.first_name ?? ""}`.trim();
        }
      }

      // 2) Мэдэгдэл илгээх
      if (studentUserId) {
        const flaggedWords = result.flagged_words ?? [];
        const severity = result.severity ?? "medium";

        let severityText = "зөрчил";
        if (severity === "high") severityText = "хүнд зөрчил";
        else if (severity === "medium") severityText = "дунд зөрчил";

        const wordsText =
          flaggedWords.length > 0
            ? ` Илэрсэн: ${flaggedWords.join(", ")}.`
            : "";

        const { error: notifError } = await supabase
          .from("notifications")
          .insert({
            user_id: studentUserId,
            title: "⚠️ Үнэлгээ устгагдлаа",
            body:
              `Таны "${teacherName}" багшид бичсэн үнэлгээ доромжлол/хараалын үг агуулсан тул ` +
              `устгагдлаа (${severityText}).${wordsText} ` +
              `Та зөв, боловсон хэлээр дахин үнэлгээ бичнэ үү.`,
            type: "warning",
            is_read: false,
          });

        if (notifError) {
          console.error("Мэдэгдэл алдаа:", notifError);
        } else {
          console.log("✅ Мэдэгдэл илгээгдлээ");
        }
      }

      // 3) Үнэлгээг устгах
      const { error: deleteError } = await supabase
        .from("evaluations")
        .delete()
        .eq("id", evaluationId);

      if (deleteError) {
        console.error("Устгах алдаа:", deleteError);
      } else {
        console.log("✅ Үнэлгээ устгагдлаа");
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
        { status: 200 }
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
      { status: 200 }
    );
  } catch (err) {
    console.error("Edge Function алдаа:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
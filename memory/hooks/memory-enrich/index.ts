import { execFileSync } from "child_process";

const MEMOS_API = process.env.MEMOS_API_URL || "http://100.76.233.80:5230";
const MAX_ENRICHMENT_CHARS = 1500; // ~500 tokens

interface MemosResponse {
  memos: Array<{ name: string; content: string; createTime: string; updateTime: string }>;
  nextPageToken?: string;
}

function getMemosToken(): string {
  try {
    const result = execFileSync("curl", [
      "-sf", "-X", "POST",
      "http://100.76.233.80:5230/memos.api.v1.AuthService/SignIn",
      "-H", "Content-Type: application/json",
      "-d", JSON.stringify({passwordCredentials:{username:"openclaw",password:process.env.MEMOS_PASSWORD||"changeme"}})
    ], { timeout: 5000 }).toString();
    const data = JSON.parse(result);
    return data.accessToken || "";
  } catch {
    return "";
  }
}

function searchMemos(keyword: string, token: string, pageSize = 5): MemosResponse {
  try {
    const url = `${MEMOS_API}/api/v1/memos?pageSize=${pageSize}&filter=${encodeURIComponent(`content.contains('${keyword}')`)}`;
    const args = ["-sf", "--max-time", "3"];
    if (token) {
      args.push("-H", `Authorization: Bearer ${token}`);
    }
    args.push(url);
    const raw = execFileSync("curl", args, { timeout: 5000 }).toString();
    return JSON.parse(raw);
  } catch {
    return { memos: [] };
  }
}

function extractKeywords(text: string): string[] {
  // Remove common stop words, keep meaningful terms 3+ chars
  const stopWords = new Set([
    "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
    "had", "her", "was", "one", "our", "out", "has", "his", "how", "its",
    "may", "new", "now", "old", "see", "way", "who", "did", "get", "let",
    "say", "she", "too", "use", "this", "that", "with", "have", "from",
    "they", "been", "said", "each", "will", "what", "when", "make", "like",
    "just", "over", "such", "take", "than", "them", "very", "some", "into",
    "could", "would", "about", "which", "there", "their", "these", "other",
    "should", "please", "thanks", "hello", "help", "need", "want", "know",
  ]);

  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 3 && !stopWords.has(w));

  // Deduplicate, take top 5 most distinctive
  const unique = [...new Set(words)];
  return unique.slice(0, 5);
}

const handler = async (event: any) => {
  if (event.type !== "message" || event.action !== "received") return;

  // Extract text from the incoming message
  const context = event.context || {};
  const message = context.message || {};
  let text = "";

  if (typeof message.content === "string") {
    text = message.content;
  } else if (Array.isArray(message.content)) {
    text = message.content
      .filter((c: any) => c.type === "text")
      .map((c: any) => c.text)
      .join(" ");
  }

  if (!text || text.length < 10) return;

  const keywords = extractKeywords(text);
  if (keywords.length === 0) return;

  const token = getMemosToken();

  // Search memos for each keyword, collect unique results
  const seen = new Set<string>();
  const relevant: string[] = [];
  let totalChars = 0;

  for (const kw of keywords) {
    if (totalChars >= MAX_ENRICHMENT_CHARS) break;

    const resp = searchMemos(kw, token, 3);
    if (!resp.memos) continue;

    for (const memo of resp.memos) {
      if (seen.has(memo.name)) continue;
      seen.add(memo.name);

      const preview = memo.content.slice(0, 300).replace(/\n/g, " ");
      if (totalChars + preview.length > MAX_ENRICHMENT_CHARS) break;

      relevant.push(`- ${preview}`);
      totalChars += preview.length;
    }
  }

  if (relevant.length === 0) return;

  const enrichment = [
    "<memory-context>",
    "Relevant memories retrieved from Memos (keywords: " + keywords.join(", ") + "):",
    "",
    ...relevant,
    "</memory-context>",
  ].join("\n");

  event.messages.push({
    role: "user",
    content: [{ type: "text", text: enrichment }],
  });
};

export default handler;

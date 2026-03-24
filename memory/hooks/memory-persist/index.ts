import { execFileSync } from "child_process";

const MEMOS_API = process.env.MEMOS_API_URL || "http://100.76.233.80:5230";
const SELF_EVAL_MCP = process.env.SELF_EVAL_MCP_URL || "http://localhost:9502";

// Rate-limit: don't persist more than 1 memo per 30 seconds
let lastPersistTime = 0;
const PERSIST_COOLDOWN_MS = 30_000;

interface SignalMatch {
  tag: string;
  pattern: RegExp;
}

const SIGNALS: SignalMatch[] = [
  { tag: "#decision", pattern: /\b(?:decided|decision|chose|choosing|we(?:'ll| will) go with)\b/i },
  { tag: "#completed", pattern: /\b(?:completed|finished|done|implemented|deployed|shipped|resolved)\b/i },
  { tag: "#learning", pattern: /\b(?:learned|discovered|realized|insight|takeaway|finding|turns out)\b/i },
  { tag: "#error", pattern: /\b(?:error|failed|failure|bug|broken|crash|exception|issue found)\b/i },
];

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

function createMemo(content: string): boolean {
  try {
    const token = getMemosToken();
    if (!token) return false;

    const args = [
      "-sf", "--max-time", "5",
      "-X", "POST",
      "-H", `Authorization: Bearer ${token}`,
      "-H", "Content-Type: application/json",
      `${MEMOS_API}/api/v1/memos`,
      "-d", JSON.stringify({ content }),
    ];
    execFileSync("curl", args, { timeout: 8000 });
    return true;
  } catch {
    return false;
  }
}

function triggerSelfEval(summary: string): void {
  try {
    const payload = JSON.stringify({
      jsonrpc: "2.0",
      method: "tools/call",
      params: {
        name: "self_eval",
        arguments: { summary, trigger: "task-completion" },
      },
      id: Date.now(),
    });
    execFileSync("curl", [
      "-sf", "--max-time", "3",
      "-X", "POST",
      "-H", "Content-Type: application/json",
      SELF_EVAL_MCP,
      "-d", payload,
    ], { timeout: 5000 });
  } catch {
    // Self-eval MCP may not be running yet; fail silently
  }
}

function extractFirstSentences(text: string, count = 3): string {
  const sentences = text.match(/[^.!?\n]+[.!?\n]+/g) || [text.slice(0, 200)];
  return sentences.slice(0, count).join(" ").trim().slice(0, 500);
}

const handler = async (event: any) => {
  if (event.type !== "message" || event.action !== "sent") return;

  const now = Date.now();
  if (now - lastPersistTime < PERSIST_COOLDOWN_MS) return;

  // Extract text from the outbound message
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

  if (!text || text.length < 50) return;

  // Check for significant signals
  const matchedTags: string[] = [];
  for (const signal of SIGNALS) {
    if (signal.pattern.test(text)) {
      matchedTags.push(signal.tag);
    }
  }

  if (matchedTags.length === 0) return;

  // Build memo content
  const summary = extractFirstSentences(text);
  const tags = matchedTags.join(" ");
  const timestamp = new Date().toISOString();
  const memoContent = `${summary}\n\n${tags} #autoresearch\nTimestamp: ${timestamp}`;

  if (createMemo(memoContent)) {
    lastPersistTime = now;
  }

  // If task completion detected, trigger self-eval
  if (matchedTags.includes("#completed")) {
    triggerSelfEval(summary);
  }
};

export default handler;

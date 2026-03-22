import { execFileSync } from "child_process";

const MEMOS_API = process.env.MEMOS_API_URL || "http://100.76.233.80:5230";

function getMemosToken(): string {
  try {
    const result = execFileSync("curl", [
      "-sf", "-X", "POST",
      "http://100.76.233.80:5230/memos.api.v1.AuthService/SignIn",
      "-H", "Content-Type: application/json",
      "-d", JSON.stringify({passwordCredentials:{username:"openclaw",password:process.env.MEMOS_PASSWORD||"YOUR_MEMOS_PASSWORD"}})
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

function extractKeyFacts(messages: any[]): string[] {
  const facts: string[] = [];
  const seen = new Set<string>();

  for (const msg of messages) {
    if (!msg || !msg.content) continue;

    let text = "";
    if (typeof msg.content === "string") {
      text = msg.content;
    } else if (Array.isArray(msg.content)) {
      text = msg.content
        .filter((c: any) => c.type === "text")
        .map((c: any) => c.text)
        .join(" ");
    }

    if (!text || text.length < 30) continue;

    // Look for significant patterns
    const patterns = [
      { re: /(?:decided|decision|chose)[:.]?\s*(.{20,200})/gi, tag: "Decision" },
      { re: /(?:completed|finished|done)[:.]?\s*(.{20,200})/gi, tag: "Completed" },
      { re: /(?:todo|next step|follow[- ]up)[:.]?\s*(.{20,200})/gi, tag: "TODO" },
      { re: /(?:error|failed|bug|issue)[:.]?\s*(.{20,200})/gi, tag: "Issue" },
      { re: /(?:learned|insight|finding|discovered)[:.]?\s*(.{20,200})/gi, tag: "Learning" },
      { re: /(?:task \d|step \d|phase \d)[:.]?\s*(.{20,200})/gi, tag: "Progress" },
    ];

    for (const { re, tag } of patterns) {
      let match;
      while ((match = re.exec(text)) !== null) {
        const fact = match[1].replace(/\n/g, " ").trim().slice(0, 200);
        const key = `${tag}:${fact.slice(0, 50)}`;
        if (!seen.has(key)) {
          seen.add(key);
          facts.push(`[${tag}] ${fact}`);
        }
        if (facts.length >= 15) break;
      }
      if (facts.length >= 15) break;
    }
    if (facts.length >= 15) break;
  }

  return facts;
}

const handler = async (event: any) => {
  if (event.type !== "session" || event.action !== "compact:before") return;

  const context = event.context || {};
  const messages = context.messages || [];

  if (!Array.isArray(messages) || messages.length === 0) return;

  const facts = extractKeyFacts(messages);

  if (facts.length === 0) return;

  const timestamp = new Date().toISOString();
  const sessionKey = event.sessionKey || "unknown";

  const memoContent = [
    `## Context Flush — ${timestamp}`,
    `Session: ${sessionKey}`,
    `Messages being compacted: ${messages.length}`,
    "",
    "### Key Facts Preserved",
    ...facts.map((f) => `- ${f}`),
    "",
    "#context-flush #autoresearch",
  ].join("\n");

  createMemo(memoContent);
};

export default handler;

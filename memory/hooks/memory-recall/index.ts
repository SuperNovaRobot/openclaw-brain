import { execFileSync } from "child_process";

const MEMOS_API = process.env.MEMOS_API_URL || "http://100.76.233.80:5230";

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
      "-d", JSON.stringify({passwordCredentials:{username:"openclaw",password:process.env.MEMOS_PASSWORD||"YOUR_MEMOS_PASSWORD"}})
    ], { timeout: 5000 }).toString();
    const data = JSON.parse(result);
    return data.accessToken || "";
  } catch {
    return "";
  }
}

function searchMemos(filter: string, token: string, pageSize = 20): MemosResponse {
  try {
    const url = `${MEMOS_API}/api/v1/memos?pageSize=${pageSize}&filter=${encodeURIComponent(filter)}`;
    const args = ["-sf", "--max-time", "5"];
    if (token) {
      args.push("-H", `Authorization: Bearer ${token}`);
    }
    args.push(url);
    const raw = execFileSync("curl", args, { timeout: 8000 }).toString();
    return JSON.parse(raw);
  } catch {
    return { memos: [] };
  }
}

function formatMemos(label: string, tag: string, token: string): string {
  const resp = searchMemos(`content.contains('${tag}')`, token);
  if (!resp.memos || resp.memos.length === 0) return "";

  const items = resp.memos
    .slice(0, 10)
    .map((m) => {
      const preview = m.content.slice(0, 200).replace(/\n/g, " ");
      return `  - ${preview}`;
    })
    .join("\n");

  return `### ${label} (${tag})\n${items}`;
}

const handler = async (event: any) => {
  if (event.type !== "agent" || event.action !== "bootstrap") return;

  const token = getMemosToken();

  const sections: string[] = [];

  const tags = [
    { label: "Active TODOs", tag: "#todo" },
    { label: "Current Mission", tag: "#mission" },
    { label: "Recent Self-Evaluations", tag: "#self-eval" },
    { label: "Active Experiments", tag: "#improvement" },
    { label: "Context Flushes", tag: "#context-flush" },
  ];

  for (const { label, tag } of tags) {
    const section = formatMemos(label, tag, token);
    if (section) sections.push(section);
  }

  if (sections.length === 0) return;

  const content = [
    "## Memory Recall — Active Context from Memos",
    "",
    "The following items were retrieved from your persistent memory (Memos):",
    "",
    ...sections,
    "",
    "Use this context to continue work. Update or close items as they are resolved.",
  ].join("\n");

  event.messages.push({
    role: "user",
    content: [{ type: "text", text: content }],
  });
};

export default handler;

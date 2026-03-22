import { execFileSync } from "child_process";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { tmpdir, homedir } from "os";

const LCM_DB = process.env.LCM_DB || join(homedir(), ".openclaw", "lcm.db");
const RAGFLOW_API =
  process.env.RAGFLOW_API || "http://100.76.233.80:9380/api/v1";
const RAGFLOW_KEY =
  process.env.RAGFLOW_KEY || "ragflow-c5062fdd133375fcef53c7b91eca624c";
const DATASET_ID =
  process.env.RAGFLOW_DATASET_ID || "4a543fc0263e11f1b983a57a35761573";
const SYNC_STATE_DIR = join(homedir(), ".openclaw", "lcm-ragflow-sync");
const LAST_SYNC_FILE = join(SYNC_STATE_DIR, ".last-sync-id");
const SYNCED_IDS_FILE = join(SYNC_STATE_DIR, "synced-ids.txt");

// Rate-limit: at most one sync per 10 seconds
let lastSyncTime = 0;
const SYNC_COOLDOWN_MS = 10_000;

interface LcmSummary {
  summary_id: string;
  conversation_id: number;
  session_id: string;
  conversation_title: string;
  kind: string;
  depth: number;
  content: string;
  token_count: number;
  earliest_at: string;
  latest_at: string;
  message_count: number;
  model: string;
  created_at: string;
}

function getLastSyncId(): string {
  try {
    if (existsSync(LAST_SYNC_FILE)) {
      return readFileSync(LAST_SYNC_FILE, "utf-8").trim();
    }
  } catch {
    // ignore
  }
  return "";
}

function setLastSyncId(id: string): void {
  try {
    mkdirSync(SYNC_STATE_DIR, { recursive: true });
    writeFileSync(LAST_SYNC_FILE, id + "\n");
  } catch {
    // ignore
  }
}

function appendSyncedId(id: string): void {
  try {
    mkdirSync(SYNC_STATE_DIR, { recursive: true });
    const existing = existsSync(SYNCED_IDS_FILE)
      ? readFileSync(SYNCED_IDS_FILE, "utf-8")
      : "";
    if (!existing.includes(id)) {
      writeFileSync(SYNCED_IDS_FILE, existing + id + "\n");
    }
  } catch {
    // ignore
  }
}

function queryLatestSummary(): LcmSummary | null {
  if (!existsSync(LCM_DB)) return null;

  try {
    const pyScript = [
      "import sqlite3, json, sys",
      "conn = sqlite3.connect('" + LCM_DB + "')",
      "c = conn.cursor()",
      "c.execute('''",
      "  SELECT json_object(",
      "    'summary_id', s.summary_id,",
      "    'conversation_id', s.conversation_id,",
      "    'session_id', c.session_id,",
      "    'conversation_title', COALESCE(c.title, 'untitled'),",
      "    'kind', s.kind,",
      "    'depth', s.depth,",
      "    'content', s.content,",
      "    'token_count', s.token_count,",
      "    'earliest_at', COALESCE(s.earliest_at, ''),",
      "    'latest_at', COALESCE(s.latest_at, ''),",
      "    'message_count', (SELECT COUNT(*) FROM summary_messages sm WHERE sm.summary_id = s.summary_id),",
      "    'model', s.model,",
      "    'created_at', s.created_at",
      "  )",
      "  FROM summaries s",
      "  JOIN conversations c ON s.conversation_id = c.conversation_id",
      "  ORDER BY s.rowid DESC",
      "  LIMIT 1",
      "''')",
      "row = c.fetchone()",
      "conn.close()",
      "print(row[0] if row else 'null')",
    ].join("\n");

    const result = execFileSync("python3", ["-c", pyScript], {
      timeout: 5000,
    })
      .toString()
      .trim();

    if (result === "null" || !result) return null;
    return JSON.parse(result) as LcmSummary;
  } catch {
    return null;
  }
}

function buildDocument(s: LcmSummary): string {
  const kindLabel = s.kind === "leaf" ? "Leaf Summary" : "Condensed Summary";
  const timeRange =
    s.earliest_at && s.latest_at
      ? s.earliest_at + " to " + s.latest_at
      : s.earliest_at || "unknown";

  return [
    "# " + kindLabel + ": " + s.conversation_title,
    "",
    "## Metadata",
    "- **Summary ID:** " + s.summary_id,
    "- **Conversation:** " +
      s.conversation_title +
      " (ID: " +
      s.conversation_id +
      ", Session: " +
      s.session_id +
      ")",
    "- **Type:** " + s.kind + " (depth " + s.depth + ")",
    "- **Time Range:** " + timeRange,
    "- **Messages Covered:** " + s.message_count,
    "- **Tokens:** " + s.token_count,
    "- **Model:** " + s.model,
    "- **Created:** " + s.created_at,
    "",
    "## Content",
    "",
    s.content,
    "",
    "---",
    "*Synced from Lossless Claw (LCM) — use lcm:recall with summary_id " +
      s.summary_id +
      " to drill into full conversation*",
    "",
  ].join("\n");
}

function uploadToRagFlow(docContent: string, summaryId: string): boolean {
  const tmpFile = join(tmpdir(), "lcm-" + summaryId.slice(0, 16) + ".md");

  try {
    writeFileSync(tmpFile, docContent);

    // Upload document
    const uploadResult = execFileSync(
      "curl",
      [
        "-sf",
        "--max-time",
        "15",
        "-X",
        "POST",
        "-H",
        "Authorization: Bearer " + RAGFLOW_KEY,
        "-F",
        "file=@" + tmpFile,
        RAGFLOW_API + "/datasets/" + DATASET_ID + "/documents",
      ],
      { timeout: 20000 },
    ).toString();

    const resp = JSON.parse(uploadResult);
    if (resp.code !== 0) return false;

    const docId = resp.data?.[0]?.id;
    if (!docId) return false;

    // Trigger parsing
    execFileSync(
      "curl",
      [
        "-sf",
        "--max-time",
        "10",
        "-X",
        "POST",
        "-H",
        "Authorization: Bearer " + RAGFLOW_KEY,
        "-H",
        "Content-Type: application/json",
        RAGFLOW_API + "/datasets/" + DATASET_ID + "/chunks",
        "-d",
        JSON.stringify({ document_ids: [docId] }),
      ],
      { timeout: 15000 },
    );

    return true;
  } catch {
    return false;
  } finally {
    try {
      execFileSync("rm", ["-f", tmpFile], { timeout: 2000 });
    } catch {
      // ignore cleanup failure
    }
  }
}

const handler = async (event: any) => {
  if (event.type !== "message" || event.action !== "sent") return;

  const now = Date.now();
  if (now - lastSyncTime < SYNC_COOLDOWN_MS) return;

  // Query LCM for the latest summary
  const latest = queryLatestSummary();
  if (!latest) return;

  // Check if we already synced this one
  const lastSyncId = getLastSyncId();
  if (latest.summary_id === lastSyncId) return;

  // Build and upload
  const doc = buildDocument(latest);
  if (uploadToRagFlow(doc, latest.summary_id)) {
    setLastSyncId(latest.summary_id);
    appendSyncedId(latest.summary_id);
    lastSyncTime = now;
  }
};

export default handler;

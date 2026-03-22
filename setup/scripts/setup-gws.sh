#!/usr/bin/env bash
# setup-gws.sh — Wire Google Workspace CLI for OpenClaw Brain
# Part of Phase 3, Task 28

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

MCP_DIR="$HOME/.openclaw/mcp-servers"
MCP_CONFIG="$MCP_DIR/gws.json"
SKILL_FILE="/mnt/ssd/openclaw-brain/workspace/skills/google-workspace.SKILL.md"

echo -e "${BOLD}=== Google Workspace CLI Setup ===${RESET}"
echo ""

# ------------------------------------------------------------------
# 1. Check if gws binary is already installed
# ------------------------------------------------------------------
GWS_INSTALLED=false

if command -v gws &>/dev/null; then
    GWS_VERSION=$(gws --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}[OK]${RESET} gws binary found: $(command -v gws) (version: $GWS_VERSION)"
    GWS_INSTALLED=true
else
    echo -e "${YELLOW}[WARN]${RESET} gws binary not found in PATH"
fi

# ------------------------------------------------------------------
# 2. Attempt installation (try multiple methods, soft-fail)
# ------------------------------------------------------------------
if [ "$GWS_INSTALLED" = false ]; then
    echo ""
    echo -e "${BOLD}Attempting to install gws...${RESET}"

    # Try cargo
    if command -v cargo &>/dev/null; then
        echo "  Trying: cargo install gws-cli ..."
        if cargo install gws-cli 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${RESET} Installed via cargo"
            GWS_INSTALLED=true
        else
            echo -e "  ${YELLOW}[SKIP]${RESET} cargo install failed (package may not exist on crates.io)"
        fi
    fi

    # Try npm
    if [ "$GWS_INSTALLED" = false ] && command -v npm &>/dev/null; then
        echo "  Trying: npm install -g @googleworkspace/cli ..."
        if npm install -g @googleworkspace/cli 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${RESET} Installed via npm"
            GWS_INSTALLED=true
        else
            echo -e "  ${YELLOW}[SKIP]${RESET} npm install failed (package may not exist on npm)"
        fi
    fi

    # Try prebuilt binary download (GitHub releases)
    if [ "$GWS_INSTALLED" = false ]; then
        ARCH=$(uname -m)
        OS=$(uname -s | tr [:upper:] [:lower:])
        RELEASE_URL="https://github.com/googleworkspace/cli/releases/latest/download/gws-${OS}-${ARCH}"
        echo "  Trying: prebuilt binary from $RELEASE_URL ..."
        if command -v curl &>/dev/null; then
            if curl -fsSL "$RELEASE_URL" -o /tmp/gws 2>/dev/null; then
                chmod +x /tmp/gws
                if [ -w /usr/local/bin ]; then
                    mv /tmp/gws /usr/local/bin/gws
                else
                    sudo mv /tmp/gws /usr/local/bin/gws 2>/dev/null
                fi
                if command -v gws &>/dev/null; then
                    echo -e "  ${GREEN}[OK]${RESET} Installed prebuilt binary to /usr/local/bin/gws"
                    GWS_INSTALLED=true
                else
                    echo -e "  ${YELLOW}[SKIP]${RESET} Binary download succeeded but gws not in PATH"
                fi
            else
                echo -e "  ${YELLOW}[SKIP]${RESET} Prebuilt binary not available at that URL"
            fi
        fi
    fi

    # If all methods failed, print manual instructions
    if [ "$GWS_INSTALLED" = false ]; then
        echo ""
        echo -e "${YELLOW}[INFO]${RESET} Automatic installation was not successful."
        echo -e "${BOLD}Manual installation instructions:${RESET}"
        echo ""
        echo "  Option 1: Build from source"
        echo "    git clone https://github.com/googleworkspace/cli.git /tmp/gws-cli"
        echo "    cd /tmp/gws-cli && make install"
        echo ""
        echo "  Option 2: Download from GitHub Releases"
        echo "    Visit: https://github.com/googleworkspace/cli/releases"
        echo "    Download the binary for your platform and place it in /usr/local/bin/"
        echo ""
        echo "  Option 3: If the CLI is distributed differently, check:"
        echo "    https://github.com/googleworkspace/cli"
        echo ""
        echo -e "  ${YELLOW}This is NOT a hard error.${RESET} The MCP config and skill file will still be created."
        echo "  You can install gws later and everything will work."
        echo ""
    fi
fi

# ------------------------------------------------------------------
# 3. Print OAuth authentication instructions
# ------------------------------------------------------------------
echo ""
echo -e "${BOLD}=== OAuth Authentication ===${RESET}"
echo ""
echo "  gws uses OAuth for Google Workspace access."
echo "  Authentication is interactive and cannot be automated."
echo ""
echo "  To authenticate, run:"
echo "    gws auth login"
echo ""
echo "  This will open a browser for Google OAuth consent."
echo "  If running on a headless server, use:"
echo "    gws auth login --no-browser"
echo "  and follow the URL it prints."
echo ""

# ------------------------------------------------------------------
# 4. Create MCP server config
# ------------------------------------------------------------------
echo -e "${BOLD}=== MCP Server Config ===${RESET}"
mkdir -p "$MCP_DIR"

cat > "$MCP_CONFIG" << EOF
{
  "name": "gws",
  "display_name": "Google Workspace CLI",
  "description": "Google Workspace operations via gws CLI — Gmail, Calendar, Drive, Sheets, Docs, Chat",
  "command": "gws",
  "type": "cli",
  "services": ["gmail", "calendar", "drive", "sheets", "docs", "chat"],
  "auth": {
    "method": "oauth",
    "command": "gws auth login"
  },
  "capabilities": {
    "gmail": ["messages.list", "messages.get", "messages.send"],
    "calendar": ["events.list", "events.create", "events.delete"],
    "drive": ["files.list", "files.download", "files.upload"],
    "sheets": ["spreadsheets.get", "spreadsheets.values.get", "spreadsheets.values.update"],
    "docs": ["documents.get", "documents.create"],
    "chat": ["spaces.list", "spaces.messages.list", "spaces.messages.create"]
  },
  "rules": {
    "require_approval": ["gmail.messages.send", "calendar.events.delete", "calendar.events.create"],
    "safe_operations": ["*.list", "*.get", "drive.files.download"],
    "logging": "Log all write operations to Memos with #gws-action tag"
  },
  "skill_file": "workspace/skills/google-workspace.SKILL.md"
}
EOF

echo -e "${GREEN}[OK]${RESET} MCP config written to $MCP_CONFIG"

# ------------------------------------------------------------------
# 5. Print status summary
# ------------------------------------------------------------------
echo ""
echo -e "${BOLD}=== Status Summary ===${RESET}"
echo ""

if [ "$GWS_INSTALLED" = true ]; then
    echo -e "  gws binary:      ${GREEN}INSTALLED${RESET} ($(command -v gws))"
else
    echo -e "  gws binary:      ${YELLOW}NOT INSTALLED${RESET} (install manually, see above)"
fi

if [ -f "$MCP_CONFIG" ]; then
    echo -e "  MCP config:      ${GREEN}CREATED${RESET} ($MCP_CONFIG)"
else
    echo -e "  MCP config:      ${RED}MISSING${RESET}"
fi

if [ -f "$SKILL_FILE" ]; then
    echo -e "  Skill file:      ${GREEN}EXISTS${RESET} ($SKILL_FILE)"
else
    echo -e "  Skill file:      ${YELLOW}NOT YET CREATED${RESET} (will be created by this task)"
fi

# Check auth status
if [ "$GWS_INSTALLED" = true ]; then
    if gws auth status &>/dev/null 2>&1; then
        echo -e "  Auth status:     ${GREEN}AUTHENTICATED${RESET}"
    else
        echo -e "  Auth status:     ${YELLOW}NOT AUTHENTICATED${RESET} (run: gws auth login)"
    fi
else
    echo -e "  Auth status:     ${YELLOW}SKIPPED${RESET} (gws not installed)"
fi

echo ""
echo -e "${BOLD}Setup complete.${RESET}"

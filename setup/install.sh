#!/bin/bash
set -euo pipefail

###############################################################################
#  OpenClaw Brain — Interactive One-Command Installer
#  https://github.com/openclaw/openclaw-brain
#
#  Usage:
#    bash setup/install.sh              # interactive mode
#    bash setup/install.sh --defaults   # non-interactive, sensible defaults
#
#  Idempotent: safe to re-run at any stage.
###############################################################################

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${REPO_DIR}/setup/.env"
ENV_EXAMPLE="${REPO_DIR}/setup/.env.example"
COMPOSE_NOVA="${REPO_DIR}/setup/docker-compose.nova.yml"
COMPOSE_RIG="${REPO_DIR}/setup/docker-compose.rig.yml"
COMPOSE_RIG_LLAMA="${REPO_DIR}/setup/docker-compose.rig-llamacpp.yml"
PROFILES_DIR="${REPO_DIR}/setup/hardware-profiles"
VERSION="0.1.0"

# ── Flags ────────────────────────────────────────────────────────────────────
USE_DEFAULTS=false
for arg in "$@"; do
  case "$arg" in
    --defaults) USE_DEFAULTS=true ;;
    --help|-h)
      echo "Usage: bash setup/install.sh [--defaults]"
      echo "  --defaults   Skip interactive prompts, use sensible defaults"
      exit 0
      ;;
  esac
done

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Output helpers ───────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Env file reader (safe alternative to sourcing) ──────────────────────────
get_env() {
  local key="$1"
  local default="${2:-}"
  local val
  val=$(grep "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true)
  echo "${val:-$default}"
}
header()  {
  echo ""
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}  $*${NC}"
  echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
  echo ""
}

# ── Prompt helper (respects --defaults) ──────────────────────────────────────
# Usage: ask "Prompt text" "default_value"  -> sets REPLY
ask() {
  local prompt="$1"
  local default="$2"
  if $USE_DEFAULTS; then
    REPLY="$default"
    return
  fi
  read -rp "$(echo -e "${BOLD}${prompt}${NC} [${DIM}${default}${NC}]: ")" REPLY
  REPLY="${REPLY:-$default}"
}

# ── Yes/No helper ────────────────────────────────────────────────────────────
# Usage: confirm "Enable X?" "y" -> returns 0 for yes, 1 for no
confirm() {
  local prompt="$1"
  local default="${2:-y}"
  if $USE_DEFAULTS; then
    [[ "$default" == "y" ]] && return 0 || return 1
  fi
  local yn
  if [[ "$default" == "y" ]]; then
    read -rp "$(echo -e "${BOLD}${prompt}${NC} [${DIM}Y/n${NC}]: ")" yn
    yn="${yn:-y}"
  else
    read -rp "$(echo -e "${BOLD}${prompt}${NC} [${DIM}y/N${NC}]: ")" yn
    yn="${yn:-n}"
  fi
  [[ "$yn" =~ ^[Yy] ]]
}

# ── Menu helper ──────────────────────────────────────────────────────────────
# Usage: menu_select "prompt" "opt1,opt2,opt3" default_index -> sets MENU_RESULT
menu_select() {
  local prompt="$1"
  IFS=',' read -ra options <<< "$2"
  local default_idx="${3:-1}"

  if $USE_DEFAULTS; then
    MENU_RESULT="${options[$((default_idx - 1))]}"
    return 0
  fi

  echo -e "\n${BOLD}${prompt}${NC}"
  for i in "${!options[@]}"; do
    local marker=" "
    if [[ $((i + 1)) -eq $default_idx ]]; then marker="*"; fi
    echo -e "  ${CYAN}${marker} $((i + 1)))${NC} ${options[$i]}"
  done
  read -rp "$(echo -e "${BOLD}Choose${NC} [${DIM}${default_idx}${NC}]: ")" choice
  choice="${choice:-$default_idx}"
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
    MENU_RESULT="${options[$((choice - 1))]}"
  else
    MENU_RESULT="${options[$((default_idx - 1))]}"
  fi
}

# ── Toggle list helper ───────────────────────────────────────────────────────
# Usage: toggle_list "prompt" "name1:default,name2:default,..." -> sets TOGGLE_RESULTS (array)
toggle_list() {
  local prompt="$1"
  IFS=',' read -ra items <<< "$2"
  local -a names=()
  local -a states=()

  for item in "${items[@]}"; do
    local name="${item%%:*}"
    local state="${item##*:}"
    names+=("$name")
    states+=("$state")
  done

  if $USE_DEFAULTS; then
    TOGGLE_RESULTS=()
    for i in "${!names[@]}"; do
      if [[ "${states[$i]}" == "on" ]]; then
        TOGGLE_RESULTS+=("${names[$i]}")
      fi
    done
    return 0
  fi

  echo -e "\n${BOLD}${prompt}${NC}"
  echo -e "${DIM}  Enter numbers to toggle, 'a' for all, 'n' for none, or press Enter to confirm.${NC}"

  while true; do
    for i in "${!names[@]}"; do
      local check=" "
      if [[ "${states[$i]}" == "on" ]]; then check="x"; fi
      echo -e "  ${CYAN}$((i + 1)))${NC} [${GREEN}${check}${NC}] ${names[$i]}"
    done
    read -rp "$(echo -e "${BOLD}Toggle${NC} [${DIM}Enter=confirm${NC}]: ")" input
    if [[ -z "$input" ]]; then
      break
    elif [[ "$input" == "a" ]]; then
      for i in "${!states[@]}"; do states[$i]="on"; done
    elif [[ "$input" == "n" ]]; then
      for i in "${!states[@]}"; do states[$i]="off"; done
    elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#names[@]} )); then
      local idx=$((input - 1))
      if [[ "${states[$idx]}" == "on" ]]; then states[$idx]="off"; else states[$idx]="on"; fi
    fi
  done

  TOGGLE_RESULTS=()
  for i in "${!names[@]}"; do
    if [[ "${states[$i]}" == "on" ]]; then
      TOGGLE_RESULTS+=("${names[$i]}")
    fi
  done
  return 0
}

###############################################################################
#  PHASE 1: Banner
###############################################################################
banner() {
  echo ""
  echo -e "${CYAN}${BOLD}"
  cat << 'BANNER'
   ___                    ____ _
  / _ \ _ __   ___ _ __  / ___| | __ ___      __
 | | | | '_ \ / _ \ '_ \| |   | |/ _` \ \ /\ / /
 | |_| | |_) |  __/ | | | |___| | (_| |\ V  V /
  \___/| .__/ \___|_| |_|\____|_|\__,_| \_/\_/
       |_|
BANNER
  echo -e "${NC}"
  echo -e "  ${BOLD}OpenClaw Brain${NC} v${VERSION} — Autonomous Agent Framework"
  echo -e "  ${DIM}The self-improving agent for physical humanoid robots${NC}"
  echo ""
  echo -e "  ${DIM}Repo:${NC}  ${REPO_DIR}"
  echo -e "  ${DIM}Mode:${NC}  $( $USE_DEFAULTS && echo 'Non-interactive (--defaults)' || echo 'Interactive' )"
  echo ""
}

###############################################################################
#  PHASE 2: Detect Hardware
###############################################################################
detect_hardware() {
  header "Phase 1/10 — Detecting Hardware"

  # GPU detection
  GPU_COUNT=0
  GPU_VRAM=0
  GPU_MODEL="none"
  IS_JETSON=false

  if command -v nvidia-smi &>/dev/null; then
    GPU_COUNT=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
    GPU_COUNT="${GPU_COUNT// /}"
    if [[ "$GPU_COUNT" -gt 0 ]]; then
      GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
      GPU_VRAM="${GPU_VRAM// /}"
      GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "unknown")
      GPU_MODEL="${GPU_MODEL## }"
    fi
  fi

  # Jetson detection
  if [[ -f /etc/nv_tegra_release ]] || [[ -d /sys/devices/platform/tegra-fuse ]]; then
    IS_JETSON=true
    # Jetson shares system RAM with GPU — VRAM = total RAM
    if [[ "$GPU_COUNT" -eq 0 ]]; then
      GPU_COUNT=1
      GPU_MODEL="NVIDIA Jetson (integrated)"
    fi
    # nvidia-smi on Jetson may report [N/A] for VRAM; use system RAM instead
    if [[ "$GPU_VRAM" == "0" || "$GPU_VRAM" == *"N/A"* || -z "$GPU_VRAM" ]]; then
      local ram_kb
      ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
      GPU_VRAM=$(( ram_kb / 1024 ))
    fi
  fi

  # RAM detection
  TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1024 / 1024 ))

  # CPU detection
  CPU_MODEL=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "unknown")
  CPU_CORES=$(nproc 2>/dev/null || echo "?")

  # OS detection
  OS_NAME="unknown"
  if [[ -f /etc/os-release ]]; then
    OS_NAME=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")
  fi

  # Disk detection (for /mnt/ssd or /)
  if mountpoint -q /mnt/ssd 2>/dev/null; then
    DISK_TOTAL=$(df /mnt/ssd --output=size -BG | tail -1 | tr -d ' G')
    DISK_AVAIL=$(df /mnt/ssd --output=avail -BG | tail -1 | tr -d ' G')
    DISK_PATH="/mnt/ssd"
  else
    DISK_TOTAL=$(df / --output=size -BG | tail -1 | tr -d ' G')
    DISK_AVAIL=$(df / --output=avail -BG | tail -1 | tr -d ' G')
    DISK_PATH="/"
  fi

  # Print summary
  info "CPU:   ${CPU_MODEL} (${CPU_CORES} cores)"
  info "RAM:   ${TOTAL_RAM_GB} GB"
  if $IS_JETSON; then
    info "GPU:   Jetson (${GPU_VRAM} MB unified memory)"
  elif [[ "$GPU_COUNT" -gt 0 ]]; then
    info "GPU:   ${GPU_COUNT}x ${GPU_MODEL} (${GPU_VRAM} MB VRAM each)"
  else
    info "GPU:   None detected"
  fi
  info "Disk:  ${DISK_AVAIL}G available / ${DISK_TOTAL}G total (${DISK_PATH})"
  info "OS:    ${OS_NAME}"
}

###############################################################################
#  PHASE 3: Select Hardware Profile
###############################################################################
select_profile() {
  header "Phase 2/10 — Selecting Hardware Profile"

  # Auto-detect best profile
  if $IS_JETSON; then
    AUTO_PROFILE="jetson-orin"
  elif [[ "$GPU_COUNT" -ge 2 ]]; then
    AUTO_PROFILE="multi-gpu"
  elif [[ "$GPU_COUNT" -eq 1 ]]; then
    AUTO_PROFILE="single-gpu"
  elif [[ "$GPU_COUNT" -eq 0 && "$TOTAL_RAM_GB" -ge 16 ]]; then
    AUTO_PROFILE="cpu-only"
  else
    AUTO_PROFILE="cloud"
  fi

  info "Auto-detected profile: ${BOLD}${AUTO_PROFILE}${NC}"

  menu_select "Select hardware profile:" \
    "jetson-orin,multi-gpu,single-gpu,cloud,cpu-only" \
    "$(case "$AUTO_PROFILE" in
        jetson-orin) echo 1;;
        multi-gpu)   echo 2;;
        single-gpu)  echo 3;;
        cloud)       echo 4;;
        cpu-only)    echo 5;;
      esac)"

  HARDWARE_PROFILE="$MENU_RESULT"
  success "Hardware profile: ${HARDWARE_PROFILE}"

  # Load profile overrides if the file exists
  PROFILE_FILE="${PROFILES_DIR}/${HARDWARE_PROFILE}.env"
  if [[ -f "$PROFILE_FILE" ]]; then
    info "Loading profile overrides from ${PROFILE_FILE}"
  fi
}

###############################################################################
#  PHASE 4: Choose Components
###############################################################################
choose_components() {
  header "Phase 3/10 — Selecting Components"

  # Default components vary by profile
  local pg_default="on"
  local es_default="on"
  local redis_default="on"
  local ragflow_default="on"
  local memos_default="on"
  local surfsense_default="on"
  local crawl4ai_default="on"
  local vllm_default="off"

  # Adjust defaults by profile
  case "$HARDWARE_PROFILE" in
    jetson-orin)
      es_default="on"
      surfsense_default="on"
      vllm_default="off"
      ;;
    multi-gpu)
      vllm_default="on"
      ;;
    single-gpu)
      vllm_default="on"
      ;;
    cpu-only)
      vllm_default="off"
      es_default="off"
      ragflow_default="off"
      surfsense_default="off"
      ;;
    cloud)
      vllm_default="off"
      ;;
  esac

  toggle_list "Select services to install:" \
    "postgres:${pg_default},elasticsearch:${es_default},redis:${redis_default},ragflow:${ragflow_default},memos:${memos_default},surfsense:${surfsense_default},crawl4ai:${crawl4ai_default},vllm:${vllm_default}"

  SELECTED_COMPONENTS=("${TOGGLE_RESULTS[@]}")

  echo ""
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    success "  + ${comp}"
  done

  if [[ ${#SELECTED_COMPONENTS[@]} -eq 0 ]]; then
    warn "No components selected. Only OpenClaw core will be installed."
  fi
}

###############################################################################
#  PHASE 5: Choose Model
###############################################################################
choose_model() {
  header "Phase 4/10 — Selecting Model"

  local default_model="nemotron-122b"
  case "$HARDWARE_PROFILE" in
    jetson-orin)  default_model="nemotron-122b" ;;
    multi-gpu)    default_model="nemotron-122b-awq" ;;
    single-gpu)   default_model="nemotron-122b-awq" ;;
    cpu-only)     default_model="none (external API)" ;;
    cloud)        default_model="none (external API)" ;;
  esac

  menu_select "Select inference model:" \
    "nemotron-122b (GGUF for llama.cpp),nemotron-122b-awq (quantized for vLLM),custom model path,none (use external API)" \
    "$(case "$default_model" in
        nemotron-122b)          echo 1;;
        nemotron-122b-awq)      echo 2;;
        "none (external API)")  echo 4;;
        *)                      echo 1;;
      esac)"

  case "$MENU_RESULT" in
    *GGUF*)
      SELECTED_MODEL="nemotron-122b.gguf"
      INFERENCE_BACKEND="llamacpp"
      ;;
    *vLLM*)
      SELECTED_MODEL="nemotron-122b-awq"
      INFERENCE_BACKEND="vllm"
      ;;
    *custom*)
      ask "Enter model path or name" "/mnt/ssd/models/my-model"
      SELECTED_MODEL="$REPLY"
      menu_select "Inference backend for this model:" "llamacpp,vllm" 1
      INFERENCE_BACKEND="$MENU_RESULT"
      ;;
    *external*)
      SELECTED_MODEL="none"
      INFERENCE_BACKEND="external"
      ;;
  esac

  success "Model: ${SELECTED_MODEL}"
  success "Backend: ${INFERENCE_BACKEND}"
}

###############################################################################
#  PHASE 6: Choose Channel
###############################################################################
choose_channel() {
  header "Phase 5/10 — Selecting Channel"

  menu_select "How will you talk to your agent?" \
    "telegram,discord,slack,cli-only" 1

  SELECTED_CHANNEL="$MENU_RESULT"
  success "Channel: ${SELECTED_CHANNEL}"
}

###############################################################################
#  PHASE 7: Configure .env
###############################################################################
configure_env() {
  header "Phase 6/10 — Configuring Environment"

  # Copy .env.example to .env if it doesn't exist (or if user wants to reset)
  if [[ -f "$ENV_FILE" ]]; then
    if confirm "Existing .env found. Overwrite with fresh template?" "n"; then
      cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%s)"
      warn "Backed up existing .env"
      cp "$ENV_EXAMPLE" "$ENV_FILE"
    else
      info "Keeping existing .env"
    fi
  else
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    info "Created .env from template"
  fi

  # ── Generate secure defaults ───────────────────────────────────────────────
  generate_password() {
    openssl rand -base64 24 2>/dev/null | tr -d '/+=' | head -c 24 || \
      head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 24
  }

  local pg_password
  pg_password="$(generate_password)"
  local inference_key
  inference_key="$(generate_password)"
  local ragflow_key
  ragflow_key="$(generate_password)"

  # ── Set values in .env ─────────────────────────────────────────────────────
  set_env() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
      sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
      echo "${key}=${value}" >> "$ENV_FILE"
    fi
  }

  # Auto-set inference backend and model
  set_env "INFERENCE_BACKEND" "$INFERENCE_BACKEND"
  if [[ "$INFERENCE_BACKEND" == "vllm" ]]; then
    set_env "VLLM_MODEL" "$SELECTED_MODEL"
    local tp_size=1
    if [[ "$GPU_COUNT" -gt 1 ]]; then tp_size="$GPU_COUNT"; fi
    set_env "VLLM_TENSOR_PARALLEL" "$tp_size"
  elif [[ "$INFERENCE_BACKEND" == "llamacpp" ]]; then
    set_env "LLAMACPP_MODEL" "$SELECTED_MODEL"
  fi

  # Set channel
  case "$SELECTED_CHANNEL" in
    telegram)
      ask "Telegram bot token" "your-telegram-token"
      set_env "TELEGRAM_BOT_TOKEN" "$REPLY"
      ;;
    discord)
      ask "Discord bot token" "your-discord-token"
      set_env "DISCORD_BOT_TOKEN" "$REPLY"
      ;;
    slack)
      ask "Slack bot token" "your-slack-token"
      set_env "SLACK_BOT_TOKEN" "$REPLY"
      ;;
    cli-only)
      info "CLI-only mode, no channel token needed."
      ;;
  esac

  # Prompt for passwords
  info "Setting up passwords and API keys..."
  echo ""

  ask "PostgreSQL password" "$pg_password"
  local final_pg_pass="$REPLY"
  set_env "POSTGRES_PASSWORD" "$final_pg_pass"
  set_env "DATABASE_URL" "postgresql://openclaw:${final_pg_pass}@localhost:5432/openclaw"

  ask "Inference API key" "$inference_key"
  set_env "INFERENCE_API_KEY" "$REPLY"

  ask "RagFlow API key" "$ragflow_key"
  set_env "RAGFLOW_API_KEY" "$REPLY"

  # Optional API keys
  if ! $USE_DEFAULTS; then
    echo ""
    info "Optional API keys (press Enter to skip):"
    ask "Tavily API key (for web search)" "your-tavily-api-key"
    if [[ "$REPLY" != "your-tavily-api-key" ]]; then set_env "TAVILY_API_KEY" "$REPLY"; fi

    ask "GLM API key (fallback LLM)" "your-glm-api-key"
    if [[ "$REPLY" != "your-glm-api-key" ]]; then set_env "GLM_API_KEY" "$REPLY"; fi
  fi

  # Hardware profile overrides
  if [[ -f "${PROFILES_DIR}/${HARDWARE_PROFILE}.env" ]]; then
    info "Applying hardware profile overrides..."
    while IFS='=' read -r key value; do
      if [[ -z "$key" || "$key" =~ ^# ]]; then continue; fi
      set_env "$key" "$value"
    done < "${PROFILES_DIR}/${HARDWARE_PROFILE}.env"
  fi

  success ".env configured at ${ENV_FILE}"
}

###############################################################################
#  PHASE 8: Prerequisites Check
###############################################################################
check_prerequisites() {
  header "Phase 7/10 — Checking Prerequisites"

  local missing=()

  # Docker
  if command -v docker &>/dev/null; then
    local docker_version
    docker_version=$(docker --version 2>/dev/null | head -1)
    success "Docker: ${docker_version}"
  else
    missing+=("docker")
    error "Docker not found"
  fi

  # Docker Compose (v2 plugin)
  if docker compose version &>/dev/null 2>&1; then
    local compose_version
    compose_version=$(docker compose version 2>/dev/null | head -1)
    success "Docker Compose: ${compose_version}"
  else
    missing+=("docker-compose-plugin")
    error "Docker Compose v2 not found"
  fi

  # Node.js
  if command -v node &>/dev/null; then
    local node_version
    node_version=$(node --version 2>/dev/null)
    success "Node.js: ${node_version}"
  else
    missing+=("nodejs")
    error "Node.js not found"
  fi

  # npm
  if command -v npm &>/dev/null; then
    success "npm: $(npm --version 2>/dev/null)"
  else
    missing+=("npm")
    error "npm not found"
  fi

  # git
  if command -v git &>/dev/null; then
    success "git: $(git --version 2>/dev/null)"
  else
    missing+=("git")
    error "git not found"
  fi

  # nvidia-smi (optional)
  if [[ "$GPU_COUNT" -gt 0 ]]; then
    if command -v nvidia-smi &>/dev/null; then
      success "nvidia-smi: available"
    else
      warn "nvidia-smi not found (GPU features may not work)"
    fi
  fi

  # NVIDIA Container Toolkit (for GPU containers)
  if [[ "$GPU_COUNT" -gt 0 ]]; then
    if docker info 2>/dev/null | grep -qi nvidia; then
      success "NVIDIA Container Toolkit: available"
    else
      warn "NVIDIA Container Toolkit not detected. GPU containers may fail."
      warn "Install: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
    fi
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    error "Missing required tools: ${missing[*]}"
    echo ""
    info "Install missing dependencies:"
    for tool in "${missing[@]}"; do
      case "$tool" in
        docker)
          echo "  curl -fsSL https://get.docker.com | sh"
          ;;
        docker-compose-plugin)
          echo "  sudo apt-get install -y docker-compose-plugin"
          ;;
        nodejs|npm)
          echo "  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
          echo "  sudo apt-get install -y nodejs"
          ;;
        git)
          echo "  sudo apt-get install -y git"
          ;;
      esac
    done
    echo ""
    if ! confirm "Continue anyway? (some steps may fail)" "n"; then
      error "Aborting. Install missing dependencies and re-run."
      exit 1
    fi
  fi
}

###############################################################################
#  PHASE 9: Start Services (Docker Compose)
###############################################################################
start_services() {
  header "Phase 8/10 — Starting Services"

  cd "$REPO_DIR"

  # Build the list of services to start from the nova compose file
  local services_to_start=()
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    case "$comp" in
      postgres|elasticsearch|redis|ragflow|memos|surfsense|crawl4ai)
        services_to_start+=("$comp")
        ;;
    esac
  done

  if [[ ${#services_to_start[@]} -gt 0 ]]; then
    info "Starting brain services: ${services_to_start[*]}"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_NOVA" up -d "${services_to_start[@]}" || {
      error "Failed to start some brain services. Check: docker compose -f $COMPOSE_NOVA logs"
      warn "Continuing with remaining setup..."
    }

    # Wait for postgres if it was started
    if printf '%s\n' "${services_to_start[@]}" | grep -q '^postgres$'; then
      info "Waiting for PostgreSQL to be ready..."
      local retries=0
      until docker compose --env-file "$ENV_FILE" -f "$COMPOSE_NOVA" exec -T postgres pg_isready -U "$(get_env POSTGRES_USER openclaw)" &>/dev/null; do
        retries=$((retries + 1))
        if [[ $retries -ge 30 ]]; then
          error "PostgreSQL did not become ready in time."
          break
        fi
        sleep 2
      done
      if [[ $retries -lt 30 ]]; then success "PostgreSQL is ready"; fi
    fi
  else
    info "No brain services selected, skipping Docker Compose for nova."
  fi

  # Start inference service if vllm is selected
  if printf '%s\n' "${SELECTED_COMPONENTS[@]}" | grep -q '^vllm$'; then
    info "Starting inference service (vLLM)..."
    if [[ "$INFERENCE_BACKEND" == "vllm" ]]; then
      docker compose --env-file "$ENV_FILE" -f "$COMPOSE_RIG" up -d || {
        error "Failed to start vLLM. Check: docker compose -f $COMPOSE_RIG logs"
      }
    else
      docker compose --env-file "$ENV_FILE" -f "$COMPOSE_RIG_LLAMA" up -d || {
        error "Failed to start llama.cpp. Check: docker compose -f $COMPOSE_RIG_LLAMA logs"
      }
    fi
  fi

  success "Docker services started"
}

###############################################################################
#  PHASE 10: Run Setup Scripts
###############################################################################
run_setup_scripts() {
  header "Phase 9/10 — Running Setup Scripts"

  cd "$REPO_DIR"

  # PostgreSQL setup (creates databases + pgvector extension)
  if printf '%s\n' "${SELECTED_COMPONENTS[@]}" | grep -q '^postgres$'; then
    info "Setting up PostgreSQL databases..."
    if timeout 60 bash "${REPO_DIR}/setup/scripts/setup-postgres.sh" 2>/dev/null; then
      success "PostgreSQL databases configured"
    else
      warn "PostgreSQL setup had issues (databases may already exist — this is OK)"
    fi
  fi

  # Obsidian vault setup
  info "Setting up Obsidian vault..."
  if bash "${REPO_DIR}/setup/scripts/setup-obsidian.sh" 2>/dev/null; then
    success "Obsidian vault configured"
  else
    warn "Obsidian setup had issues (vault may already exist — this is OK)"
  fi

  # Install OpenClaw via npm (if package.json exists)
  info "Installing OpenClaw..."
  if [[ -f "${REPO_DIR}/package.json" ]]; then
    cd "$REPO_DIR"
    npm install --production 2>/dev/null && success "npm dependencies installed" || warn "npm install had issues"
  else
    info "No package.json found — skipping npm install (this is fine for early setup)"
  fi

  # Copy workspace files
  if [[ -d "${REPO_DIR}/workspace" ]]; then
    local vault_path
    vault_path="$(get_env OBSIDIAN_VAULT_PATH /mnt/ssd/obsidian-vault)"
    local workspace_dest="${vault_path}/.openclaw"
    mkdir -p "$workspace_dest" 2>/dev/null || true
    if cp -r "${REPO_DIR}/workspace/"* "$workspace_dest/" 2>/dev/null; then
      success "Workspace files copied to ${workspace_dest}"
    else
      warn "Could not copy workspace files to ${workspace_dest}"
    fi
  fi
}

###############################################################################
#  PHASE 11: Health Check
###############################################################################
run_health_check() {
  header "Phase 10/10 — Health Check"

  if [[ -x "${REPO_DIR}/setup/scripts/health-check.sh" ]]; then
    cd "$REPO_DIR"
    bash "${REPO_DIR}/setup/scripts/health-check.sh" || true
  else
    warn "Health check script not found or not executable."
    info "You can run it later: bash setup/scripts/health-check.sh"
  fi
}

###############################################################################
#  PHASE 12: Print Success
###############################################################################
print_success() {
  echo ""
  echo -e "${GREEN}${BOLD}"
  cat << 'SUCCESS'
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║   OpenClaw Brain — Installation Complete!                 ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
SUCCESS
  echo -e "${NC}"

  echo -e "  ${BOLD}Hardware Profile:${NC}  ${HARDWARE_PROFILE}"
  echo -e "  ${BOLD}Model:${NC}             ${SELECTED_MODEL}"
  echo -e "  ${BOLD}Backend:${NC}           ${INFERENCE_BACKEND}"
  echo -e "  ${BOLD}Channel:${NC}           ${SELECTED_CHANNEL}"
  echo ""

  echo -e "  ${BOLD}Service URLs:${NC}"
  local host
  host="$(get_env NOVA_HOST localhost)"
  for comp in "${SELECTED_COMPONENTS[@]}"; do
    case "$comp" in
      postgres)       echo -e "    ${GREEN}+${NC} PostgreSQL:     postgresql://${host}:$(get_env POSTGRES_PORT 5432)" ;;
      elasticsearch)  echo -e "    ${GREEN}+${NC} Elasticsearch:  http://${host}:$(get_env ES_PORT 9200)" ;;
      redis)          echo -e "    ${GREEN}+${NC} Redis:          redis://${host}:$(get_env REDIS_PORT 6379)" ;;
      ragflow)        echo -e "    ${GREEN}+${NC} RagFlow:        http://${host}:$(get_env RAGFLOW_PORT 9380)" ;;
      memos)          echo -e "    ${GREEN}+${NC} Memos:          http://${host}:$(get_env MEMOS_PORT 5230)" ;;
      surfsense)      echo -e "    ${GREEN}+${NC} SurfSense:      http://${host}:$(get_env SURFSENSE_PORT 8000)" ;;
      crawl4ai)       echo -e "    ${GREEN}+${NC} crawl4ai:       http://${host}:$(get_env CRAWL4AI_PORT 11235)" ;;
      vllm)           echo -e "    ${GREEN}+${NC} Inference:      http://$(get_env RIG_HOST nova-rig):8080" ;;
    esac
  done

  echo ""
  echo -e "  ${BOLD}OpenClaw Gateway:${NC}   http://${host}:$(get_env OPENCLAW_PORT 18789)"
  echo ""

  echo -e "  ${BOLD}Next Steps:${NC}"
  echo -e "    1. Review your .env:            ${DIM}cat setup/.env${NC}"
  echo -e "    2. Check service logs:          ${DIM}docker compose -f setup/docker-compose.nova.yml logs -f${NC}"
  echo -e "    3. Run health check:            ${DIM}bash setup/scripts/health-check.sh${NC}"
  if [[ "$SELECTED_MODEL" != "none" ]]; then
    echo -e "    4. Ensure model is downloaded:   ${DIM}ls /mnt/ssd/models/${NC}"
  fi
  if [[ "$SELECTED_CHANNEL" == "telegram" ]]; then
    echo -e "    5. Message your Telegram bot to start chatting!"
  fi
  echo ""
  echo -e "  ${DIM}Documentation: ${REPO_DIR}/ARCHITECTURE.md${NC}"
  echo -e "  ${DIM}Re-run installer: bash setup/install.sh${NC}"
  echo ""
}

###############################################################################
#  MAIN
###############################################################################
main() {
  banner
  detect_hardware
  select_profile
  choose_components
  choose_model
  choose_channel
  configure_env
  check_prerequisites
  start_services
  run_setup_scripts
  run_health_check
  print_success
}

main "$@"

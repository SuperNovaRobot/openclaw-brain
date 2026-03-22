#!/bin/bash
# Setup Coding Skills Ecosystem for OpenClaw Brain

echo "=== Setting up Coding Skills Ecosystem ==="
echo ""

BRAIN_DIR="/mnt/ssd/openclaw-brain"
DEPS_DIR="$BRAIN_DIR/setup/deps"
SKILLS_DIR="$BRAIN_DIR/workspace/skills"

mkdir -p "$DEPS_DIR"
mkdir -p "$SKILLS_DIR"/{ecc,claude-skills,superpowers,bmad}
mkdir -p "$BRAIN_DIR/workspace/bmad-agents"

# 1. everything-claude-code (102 skills)
echo "=== 1/4: Installing everything-claude-code ==="
if [ ! -d "$DEPS_DIR/everything-claude-code" ]; then
  git clone --depth 1 https://github.com/affaan-m/everything-claude-code.git "$DEPS_DIR/everything-claude-code"
else
  echo "  Already cloned."
fi
find "$DEPS_DIR/everything-claude-code" -name "*.md" -not -name "README.md" -not -name "CHANGELOG.md" \
  -exec cp {} "$SKILLS_DIR/ecc/" \; 2>/dev/null || true
ECC_COUNT=$(find "$SKILLS_DIR/ecc" -type f 2>/dev/null | wc -l)
echo "  Installed: $ECC_COUNT files"

# 2. claude-skills (192 skills)
echo ""
echo "=== 2/4: Installing claude-skills ==="
if [ ! -d "$DEPS_DIR/claude-skills" ]; then
  git clone --depth 1 https://github.com/alirezarezvani/claude-skills.git "$DEPS_DIR/claude-skills"
else
  echo "  Already cloned."
fi
find "$DEPS_DIR/claude-skills" -name "*.md" -not -name "README.md" -not -name "CHANGELOG.md" \
  -exec cp {} "$SKILLS_DIR/claude-skills/" \; 2>/dev/null || true
CS_COUNT=$(find "$SKILLS_DIR/claude-skills" -type f 2>/dev/null | wc -l)
echo "  Installed: $CS_COUNT files"

# 3. Superpowers (14 skills)
echo ""
echo "=== 3/4: Installing Superpowers ==="
if [ ! -d "$DEPS_DIR/superpowers" ]; then
  git clone --depth 1 https://github.com/obra/superpowers.git "$DEPS_DIR/superpowers"
else
  echo "  Already cloned."
fi
find "$DEPS_DIR/superpowers" -name "*.md" -path "*/skills/*" \
  -exec cp {} "$SKILLS_DIR/superpowers/" \; 2>/dev/null || true
SP_COUNT=$(find "$SKILLS_DIR/superpowers" -type f 2>/dev/null | wc -l)
echo "  Installed: $SP_COUNT files"

# 4. BMAD Method (34 workflows + 12 agents)
echo ""
echo "=== 4/4: Installing BMAD Method ==="
if [ ! -d "$DEPS_DIR/BMAD-METHOD" ]; then
  git clone --depth 1 https://github.com/bmad-code-org/BMAD-METHOD.git "$DEPS_DIR/BMAD-METHOD"
else
  echo "  Already cloned."
fi
find "$DEPS_DIR/BMAD-METHOD" -name "*.md" -path "*workflow*" -o -name "*.md" -path "*task*" | \
  while read -r f; do cp "$f" "$SKILLS_DIR/bmad/" 2>/dev/null; done || true
find "$DEPS_DIR/BMAD-METHOD" -name "*.md" -path "*agent*" | \
  while read -r f; do cp "$f" "$BRAIN_DIR/workspace/bmad-agents/" 2>/dev/null; done || true
BMAD_WF=$(find "$SKILLS_DIR/bmad" -type f 2>/dev/null | wc -l)
BMAD_AG=$(find "$BRAIN_DIR/workspace/bmad-agents" -type f 2>/dev/null | wc -l)
echo "  Workflows: $BMAD_WF"
echo "  Agent personas: $BMAD_AG"

# Summary
echo ""
echo "========================================="
echo "Skills Ecosystem Summary"
echo "========================================="
echo "  everything-claude-code: $ECC_COUNT files"
echo "  claude-skills:          $CS_COUNT files"
echo "  superpowers:            $SP_COUNT files"
echo "  BMAD workflows:         $BMAD_WF files"
echo "  BMAD agents:            $BMAD_AG files"
TOTAL=$((ECC_COUNT + CS_COUNT + SP_COUNT + BMAD_WF + BMAD_AG))
echo "  TOTAL:                  $TOTAL files"
echo ""
echo "Skills ecosystem setup complete."

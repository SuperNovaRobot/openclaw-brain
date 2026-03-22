#!/usr/bin/env bash
# setup-picogk.sh — Wire leap71/PicoGK computational engineering for CAD design
# PicoGK is a C# SDK for parametric/lattice-based part design.
# Needs .NET runtime or Docker container. Output: STL files for 3D printing.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"

echo "=== leap71/PicoGK CAD Design Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check .NET runtime availability
echo "Checking .NET runtime..."
if command -v dotnet &>/dev/null; then
    DOTNET_VER=$(dotnet --version 2>/dev/null || echo "unknown")
    echo "[ok] .NET runtime found: $DOTNET_VER"
    # Check if .NET 8+ (required for PicoGK)
    MAJOR_VER=$(echo "$DOTNET_VER" | cut -d. -f1)
    if [ "$MAJOR_VER" -ge 8 ] 2>/dev/null; then
        echo "  [ok] .NET $MAJOR_VER meets PicoGK requirements (>= 8.0)."
    else
        echo "  [warn] PicoGK requires .NET 8.0+. Found $DOTNET_VER."
    fi
else
    echo "[info] .NET runtime not found on host."
    echo ""
    echo "  Option 1 — Install .NET SDK (recommended for dev):"
    echo "    wget https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh"
    echo "    chmod +x /tmp/dotnet-install.sh"
    echo "    /tmp/dotnet-install.sh --channel 8.0"
    echo ""
    echo "  Option 2 — Use Docker (recommended for isolation):"
    echo "    docker run -it --name picogk -v /mnt/ssd:/mnt/ssd mcr.microsoft.com/dotnet/sdk:8.0 bash"
    echo ""
fi

# Check for PicoGK repository
PICOGK_DIR="/mnt/ssd/picogk"
echo "Checking for PicoGK repository..."
if [ -d "$PICOGK_DIR" ]; then
    echo "[ok] PicoGK repository found at $PICOGK_DIR."
elif [ -d "$HOME/sickGit/PicoGK" ]; then
    PICOGK_DIR="$HOME/sickGit/PicoGK"
    echo "[ok] PicoGK repository found at $PICOGK_DIR."
else
    echo "[info] PicoGK not found locally."
    echo ""
    echo "  Clone the repository:"
    echo "    cd /mnt/ssd && git clone https://github.com/leap71/PicoGK.git picogk"
    echo ""
    echo "  Also clone PicoGKExamples for reference:"
    echo "    cd /mnt/ssd && git clone https://github.com/leap71/PicoGKExamples.git"
    echo ""
fi

# Check for OpenVDB (PicoGK dependency)
echo "Checking OpenVDB availability..."
if ldconfig -p 2>/dev/null | grep -q "libopenvdb"; then
    echo "[ok] OpenVDB shared library found."
elif dpkg -l 2>/dev/null | grep -q "libopenvdb"; then
    echo "[ok] OpenVDB package installed."
else
    echo "[info] OpenVDB not detected on host."
    echo "  PicoGK uses OpenVDB internally — it may bundle it or need:"
    echo "    sudo apt install libopenvdb-dev"
fi

# Create output directory for STL files
STL_DIR="$WORKSPACE/cad-output"
mkdir -p "$STL_DIR"
echo "[ok] Created CAD output directory: $STL_DIR"

# Create MCP server config
echo "Creating PicoGK MCP server config..."
cat > "$MCP_DIR/picogk.json" << 'MCPEOF'
{
  "name": "picogk",
  "description": "PicoGK MCP server — computational engineering and lattice-based parametric CAD design",
  "version": "1.0.0",
  "capabilities": [
    "create_lattice",
    "create_solid",
    "boolean_union",
    "boolean_subtract",
    "boolean_intersect",
    "generate_stl",
    "set_voxel_size",
    "apply_modulation",
    "preview_mesh"
  ],
  "config": {
    "runtime": "dotnet",
    "dotnet_version": "8.0+",
    "voxel_size_mm": 0.5,
    "output_dir": "/mnt/ssd/openclaw-brain/workspace/cad-output",
    "output_format": "STL",
    "coordinate_system": "right-hand, Z-up, millimeters",
    "default_units": "mm"
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-picogk.sh",
    "source": "https://github.com/leap71/PicoGK",
    "use_case": "3D printable part design, lattice structures, topology optimization",
    "future": "bambu-cli integration for direct Bambu Lab printing"
  }
}
MCPEOF
echo "[ok] Created MCP config: $MCP_DIR/picogk.json"

# Create Obsidian reference note
PROJECT_NOTE="$OBSIDIAN/projects/picogk-cad-pipeline.md"
mkdir -p "$(dirname "$PROJECT_NOTE")"
cat > "$PROJECT_NOTE" << 'OBSEOF'
---
title: PicoGK CAD Design Pipeline
tags: [cad, 3d-printing, picogk, lattice, computational-engineering, leap71]
created: 2026-03-22
---

# PicoGK CAD Design Pipeline

## Purpose
PicoGK enables the agent to design 3D printable parts using computational engineering.
Lattice-based parametric design — specify requirements, generate optimized geometry.

## Pipeline
```
Part Requirements -> PicoGK Design -> STL Output -> (Future) Bambu Lab Print
     (dims, loads,    (lattice gen,    (workspace/     (bambu-cli
      material)       optimization)    cad-output/)     direct print)
```

## Architecture
- **SDK**: PicoGK (C# / .NET 8.0+)
- **Backend**: OpenVDB for voxel operations
- **Output**: STL files in workspace/cad-output/
- **Execution**: .NET runtime on nova or Docker container

## Key Concepts
- **Voxel fields**: volumetric representation of geometry
- **Lattice structures**: lightweight, strong internal geometry
- **Boolean operations**: union, subtract, intersect solids
- **Modulation**: apply patterns, gradients, functional grading

## Related Notes
- [[arm-control.SKILL]] — custom end-effector design via PicoGK
- [[TOOLS]] — PicoGK registered as MCP tool

## Source
- https://github.com/leap71/PicoGK
- https://github.com/leap71/PicoGKExamples
- https://picogk.org/
OBSEOF
echo "[ok] Created Obsidian note: $PROJECT_NOTE"

# Verify skill file exists
if [ -f "$SKILL_DIR/cad-design.SKILL.md" ]; then
    echo "[ok] CAD design skill already exists."
else
    echo "[info] Skill file will be created separately: cad-design.SKILL.md"
fi

echo ""
echo "=== PicoGK CAD Design Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Install .NET 8.0+ SDK or use Docker (mcr.microsoft.com/dotnet/sdk:8.0)"
echo "  2. Clone PicoGK: cd /mnt/ssd && git clone https://github.com/leap71/PicoGK.git picogk"
echo "  3. Clone examples: cd /mnt/ssd && git clone https://github.com/leap71/PicoGKExamples.git"
echo "  4. Build PicoGK: cd /mnt/ssd/picogk && dotnet build"
echo "  5. Test: dotnet run --project /mnt/ssd/picogk (runs example)"
echo "  6. STL output directory: $STL_DIR"
echo "  7. Future: wire bambu-cli for direct Bambu Lab printing"

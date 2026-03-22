# CAD Design (leap71/PicoGK)

## Purpose
Computational engineering via PicoGK — design optimized 3D printable parts.
The agent can create lattice structures, parametric solids, and topology-optimized geometry.

## Technology
- **SDK**: PicoGK (C#, .NET 8.0+)
- **Backend**: OpenVDB voxel operations
- **Output**: STL files at workspace/cad-output/
- **Execution**: .NET runtime on nova or Docker container

## Design -> Simulate -> Print Pipeline

```
Requirements --> PicoGK Design --> STL File --> Slicer --> 3D Printer
(dimensions,     (lattice gen,     (workspace/   (future)   (future:
 loads,           booleans,         cad-output/)            bambu-cli)
 material)        optimization)
```

## Input: Part Requirements

| Parameter | Description | Example |
|-----------|-------------|---------|
| Dimensions | Bounding box or envelope | 50x30x20 mm |
| Loads | Forces the part must withstand | 10N downward on top face |
| Material | Target print material | PLA, PETG, TPU, Nylon |
| Infill strategy | Solid, lattice, or graded | Lattice with 2mm struts |
| Resolution | Voxel size (detail level) | 0.5 mm (default) |
| Constraints | Mounting holes, clearances | M3 bolt holes at corners |

## Output: Optimized STL

- Watertight mesh ready for slicing
- Named: `{project}-{part}-{version}.stl`
- Stored: `workspace/cad-output/`
- Metadata logged to Obsidian projects/ with [[wiki-links]]

## Core Operations

| Operation | Description |
|-----------|-------------|
| `create_lattice(params)` | Generate lattice structure (BCC, FCC, gyroid, etc.) |
| `create_solid(shape, dims)` | Create basic solid (box, cylinder, sphere, etc.) |
| `boolean_union(a, b)` | Combine two shapes |
| `boolean_subtract(a, b)` | Cut shape b from shape a |
| `boolean_intersect(a, b)` | Keep only overlapping region |
| `generate_stl(voxels, path)` | Export voxel field to STL mesh |
| `set_voxel_size(mm)` | Set resolution (smaller = more detail, slower) |
| `apply_modulation(field, fn)` | Apply functional grading or patterns |

## Lattice Types

| Type | Use Case | Strength Profile |
|------|----------|-----------------|
| BCC (body-centered cubic) | General purpose | Isotropic |
| FCC (face-centered cubic) | High strength-to-weight | Isotropic |
| Gyroid | Maximum surface area | Isotropic, self-supporting |
| Diamond | Impact absorption | Isotropic |
| Octet truss | Structural load-bearing | High stiffness |
| Custom | Agent-designed | Variable |

## Example Workflow

1. Requirement: "Design a bracket that holds the OAK-D camera to the arm"
2. Agent defines: 60x40x15mm envelope, 4x M3 mounting holes, PLA, 20N load
3. PicoGK generates: lattice-infilled bracket with bolt holes
4. Output: `workspace/cad-output/oakd-bracket-v1.stl`
5. Log: Obsidian note at projects/oakd-bracket.md with [[wiki-links]]
6. Future: send to bambu-cli for direct printing on Bambu Lab printer

## Integration
- Designs logged to Obsidian projects/ with [[wiki-links]] to related hardware notes
- STL files stored in workspace/cad-output/ with version numbering
- Design requirements can come from [[arm-control.SKILL]] (custom end-effectors)
- Design iterations tracked for self-improvement (did the part work?)
- Future: [[bambu-cli]] integration for direct Bambu Lab printing

## Rules
- All designs must be watertight (no holes in mesh) — PicoGK enforces this
- Voxel size default 0.5mm — decrease only if detail requires it (slower)
- Every design gets an Obsidian note with requirements, parameters, and result links
- Version STL files — never overwrite, always increment version
- C# / .NET runs on host or in Docker — not inside glm-server (different runtime)

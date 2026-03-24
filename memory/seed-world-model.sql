-- Seed script for world model tables
-- Run: docker exec -i nova-postgres psql -U openclaw -d openclaw < seed-world-model.sql
-- 
-- Experiment: exp/001-world-model-seed
-- Result: Compliance 0.48 → 0.68 (+0.20)
-- Date: 2026-03-24

-- Core entities
INSERT INTO memory_entities (kind, display_name, normalized_name, aliases, confidence) VALUES
('agent', 'Eve', 'eve', ARRAY['Nova assistant', 'autonomous agent'], 1.0),
('person', 'Creator', 'creator', ARRAY['SuperNova', 'William', 'magiccat'], 0.9),
('machine', 'Nova', 'nova', ARRAY['Jetson Orin', '100.113.249.57'], 1.0),
('machine', 'Nova-Rig', 'nova-rig', ARRAY['workstation', '100.76.233.80'], 1.0),
('service', 'RagFlow', 'ragflow', ARRAY['vector memory', 'RAG'], 1.0),
('service', 'Memos', 'memos', ARRAY['fast notes', 'memo service'], 1.0),
('tool', 'acpx', 'acpx', ARRAY['coding delegate'], 1.0),
('tool', 'Claude Code', 'claude-code', ARRAY['claude'], 0.9)
ON CONFLICT DO NOTHING;

-- Core beliefs
INSERT INTO memory_beliefs (entity_id, content, claim_topic, status, confidence, source_type)
SELECT id, 'Eve is an autonomous research agent built on Karpathy autoresearch concept', 'identity', 'current', 1.0, 'spec'
FROM memory_entities WHERE normalized_name = 'eve';

INSERT INTO memory_beliefs (entity_id, content, claim_topic, status, confidence, source_type)
SELECT id, 'Creator built and operates Eve with hands-off approach', 'origin', 'current', 0.9, 'spec'
FROM memory_entities WHERE normalized_name = 'creator';

INSERT INTO memory_beliefs (entity_id, content, claim_topic, status, confidence, source_type)
SELECT id, 'Eve runs on Jetson Orin 64GB with CUDA 12.6', 'hardware', 'current', 1.0, 'spec'
FROM memory_entities WHERE normalized_name = 'nova';

-- Core facts
INSERT INTO memory_facts (subject_id, predicate, object_text, confidence, importance)
SELECT id, 'runs_on', 'Jetson Orin 64GB', 1.0, 0.9
FROM memory_entities WHERE normalized_name = 'eve';

INSERT INTO memory_facts (subject_id, predicate, object_text, confidence, importance)
SELECT id, 'uses_model', 'glm-5 (Nemotron 122B)', 1.0, 0.9
FROM memory_entities WHERE normalized_name = 'eve';

INSERT INTO memory_facts (subject_id, predicate, object_text, confidence, importance)
SELECT id, 'served_by', '8x RTX 3090 on nova-rig', 1.0, 0.8
FROM memory_entities WHERE normalized_name = 'eve';

INSERT INTO memory_facts (subject_id, predicate, object_text, confidence, importance)
SELECT id, 'gateway_port', '18789', 1.0, 0.9
FROM memory_entities WHERE normalized_name = 'nova';

ALTER TABLE questions ADD COLUMN IF NOT EXISTS manual_grading_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE questions ADD COLUMN IF NOT EXISTS manual_grading_autograde_score_weight DOUBLE PRECISION DEFAULT NULL;
ALTER TABLE questions ADD COLUMN IF NOT EXISTS manual_grading_manual_score_weight DOUBLE PRECISION DEFAULT NULL;

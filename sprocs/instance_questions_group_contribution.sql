DROP FUNCTION IF EXISTS instance_questions_group_contribution(bigint);

CREATE OR REPLACE FUNCTION
    instance_questions_group_contribution ( 
        a_id bigint
    ) 
    RETURNS TABLE(
        assessment_label text,
        assessment_instance_id bigint,
        instance_question_id bigint,
        contribution bigint[]
    )
AS $$
BEGIN
    RETURN query
        WITH
        event_log AS (
            (
                SELECT
                    'Submission'::TEXT AS event_name,
                    v.date,
                    u.user_id AS user_id,
                    ai.id as ai_id,
                    iq.assessment_question_id as iq_id 
                FROM
                    submissions AS s
                    JOIN variants AS v ON (v.id = s.variant_id)
                    JOIN instance_questions AS iq ON (iq.id = v.instance_question_id)
                    JOIN assessment_instances AS ai ON (iq.assessment_instance_id = ai.id)
                    LEFT JOIN users AS u ON (u.user_id = s.user_id)
                WHERE
                    ai.id = a_id
            )
            UNION
            (
                SELECT
                    'View variant'::TEXT AS event_name,
                    pvl.date,
                    u.user_id AS user_id,
                    ai.id as ai_id,
                    iq.assessment_question_id as iq_id
                FROM
                    page_view_logs AS pvl
                    JOIN variants AS v ON (v.id = pvl.variant_id)
                    JOIN instance_questions AS iq ON (iq.id = v.instance_question_id)
                    JOIN questions AS q ON (q.id = pvl.question_id)
                    JOIN users AS u ON (u.user_id = pvl.user_id)
                    JOIN assessment_instances AS ai ON (ai.id = pvl.assessment_instance_id)
                WHERE
                    pvl.assessment_id = a_id
                    AND pvl.page_type = 'studentInstanceQuestion'
            )
        ),
        group_members AS (
            SELECT
                gu.user_id AS user_id,
                ai.id AS ai_id
            FROM
                assessments AS a
                JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
                JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
                JOIN assessment_instances AS ai ON (ai.assessment_id = a.id)
                LEFT JOIN group_users AS gu ON (gu.group_id = ai.group_id)
            WHERE
                ai.id = a_id
        ),
        rw_contribution AS (
            (
                SELECT
                    el.user_id as user_id,
                    el.ai_id as ai_id,
                    el.iq_id as iq_id,
                    COUNT(el.event_name) as contribution
                FROM
                    event_log AS el
                GROUP BY
                    el.user_id,
                    el.ai_id,
                    el.iq_id
            )
        ),
        rw_contribution_padded AS (
            (
                SELECT
                    gm.user_id as user_id,
                    gm.ai_id as ai_id,
                    CASE WHEN rwc.iq_id is NULL THEN 0 ELSE rwc.iq_id END AS iq_id,
                    CASE WHEN rwc.contribution is NULL THEN 0 ELSE rwc.contribution END AS contribution
                FROM
                    group_members as gm
                LEFT JOIN rw_contribution as rwc
                    ON gm.user_id = rwc.user_id
                ORDER BY gm.user_id
            )
        ),
        rw_contribution_arr AS (
            (
                SELECT
                    rc.ai_id as ai_id,
                    rc.iq_id as iq_id,
                    array_agg(rc.contribution) as contribution
                FROM
                    rw_contribution_padded as rc
                GROUP BY
                    rc.ai_id,
                    rc.iq_id
            )
        ),
        question_instances_info AS (
            (
                SELECT
                    (aset.name || ' ' || a.number) AS assessment_label,
                    ai.id AS assessment_instance_id, 
                    iq.assessment_question_id AS instance_question_id
                FROM
                    assessments AS a
                    JOIN course_instances AS ci ON (ci.id = a.course_instance_id)
                    JOIN assessment_sets AS aset ON (aset.id = a.assessment_set_id)
                    JOIN assessment_instances AS ai ON (ai.assessment_id = a.id)
                    JOIN instance_questions AS iq ON (iq.assessment_instance_id= ai.id)
                    LEFT JOIN group_info(a_id) AS gi ON (gi.id = ai.group_id)
                    LEFT JOIN users AS u ON (u.user_id = ai.user_id)
                    LEFT JOIN enrollments AS e ON (e.user_id = u.user_id AND e.course_instance_id = a.course_instance_id)
                WHERE
                    ai.id = a_id
                ORDER BY
                    e.role DESC, u.uid, u.user_id, ai.number, ai.id, iq.assessment_question_id
            )
        )
        SELECT
            qi.assessment_label AS assessment_label,
            qi.assessment_instance_id AS assessment_instance_id,
            qi.instance_question_id AS instance_question_id,
            ca.contribution AS contribution
        FROM
            question_instances_info AS qi 
            JOIN rw_contribution_arr AS ca ON (qi.assessment_instance_id = ca.ai_id) AND (qi.instance_question_id = ca.iq_id);

END;
$$ LANGUAGE plpgsql STABLE;
use sql_and_tableau;
/*
    Career Track Analysis – Data Extraction with SQL
    ------------------------------------------------
    This query joins enrollment and track information, 
    assigns unique identifiers to each student–track pair,
    determines whether the track was completed, 
    calculates the number of days needed for completion,
    and categorizes students into completion buckets.
*/

SELECT 
    student_track_id,
    student_id,
    track_name,
    date_enrolled,
    date_completed,
    track_completed,
    days_for_completion,

    CASE
        WHEN days_for_completion = 0 THEN 'Same day'
        WHEN days_for_completion BETWEEN 1 AND 7 THEN '1 to 7 days'
        WHEN days_for_completion BETWEEN 8 AND 30 THEN '8 to 30 days'
        WHEN days_for_completion BETWEEN 31 AND 60 THEN '31 to 60 days'
        WHEN days_for_completion BETWEEN 61 AND 90 THEN '61 to 90 days'
        WHEN days_for_completion BETWEEN 91 AND 365 THEN '91 to 365 days'
        WHEN days_for_completion > 365 THEN '366+ days'
        ELSE NULL
    END AS completion_bucket

FROM (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY student_id, track_name DESC) AS student_track_id,
        e.student_id,
        i.track_name,
        e.date_enrolled,
        e.date_completed,
        IF(e.date_completed IS NULL, 0, 1) AS track_completed,
        DATEDIFF(e.date_completed, e.date_enrolled) AS days_for_completion
    FROM career_track_student_enrollments e
    JOIN career_track_info i 
        ON e.track_id = i.track_id
) AS a;



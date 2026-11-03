-- =============================================================================
-- Eval benchmark seed data (DDL lives in 09d_eval_benchmark.sql)
-- =============================================================================

ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = nas_sim;
-- Benchmark operator identity: reuse dev.operator from 99_seed_reference.sql
MERGE INTO global_configuration t
USING (SELECT 'eval.benchmark.operator_user_id' AS config_key FROM dual) s
ON (t.config_key = s.config_key)
WHEN MATCHED THEN UPDATE SET
    config_value = '00000000-0000-0000-0000-000000000100',
    updated_at = SYSTIMESTAMP
WHEN NOT MATCHED THEN INSERT (config_key, config_value, value_type, description)
VALUES (
    'eval.benchmark.operator_user_id',
    '00000000-0000-0000-0000-000000000100',
    'STRING',
    'User id used by the in-process eval runner for workflow audit fields');

-- V1 benchmark catalog
MERGE INTO eval_benchmark t
USING (SELECT 'b0000001-0001-4001-8001-000000000001' AS benchmark_id FROM dual) s
ON (t.benchmark_id = s.benchmark_id)
WHEN NOT MATCHED THEN INSERT (
    benchmark_id, benchmark_code, title, description, version)
VALUES (
    'b0000001-0001-4001-8001-000000000001',
    'AVIATION_V1',
    'Aviation Simulation Benchmark v1',
    'Read-only comprehension and operator workflow tasks against the Upper Midwest corridor scenario.',
    '1.0');

MERGE INTO eval_model_profile t
USING (SELECT 'p0000001-0001-4001-8001-000000000001' AS profile_id FROM dual) s
ON (t.profile_id = s.profile_id)
WHEN NOT MATCHED THEN INSERT (
    profile_id, profile_code, display_name, provider_code, model_id, secret_ref, config_json,
    supports_tools, supports_vision)
VALUES (
    'p0000001-0001-4001-8001-000000000001',
    'FAKE_DETERMINISTIC',
    'Fake Deterministic Provider',
    'FAKE',
    'fake-v1',
    NULL,
    '{"scriptVersion":"1"}',
    'Y', 'N');

-- Task 1: KDSM outage comprehension
MERGE INTO eval_task t
USING (SELECT 't0000001-0001-4001-8001-000000000001' AS task_id FROM dual) s
ON (t.task_id = s.task_id)
WHEN NOT MATCHED THEN INSERT (
    task_id, benchmark_id, task_code, title, task_type, prompt_text,
    rubric_json, expected_outcome_json, precondition_json, isolation_json, sort_order)
VALUES (
    't0000001-0001-4001-8001-000000000001',
    'b0000001-0001-4001-8001-000000000001',
    'KDSM_OUTAGE_SUMMARY',
    'Explain KDSM facility outage',
    'READ_ONLY',
    'Using the simulation data, explain why KDSM is degraded and which navaid is unavailable. Mention ILS RWY 13.',
    '{"criteria":["Identifies ILS RWY 13 outage","Mentions degraded facility status","References glide slope or Cat I unavailability"]}',
    '{"answerMustContain":["ILS","13","degraded"],"toolCalls":["get_facility_detail"],"facilityCode":"KDSM"}',
    '{"requiresClockPaused":true}',
    '{"mutatesSimulation":false}',
    1);

-- Task 2: UA2847 delay
MERGE INTO eval_task t
USING (SELECT 't0000002-0001-4001-8001-000000000002' AS task_id FROM dual) s
ON (t.task_id = s.task_id)
WHEN NOT MATCHED THEN INSERT (
    task_id, benchmark_id, task_code, title, task_type, prompt_text,
    rubric_json, expected_outcome_json, precondition_json, isolation_json, sort_order)
VALUES (
    't0000002-0001-4001-8001-000000000002',
    'b0000001-0001-4001-8001-000000000001',
    'UA2847_DELAY_REASON',
    'Explain UA2847 ground delay',
    'READ_ONLY',
    'Why is flight UA2847 delayed on the ground at DSM? Cite the operational reason from the scenario.',
    '{"criteria":["Identifies UA2847","States ground delay","Mentions navaid or ILS outage impact"]}',
    '{"answerMustContain":["UA2847","delay","ILS"],"toolCalls":["get_flight_detail"],"flightNumber":"UA2847","operationPhase":"DELAYED"}',
    '{"requiresClockPaused":true}',
    '{"mutatesSimulation":false}',
    2);

-- Task 3: DL1920 approach
MERGE INTO eval_task t
USING (SELECT 't0000003-0001-4001-8001-000000000003' AS task_id FROM dual) s
ON (t.task_id = s.task_id)
WHEN NOT MATCHED THEN INSERT (
    task_id, benchmark_id, task_code, title, task_type, prompt_text,
    rubric_json, expected_outcome_json, precondition_json, isolation_json, sort_order)
VALUES (
    't0000003-0001-4001-8001-000000000003',
    'b0000001-0001-4001-8001-000000000001',
    'DL1920_APPROACH_STATUS',
    'Summarize DL1920 approach situation',
    'READ_ONLY',
    'Summarize DL1920 current phase and why it is holding or delayed approaching DSM.',
    '{"criteria":["Identifies DL1920","Mentions APPROACH or holding","References weather and/or ILS outage"]}',
    '{"answerMustContain":["DL1920","APPROACH"],"toolCalls":["get_flight_detail"],"flightNumber":"DL1920","operationPhase":"APPROACH"}',
    '{"requiresClockPaused":true}',
    '{"mutatesSimulation":false}',
    3);

-- Task 4: Approve pending path request for DL1920
MERGE INTO eval_task t
USING (SELECT 't0000004-0001-4001-8001-000000000004' AS task_id FROM dual) s
ON (t.task_id = s.task_id)
WHEN NOT MATCHED THEN INSERT (
    task_id, benchmark_id, task_code, title, task_type, prompt_text,
    rubric_json, expected_outcome_json, precondition_json, isolation_json, sort_order)
VALUES (
    't0000004-0001-4001-8001-000000000004',
    'b0000001-0001-4001-8001-000000000001',
    'APPROVE_DL1920_PATH',
    'Approve DL1920 RNAV path request',
    'OPERATOR_WORKFLOW',
    'DL1920 has a pending path request for an RNAV approach due to the ILS 13 outage. Approve the pending path request for flight operation DL1920.',
    '{"criteria":["Approves the correct pending path request","Does not approve unrelated requests"]}',
    '{"toolCalls":["approve_path_request"],"pathRequestId":"24000001-0001-4001-8001-000000000001","expectedStatus":"APPROVED"}',
    '{"entityChecks":[{"table":"flight_path_request","id":"24000001-0001-4001-8001-000000000001","field":"request_status","value":"PENDING"}]}',
    '{"mutatesSimulation":true,"fixtureIds":["24000001-0001-4001-8001-000000000001"]}',
    4);

-- Task 5: Clock step episode
MERGE INTO eval_task t
USING (SELECT 't0000005-0001-4001-8001-000000000005' AS task_id FROM dual) s
ON (t.task_id = s.task_id)
WHEN NOT MATCHED THEN INSERT (
    task_id, benchmark_id, task_code, title, task_type, prompt_text,
    rubric_json, expected_outcome_json, precondition_json, isolation_json, sort_order)
VALUES (
    't0000005-0001-4001-8001-000000000005',
    'b0000001-0001-4001-8001-000000000001',
    'CLOCK_STEP_EPISODE',
    'Pause, inspect, and step simulation clock',
    'EPISODE',
    'Pause the simulation clock, read the operational day summary, step the clock once, then summarize the clock status and sim time.',
    '{"criteria":["Pauses clock before stepping","Steps clock exactly once","Reports sim time after step"]}',
    '{"toolCalls":["pause_clock","get_operational_day","step_clock"],"minStepCount":1}',
    '{"requiresClockPaused":false}',
    '{"mutatesSimulation":true,"clockTools":true}',
    5);

COMMIT;

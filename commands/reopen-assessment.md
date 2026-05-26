---
name: torch:reopen-assessment
description: Reopen an auto-released 360 assessment by invoking the undo Lambda with calculated timeline
argument-hint: "<FRG_ID or name/email> [days] [tenant]"
---

# Reopen 360 Assessment

Reopen an auto-released 360 assessment for additional feedback collection. Calculates the correct `minimum_release_timeline` and invokes the `undo_auto_release_360_reports` Lambda.

## Arguments

Accepts flexible input:
- `<FRG_ID> <days>` -- reopen FRG by ID for N days
- `<name_or_email> <days> <tenant>` -- look up FRG by subject, then reopen for N days

If arguments are ambiguous or missing, ask the user to clarify.

## Steps

### 1. Parse input

Determine whether the first argument is a numeric FRG ID or a name/email.

- **Numeric**: treat as FRG ID. Second arg is days (default 10 if not provided).
- **Non-numeric**: treat as subject name or email. Need days and tenant name/ID. If tenant not provided, ask.

### 2. Look up FRG (if not given by ID)

Connect to the assessment-service prod database to find the FRG:

```bash
pgpass
```

Use the assessment-service database connection (look for the one on port 5432 with `assessment` in the database name, or the prod Redshift `prod_assessment` schema).

Query to find the FRG by subject email or name within the tenant:

```sql
SELECT frg.id as frg_id,
       frg.subject_viewable,
       frg.created_date,
       frg.form_configuration,
       u.email as subject_email,
       u.first_name || ' ' || u.last_name as subject_name,
       t.name as tenant_name,
       t.id as tenant_id
FROM form_response_group frg
JOIN "user" u ON u.id = frg.subject_id
JOIN form f ON f.id = frg.form_id
JOIN form_type ft ON ft.id = f.form_type_id
JOIN tenant t ON t.id = frg.tenant_id
WHERE ft.name = 'three_sixty'
  AND (u.email ILIKE '%<search>%' OR (u.first_name || ' ' || u.last_name) ILIKE '%<search>%')
  AND (t.name ILIKE '%<tenant>%' OR t.id = <tenant_id>)
ORDER BY frg.created_date DESC
LIMIT 10;
```

If multiple results, show them and ask user to pick.

### 3. Validate the FRG

Query assessment details for the selected FRG:

```sql
SELECT frg.id,
       frg.subject_viewable,
       frg.created_date,
       frg.form_configuration->>'auto_release_enabled' as auto_release_enabled,
       frg.form_configuration->>'minimum_release_timeline' as current_min_timeline,
       (SELECT EXTRACT(DAY FROM NOW() - MIN(fbr.created_date))::integer
        FROM feedback_request fbr WHERE fbr.form_response_group_id = frg.id) as days_elapsed,
       (SELECT COUNT(*) FROM feedback_request fbr
        WHERE fbr.form_response_group_id = frg.id AND fbr.is_fulfilled = true) as fulfilled_count,
       (SELECT COUNT(*) FROM feedback_request fbr
        WHERE fbr.form_response_group_id = frg.id) as total_count
FROM form_response_group frg
WHERE frg.id = <frg_id>;
```

**Verify before proceeding:**
- `subject_viewable` must be `true` (already released). If `false`, tell user it's already unreleased.
- `auto_release_enabled` should be `true`. If not, warn that manual re-release will be needed.

### 4. Calculate minimum_release_timeline

```
new_timeline = days_elapsed + requested_days
```

Where:
- `days_elapsed` = days since first feedback request was created (from query above)
- `requested_days` = number of days to keep open (from user input, default 10)

### 5. Confirm with user

Show a summary before invoking:

```
FRG:       <frg_id>
Subject:   <name> (<email>)
Tenant:    <tenant_name>
Feedback:  <fulfilled>/<total> complete (<pending> pending)
Released:  <yes/no>
Days elapsed: <days_elapsed>
Requested reopen: <requested_days> days

Will set minimum_release_timeline to <new_timeline> days.
Auto-release will re-trigger around <estimated_date>.

Proceed?
```

Wait for user confirmation.

### 6. Invoke the Lambda

```bash
aws lambda invoke \
  --function-name assessment-service-prod-undo_auto_release_360_reports \
  --payload '{"frg_ids": [<frg_id>], "minimum_release_timeline": <new_timeline>}' \
  --cli-binary-format raw-in-base64-out \
  --profile torch-cognito-kernel \
  --region us-west-2 \
  /dev/stdout
```

### 7. Report result

Show the Lambda response. Confirm success or report errors.

If successful, remind user:
- Assessment is now unreleased; subject can no longer view the report
- Pending respondents may need a reminder (check with requestor)
- Auto-release will naturally re-trigger after the timeline expires (~estimated_date)

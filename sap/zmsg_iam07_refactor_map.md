# ZMSG_IAM07 refactor map

## Scope and source of truth

- Live package: `ZSU26_GSU07_CAPSTONE`, S40 client 324.
- Existing message class: `ZMSG_IAM07` (101 active entries, including dynamic
  pass-through message `001`).
- Reviewed executable sources: lifecycle behavior pool, Firefighter behavior pool,
  seven IAM classes, three executable programs and five report includes.
- The copy-ready SE91 catalog is `sap/zmsg_iam07_catalog.csv`.

## Consolidation decisions

| Current variants | Target |
|---|---|
| `Invalid mode. Use I, E, or B only.` / `Invalid mode. Use I/E/B only.` | `020` |
| `Please select at least one user` / `Select at least one user before checking SoD` | `011` |
| Two occurrences of `No roles found for selected users` | `015` |
| Two occurrences of `Save failed.` | `013` |
| Firefighter-role and SoD-rule save-success texts | `014` |
| Role1/Role2 not-found rule validation | `310` |
| Owner/backup-owner not found in `USR02` | `307` |
| Review-reason mandatory variants | `021` |
| Audit UUID/audit-write rollback variants | `027` |
| Inactivity, grant and revoke busy-user variants | `026` |
| Final Firefighter grant/revoke result envelopes | `218` |

Only runtime data such as user, role, rule, grant, dates and counts uses
`&1`-`&4`. Translatable business nouns are not passed as placeholders.

## ABAP replacement patterns

### RAP reported message

```abap
APPEND VALUE #(
  %tky = ls_request-%tky
  %msg = new_message(
    id       = 'ZMSG_IAM07'
    number   = '100'
    severity = if_abap_behv_message=>severity-error ) )
  TO reported-request.
```

With variables:

```abap
%msg = new_message(
  id       = 'ZMSG_IAM07'
  number   = '105'
  severity = if_abap_behv_message=>severity-error
  v1       = lv_duplicate_req_id
  v2       = ls_request-TargetUser )
```

Do not use authorization object `ZIAM_REQ` as a message ID. The two occurrences
in `sap/zbp_i_iam_lreq_hdr_ff.local.abap` must use `ZMSG_IAM07`.

### Executable report message

```abap
MESSAGE e020(zmsg_iam07).
MESSAGE s014(zmsg_iam07).
MESSAGE w019(zmsg_iam07) WITH lv_cnt.
```

Keep `DISPLAY LIKE` only where the existing control flow intentionally uses a
non-terminating `S` or `I` message displayed as warning/error.

### Return text or background log

```abap
MESSAGE ID 'ZMSG_IAM07' TYPE 'S' NUMBER '218'
  WITH ls_grant-grant_id ls_grant-last_message
  INTO DATA(lv_message).

add_log(
  iv_level = 'I'
  iv_text  = lv_message ).
```

The message type used with `INTO` does not control UI flow. Continue to keep the
actual severity in `iv_level`, RAP severity or the caller's `MESSAGE` statement.

## Deliberate exclusions

- UI5 currently has 31 hard-coded `MessageBox`/`MessageToast` call sites. Move
  those texts to `webapp/i18n/i18n.properties`; UI5 cannot consume SE91/T100
  directly.
- HTML mail subject/body remains a mail template concern, not a T100 message.
- BAPI return messages and exception `get_text( )` values retain their original
  SAP message classes. Use `001` only when RAP must pass such external text.
- Audit `old_value`/`new_value` payloads remain structured technical data.
- ALV headers, toolbar labels and popup titles belong in program text symbols,
  not the message class.

## Safe implementation order

1. Fill and activate `ZMSG_IAM07` from the CSV catalog.
2. Replace messages in `ZCL_IAM_FF_SERVICE` and `ZCL_IAM_SOD_ADMIN`.
3. Replace RAP messages in `ZBP_I_IAM_LREQ_HDR`.
4. Replace report messages in `ZPG_IAM_CFG_MAINT`, `ZPG_RUSERS_02`,
   `ZPG_IAM_RUSERS_SOD_I01` and `ZPG_IAM_ACCESS_CONTROL`.
5. Replace background log/status messages in `ZCL_IAM_ACCESS_CTRL`.
6. Run syntax/ATC and regression for Joiner, Mover, Leaver, Firefighter,
   inactivity, expiry and SoD remediation.
7. Move UI5 texts to i18n as a separate change set and rebuild the app.

## Implementation status (2026-08-05)

- Local refactor completed for all backend objects listed above.
- S40 syntax check: no errors for the three classes, three reports and the SoD
  include; the active lifecycle behavior implementation has one pre-existing
  performance warning and no syntax error.
- Live update is pending because `DEV-182` has no open Workbench request/task.
  No live source was changed by the failed update attempt.

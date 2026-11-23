# Module: `kms`

One customer-managed KMS key per environment (rotation on), with an alias `alias/<name>`.
The key policy lets the account administer the key and lets **CloudWatch Logs** in this
region/account encrypt log groups with it.

The stack **skips this module** when `existing_kms_key_arn` is set (a key CloudOne provides).
A shared key must also allow CloudWatch Logs, or log group creation fails.

| Input | Default | |
|---|---|---|
| `name` | none | Alias and description prefix |
| `deletion_window_in_days` | `30` | 7–30; validated |

Outputs: `key_arn`, `key_id`

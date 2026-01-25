# Runbook

## Retrain failed
- Inspect Step Functions execution input/output.
- Check training lambda logs for errors.
- Re-run pipeline after fix.

## Drift false positive
- Validate baseline profile.
- Adjust drift threshold.
- Recompute current profile with larger window.

## Model rollback
- Set inference model key to previous version.
- Deploy lambda config update.
- Smoke test /predict.

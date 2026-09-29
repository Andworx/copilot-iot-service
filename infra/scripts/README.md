# Deployment safety checks

`check_network_plan.py` checks the compiled ARM template and Azure what-if result before the manual network workflow can deploy. It allows only the network resource types owned by this repository and fails closed on service declarations, public-access settings, modifications, deletions, incomplete previews and unexpected resource types. Only summary counts are printed.

Run locally with Python 3:

```powershell
python infra/scripts/check_network_plan.py template infra/main.json
python -m unittest discover -s infra/scripts -p 'test_*.py'
```

The tests cover additive success and rejection of destructive, unresolved, malformed and nested service changes. They do not simulate Azure or replace a real what-if. Update this README and the deployment runbook when the policy changes.

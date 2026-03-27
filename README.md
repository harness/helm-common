# helm-common

Library chart used by Harness Helm charts.

- **[KEDA](docs/KEDA.md)** – Event-driven autoscaling (ScaledObject, TriggerAuthentication). ScaledObject sets HPA ownership transfer by default so it can safely coexist with the library HPA.
- **[Init Containers](docs/INIT_CONTAINERS.md)** – Reusable init container templates (wait-for-directory).
- **[Testing](docs/TESTING.md)** – How we test the library (template smoke tests + helm-unittest + CI).

## Publish

Bump version of the chart src/Chart.yaml

helm package src -d charts

helm repo index charts

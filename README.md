# helm-common

Library chart used by Harness Helm charts.

- **[KEDA](docs/KEDA.md)** – Event-driven autoscaling (ScaledObject, TriggerAuthentication). ScaledObject sets HPA ownership transfer by default so it can safely coexist with the library HPA.
- **[Testing](docs/TESTING.md)** – How we test the library (template smoke tests + helm-unittest + CI).
- **[Engine resources](docs/ENGINE_RESOURCES.md)** – Render Harness Engine CRs (`Schedule`) from `engineResources` values.

## Publish

Bump version of the chart src/Chart.yaml

helm package src -d charts

helm repo index charts

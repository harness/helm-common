# Using KEDA with harness-common

The library chart provides templates for [KEDA](https://keda.sh/) (Kubernetes Event-driven Autoscaler) so you can scale Deployments or StatefulSets from event-driven triggers (Kafka, SQS, Prometheus, cron, etc.) instead of or in addition to CPU/memory. Any KEDA scaler and trigger spec is supported via passthrough values.

---

## Configuration (values)

Use `keda` in your chart values (or under a component key when using `configPath`). Precedence matches HPA/PDB: **global** &lt; root **keda** &lt; **configPath.keda**.

```yaml
# Optional global defaults
global:
  keda:
    enabled: false
    scaledObject:
      minReplicaCount: 0
      maxReplicaCount: 100
      pollingInterval: 30
      cooldownPeriod: 300

# Per-chart or per-deployment (when using configPath)
keda:
  enabled: false
  scaledObject:
    minReplicaCount: 0
    maxReplicaCount: 100
    pollingInterval: 30
    cooldownPeriod: 300
    initialCooldownPeriod: 0
    # optional: idleReplicaCount, scaleTargetRef.apiVersion/kind/name/envSourceContainerName
    annotations: {}   # e.g. scaledobject.keda.sh/transfer-hpa-ownership: "true"
    triggers: []     # Required when enabled — list of KEDA trigger specs. Use multiple entries to scale on several metrics; HPA scales to the max desired replicas across all triggers.
    fallback: {}     # Optional. failureThreshold, replicas, behavior
    advanced: {}    # Optional. restoreToOriginalReplicaCount, horizontalPodAutoscalerConfig, scalingModifiers
  triggerAuthentication:
    create: false
    name: ""         # default: {release-fullname}-keda-auth
    spec: {}         # passthrough: podIdentity, secretTargetRef, env, etc.
```

For multiple **deployments** (e.g. api + worker), use one ScaledObject per deployment: put `keda` under each component and use `configPath` in the template includes (see below).

**One ScaledObject per deployment, multiple triggers in it.** Do not create multiple ScaledObjects for the same deployment. To scale on several metrics (e.g. queue depth + Prometheus + cron), add multiple entries to `scaledObject.triggers` in the same ScaledObject. KEDA sends all trigger values to the HPA, which scales to the **maximum** desired replica count across triggers (and activates from 0→1 when any trigger is active).

---

## Templates

### ScaledObject

Include in a template file (e.g. `templates/keda-scaledobject.yaml`):

```yaml
{{- include "harnesscommon.keda.renderScaledObject" (dict
    "ctx" .
    "kind" "Deployment"
    "nameOverride" "my-scaler"
    "targetRefNameOverride" "my-app"
    "configPath" .Values.myComponent
) }}
```

- **ctx** – Root context (`.`).
- **kind** – Target resource kind: `Deployment`, `StatefulSet`, or a custom resource that supports `/scale`. Default `Deployment`.
- **nameOverride** – Name of the ScaledObject resource (default: chart fullname).
- **targetRefNameOverride** – `scaleTargetRef.name` (default: same as name).
- **configPath** – Values path for this workload (e.g. `.Values.worker`). Omit to use root `$.Values.keda`.

The helper only renders when `keda.enabled` is true and `keda.scaledObject.triggers` is set.

### TriggerAuthentication (optional)

Include when you need the chart to create a TriggerAuthentication (e.g. for GCP workload identity or secret refs):

```yaml
{{- include "harnesscommon.keda.renderTriggerAuthentication" (dict
    "ctx" .
    "nameOverride" "my-auth"
    "configPath" .Values.myComponent
) }}
```

Renders only when `keda.triggerAuthentication.create` is true and `keda.triggerAuthentication.spec` is set. Use the same name in your trigger’s `authenticationRef.name`.

---

## Examples

### Single deployment, Kafka trigger

```yaml
# values
keda:
  enabled: true
  scaledObject:
    minReplicaCount: 0
    maxReplicaCount: 20
    triggers:
      - type: kafka
        metadata:
          bootstrapServers: kafka:9092
          consumerGroup: my-group
          topic: my-topic
          lagThreshold: "10"
```

```yaml
# templates/keda-scaledobject.yaml
{{- include "harnesscommon.keda.renderScaledObject" (dict "ctx" . "kind" "Deployment") }}
```

### Multiple triggers (scale on several metrics)

Use **one** ScaledObject and list all metrics in `triggers`. The deployment scales to the highest replica count required by any trigger.

```yaml
keda:
  enabled: true
  scaledObject:
    minReplicaCount: 0
    maxReplicaCount: 20
    triggers:
      - type: prometheus
        metadata:
          serverAddress: http://prometheus:9090
          metricName: request_queue_depth
          threshold: "50"
      - type: kafka
        metadata:
          bootstrapServers: kafka:9092
          consumerGroup: my-group
          topic: jobs
          lagThreshold: "10"
      - type: cron
        metadata:
          timezone: America/New_York
          start: 0 9 * * 1-5
          end: 0 17 * * 1-5
          desiredReplicas: "5"
```

### Multi-deployment (worker) with configPath

```yaml
# values
worker:
  keda:
    enabled: true
    scaledObject:
      minReplicaCount: 1
      maxReplicaCount: 50
      triggers:
        - type: prometheus
          metadata:
            serverAddress: http://prometheus:9090
            metricName: queue_depth
            threshold: "100"
```

```yaml
# templates/worker-keda-scaledobject.yaml
{{- include "harnesscommon.keda.renderScaledObject" (dict
    "ctx" .
    "kind" "Deployment"
    "nameOverride" "worker"
    "targetRefNameOverride" "worker"
    "configPath" .Values.worker
) }}
```

### TriggerAuthentication (e.g. SQS with credentials)

```yaml
keda:
  enabled: true
  triggerAuthentication:
    create: true
    name: my-app-sqs-auth
    spec:
      secretTargetRef:
        - parameter: awsAccessKeyID
          name: aws-secrets
          key: AWS_ACCESS_KEY_ID
        - parameter: awsSecretAccessKey
          name: aws-secrets
          key: AWS_SECRET_ACCESS_KEY
  scaledObject:
    triggers:
      - type: aws-sqs-queue
        authenticationRef:
          name: my-app-sqs-auth
        metadata:
          queueURL: https://sqs.<region>.amazonaws.com/<account>/<queue-name>
          queueLength: "5"
```

### Prometheus (or GMP) with GCP workload identity and HPA behavior

TriggerAuthentication with `podIdentity.provider: gcp` and a ScaledObject with a Prometheus trigger and custom scale-up/scale-down behavior:

```yaml
# templates/keda-trigger-authentication.yaml
{{- include "harnesscommon.keda.renderTriggerAuthentication" (dict "ctx" .) }}

# templates/keda-scaledobject.yaml
{{- include "harnesscommon.keda.renderScaledObject" (dict
    "ctx" .
    "kind" "Deployment"
    "nameOverride" "my-app-pending-connections"
    "targetRefNameOverride" "my-app"
) }}
```

```yaml
# values — use your own Prometheus/GMP URL, query, and thresholds
keda:
  enabled: true
  triggerAuthentication:
    create: true
    name: prometheus-gcp-auth
    spec:
      podIdentity:
        provider: gcp
  scaledObject:
    minReplicaCount: 1
    maxReplicaCount: 8
    annotations: {}
    advanced:
      horizontalPodAutoscalerConfig:
        behavior:
          scaleUp:
            stabilizationWindowSeconds: 15
            policies:
              - type: Pods
                value: 2
                periodSeconds: 15
          scaleDown:
            stabilizationWindowSeconds: 180
            policies:
              - type: Pods
                value: 1
                periodSeconds: 60
    triggers:
      - type: prometheus
        authenticationRef:
          name: prometheus-gcp-auth
        metadata:
          serverAddress: https://your-prometheus-or-gmp-endpoint
          query: |
            sum(your_metric_name{namespace="your-namespace",label="value"})
          threshold: "50"
          activationThreshold: "5"
```

For a multi-deployment chart, put the same `keda` structure under a component key and pass `configPath: .Values.myComponent` in the includes.

---

## HPA coexistence

KEDA works by creating and owning an HPA for the target. **The library’s ScaledObject template sets `scaledobject.keda.sh/transfer-hpa-ownership: "true"` by default**, so if an HPA already exists for the same deployment (e.g. from `harnesscommon.hpa.renderHPA`), KEDA will take it over instead of creating a second one. That makes it safe to have both templates in the same chart or to migrate from HPA to KEDA without removing the HPA first.

- **Recommended:** For a given deployment, enable either KEDA or HPA, not both, to keep intent clear.
- If both are enabled for the same target, KEDA will adopt the existing HPA; you can override the annotation via `keda.scaledObject.annotations` if needed.

---

## References

- [KEDA ScaledObject spec](https://keda.sh/docs/2.18/reference/scaledobject-spec/)
- [KEDA scalers (triggers)](https://keda.sh/docs/2.18/scalers/)
- [KEDA authentication](https://keda.sh/docs/2.18/concepts/authentication/)

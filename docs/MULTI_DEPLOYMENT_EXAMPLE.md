# Multi-Deployment HPA and PDB Support

This document shows how to use the updated HPA and PDB templates to support multiple deployments in a single Helm chart.

## Backward Compatibility

**Existing charts continue to work without any changes!** The templates are fully backward compatible.

### Legacy Usage (Still Supported)

```yaml
# values.yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPU: 80

pdb:
  create: true
  minAvailable: "50%"
```

```yaml
# templates/hpa.yaml
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment") }}

# templates/pdb.yaml
{{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict "ctx" .) }}
```

## New Multi-Deployment Usage

When you have multiple deployments (e.g., main API + worker), you can now use the `configPath` parameter to specify different configurations for each.

### Example: API + Worker Deployments

```yaml
# values.yaml
global:
  autoscaling:
    minReplicas: 2  # Global default for all deployments
  pdb:
    create: true

# Main API deployment configuration
api:
  autoscaling:
    enabled: true
    maxReplicas: 10
    targetCPU: 80
  pdb:
    create: true
    minAvailable: "50%"

# Worker deployment configuration
worker:
  autoscaling:
    enabled: true
    minReplicas: 1    # Override global minReplicas
    maxReplicas: 50
    targetMemory: 85
  pdb:
    create: true
    minAvailable: 1
```

```yaml
# templates/api-hpa.yaml
{{- include "harnesscommon.hpa.renderHPA" (dict
    "ctx" .
    "kind" "Deployment"
    "targetRefNameOverride" "my-api"
    "configPath" .Values.api
) }}

# templates/api-pdb.yaml
{{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict
    "ctx" .
    "configPath" .Values.api
) }}

# templates/worker-hpa.yaml
{{- include "harnesscommon.hpa.renderHPA" (dict
    "ctx" .
    "kind" "Deployment"
    "targetRefNameOverride" "my-worker"
    "configPath" .Values.worker
) }}

# templates/worker-pdb.yaml
{{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict
    "ctx" .
    "configPath" .Values.worker
) }}
```

## Value Priority Order

When both global and deployment-specific values are defined, the priority order is:

1. **Highest**: `configPath.autoscaling.minReplicas` (deployment-specific)
2. **Medium**: `global.autoscaling.minReplicas` (global default)
3. **Lowest**: `autoscaling.minReplicas` (legacy root path, only when no configPath)
4. **Default**: Hard-coded defaults (e.g., minReplicas = 2)

### Example Priority Resolution

```yaml
global:
  autoscaling:
    minReplicas: 5
    maxReplicas: 100

worker:
  autoscaling:
    enabled: true
    minReplicas: 1  # This wins for worker deployment
    # maxReplicas not defined - will use global value of 100
```

Result for worker HPA:
- `minReplicas: 1` (from configPath)
- `maxReplicas: 100` (from global)

## Mixing Legacy and New Patterns

You can have some deployments using legacy pattern and others using the new configPath pattern in the same chart:

```yaml
# values.yaml
# Legacy configuration (for main deployment)
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

# New configuration (for worker deployment)
worker:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 50
```

```yaml
# templates/main-hpa.yaml (legacy - no configPath)
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment") }}

# templates/worker-hpa.yaml (new - with configPath)
{{- include "harnesscommon.hpa.renderHPA" (dict
    "ctx" .
    "kind" "Deployment"
    "targetRefNameOverride" "worker"
    "configPath" .Values.worker
) }}
```

## Parameters Reference

### HPA Parameters

- `ctx` (required): The root context, typically `.`
- `kind` (required): Resource kind (e.g., "Deployment", "StatefulSet")
- `targetRefNameOverride` (optional): Override the target reference name
- `configPath` (optional): Custom values path for multi-deployment scenarios

### PDB Parameters

- `ctx` (required): The root context, typically `.`
- `configPath` (optional): Custom values path for multi-deployment scenarios

## Supported Configuration Values

All HPA and PDB configuration values are supported with `configPath`:

### HPA
- `enabled` - Enable/disable HPA creation
- `minReplicas` - Minimum number of replicas
- `maxReplicas` - Maximum number of replicas
- `targetCPU` - Target CPU utilization percentage (simple mode)
- `targetMemory` - Target memory utilization percentage (simple mode)
- `behavior` - Custom scaling behavior (scaleUp/scaleDown policies)
- `metrics` - **NEW!** Custom metrics array (advanced mode)
  - When specified, overrides `targetCPU` and `targetMemory`
  - Supports all metric types: Resource, ContainerResource, Pods, Object, External
  - Full control over HPA metrics configuration

### PDB
- `create` - Enable/disable PDB creation
- `minAvailable` - Minimum number/percentage of pods that must be available
- `maxUnavailable` - Maximum number/percentage of pods that can be unavailable
- `unhealthyPodEvictionPolicy` - **NEW!** Policy for evicting unhealthy pods (K8s 1.26+)
  - Values: `AlwaysAllow` or `IfHealthyBudget`
  - Controls whether unhealthy pods count against the disruption budget

## Advanced Features

### Custom Metrics (HPA)

Use the `metrics` array for advanced autoscaling scenarios:

```yaml
worker:
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 100
    # Custom metrics array - full control over HPA behavior
    metrics:
      # Resource metric (CPU)
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 75

      # Container-specific resource metric
      - type: ContainerResource
        containerResource:
          name: memory
          container: main-container
          target:
            type: Utilization
            averageUtilization: 80

      # External metric (e.g., queue depth from Prometheus)
      - type: External
        external:
          metric:
            name: queue_depth
            selector:
              matchLabels:
                queue_name: "processing-queue"
          target:
            type: AverageValue
            averageValue: "30"

      # Pods metric (custom application metric)
      - type: Pods
        pods:
          metric:
            name: requests_per_second
          target:
            type: AverageValue
            averageValue: "1000"

      # Object metric (e.g., Ingress requests)
      - type: Object
        object:
          metric:
            name: requests-per-second
          describedObject:
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            name: main-route
          target:
            type: Value
            value: "10k"
```

### Unhealthy Pod Eviction Policy (PDB)

Control how unhealthy pods are treated during disruptions (K8s 1.26+):

```yaml
api:
  pdb:
    create: true
    minAvailable: "50%"
    # AlwaysAllow: Always allow eviction of unhealthy pods
    # IfHealthyBudget: Only allow if healthy pods meet the budget
    unhealthyPodEvictionPolicy: "IfHealthyBudget"
```

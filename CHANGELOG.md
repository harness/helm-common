# HPA and PDB Template Enhancements

## Summary

This update adds significant new capabilities to the HPA and PDB templates while maintaining 100% backward compatibility. The changes enable multi-deployment scenarios and add support for advanced Kubernetes features.

## New Features

### 1. Multi-Deployment Support (`configPath` Parameter)

Both HPA and PDB templates now accept an optional `configPath` parameter, allowing charts to define multiple deployments with different autoscaling and disruption budget configurations.

**Benefits:**
- Single chart can have multiple deployments with different HPA/PDB configs
- No code duplication - use the same templates for all deployments
- Fully backward compatible - existing charts work without changes

**Usage:**
```yaml
# Legacy (still works)
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment") }}

# New multi-deployment
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment" "configPath" .Values.worker) }}
```

**Value Priority Order:**
1. `configPath.autoscaling.*` (highest - deployment-specific)
2. `global.autoscaling.*` (medium - global defaults)
3. `autoscaling.*` (lowest - legacy root path)

### 2. Custom Metrics Support (HPA)

Added support for advanced HPA metrics beyond simple CPU/Memory targets.

**New capability:** `autoscaling.metrics` array

**Supports all Kubernetes HPA metric types:**
- `Resource` - Pod-level resource metrics (CPU, memory)
- `ContainerResource` - Container-specific resource metrics
- `Pods` - Custom pod metrics (e.g., requests_per_second)
- `Object` - Kubernetes object metrics (e.g., Ingress metrics)
- `External` - External metrics (e.g., queue depth from Prometheus, Datadog, etc.)

**Usage:**
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 100
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
    - type: External
      external:
        metric:
          name: queue_depth
        target:
          type: AverageValue
          averageValue: "30"
```

**Behavior:**
- If `metrics` array is provided, it takes precedence over `targetCPU`/`targetMemory`
- If `metrics` is not provided, falls back to simple `targetCPU`/`targetMemory` mode (backward compatible)

### 3. Unhealthy Pod Eviction Policy (PDB)

Added support for `unhealthyPodEvictionPolicy` (Kubernetes 1.26+).

**New field:** `pdb.unhealthyPodEvictionPolicy`

**Values:**
- `AlwaysAllow` - Always allow eviction of unhealthy pods
- `IfHealthyBudget` - Only allow eviction if healthy pods meet the budget

**Usage:**
```yaml
pdb:
  create: true
  minAvailable: "50%"
  unhealthyPodEvictionPolicy: "IfHealthyBudget"
```

**Benefits:**
- Better control over pod disruptions during cluster maintenance
- Prevents cascading failures when many pods are unhealthy
- Production stability improvement

## Files Changed

### Templates
- `src/common/templates/_hpa.tpl` - Added configPath and custom metrics support
- `src/common/templates/_pdb.tpl` - Added configPath and unhealthyPodEvictionPolicy support

### Documentation
- `src/common/templates/MULTI_DEPLOYMENT_EXAMPLE.md` - Comprehensive usage examples and patterns

### Tests
- `test-multi-deployment/` - Complete test chart validating all new features
  - Legacy backward compatibility tests
  - Multi-deployment with configPath tests
  - Custom metrics tests
  - unhealthyPodEvictionPolicy tests

## Backward Compatibility

✅ **100% backward compatible** - All existing charts continue to work without any modifications.

**Validated scenarios:**
1. Legacy HPA/PDB without configPath - ✅ Works exactly as before
2. Global values override - ✅ Still applies correctly
3. Simple targetCPU/targetMemory - ✅ Still works
4. Mixing legacy and new patterns - ✅ Supported

## Testing

All features have been tested with the included test chart:

```bash
cd test-multi-deployment
helm dependency update
helm template test .
```

**Test coverage:**
- ✅ Legacy HPA/PDB (backward compatibility)
- ✅ Multi-deployment with configPath
- ✅ Global value fallback
- ✅ Custom metrics (Resource, ContainerResource, External)
- ✅ unhealthyPodEvictionPolicy
- ✅ Priority order (configPath > global > root)

## Migration Guide

### For Existing Charts
**No action required!** Your existing charts will continue to work without any changes.

### For New Multi-Deployment Charts

**Before:**
```yaml
# Had to duplicate HPA template or use workarounds
# Could only have one HPA configuration
```

**After:**
```yaml
# values.yaml
api:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10

worker:
  autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 50

# templates/api-hpa.yaml
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment" "configPath" .Values.api) }}

# templates/worker-hpa.yaml
{{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment" "configPath" .Values.worker) }}
```

### For Advanced Metrics

**Before:**
```yaml
# Only CPU and memory targets supported
autoscaling:
  targetCPU: 80
  targetMemory: 85
```

**After:**
```yaml
# Full control over all HPA metrics
autoscaling:
  metrics:
    - type: External
      external:
        metric:
          name: sqs_queue_depth
        target:
          type: AverageValue
          averageValue: "30"
```

## See Also

- [MULTI_DEPLOYMENT_EXAMPLE.md](src/common/templates/MULTI_DEPLOYMENT_EXAMPLE.md) - Detailed usage examples
- [test-multi-deployment/](test-multi-deployment/) - Working test chart with all scenarios
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes PDB Documentation](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)

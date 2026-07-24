# Changelog

## [1.8.4] - 2026-07-24

### Added
- **`BackendTrafficPolicy` full passthrough support**: All Envoy Gateway BackendTrafficPolicy spec fields are now supported via YAML passthrough. This includes `useClientProtocol`, `circuitBreaker`, `healthCheck`, `tcpKeepalive`, `http2`, `dns`, `rateLimit`, `faultInjection`, `compression`, and all other fields from the Envoy Gateway API. Service owners can now use any BackendTrafficPolicy field by referencing the Envoy Gateway documentation (https://gateway.envoyproxy.io/docs/api/extension_types#backendtrafficpolicy). The template uses `toYaml` passthrough, eliminating the need to update helm-common for new Envoy Gateway features.

## [1.8.3] - 2026-07-24

### Added
- **`ClientTrafficPolicy` path settings**: `global.gatewayAPI.policies.clientTraffic.path` now supports `disableMergeSlashes` and `escapedSlashesAction`. Required for services that use encoded slashes (`%2F`) in URL paths (e.g. git repo paths like `org%2Frepo`) — without `escapedSlashesAction: KeepUnchanged` envoy decodes `%2F` to `/` before routing, changing the path the backend receives.

## [1.8.2] - 2026-07-23

### Fixed
- **HTTPRoute `backendRef.port` ignored `backend.service.port` set on ingress paths**: When a chart routes through a *different* service (e.g. ng-manager delegating `/ng/api/delegate-token-ng` to harness-manager:9090), the nginx Ingress path carries `backend.service.port: 9090` — which is a Service port per the k8s Ingress spec. Previously the HTTPRoute template skipped this value and fell through to the chart's own `service.port`, causing `ResolvedRefs=False "TCP Port <n> not found on Service"`. Port resolution precedence is now: per-path `gatewayAPI.backend.service.port` > per-object `gatewayAPI.backend.service.port` > per-path `backend.service.port` > per-object `backend.service.port` > chart `service.port`.

## [1.8.1] - 2026-07-08

### Fixed
- **Gateway routes/policies crash when consuming chart has no top-level `ingress:` key**: `dig "<routes>" list $ingress` panicked with `interface conversion: interface {} is nil, not map[string]interface {}` because `dig` casts its target to a map before reading keys, and the target (`$ingress`) was nil. All gateway route and policy templates now use `{{- $ingress := $.Values.ingress | default dict }}` (grpc/tcp/tls/udp routes, backendTLS/security/backendTraffic policies). This is distinct from the earlier missing-intermediate-key nil-safety fix — here the `dig` target itself was nil.
- **Duplicate `HTTPRouteFilter` when two ingress paths slug to the same name**: paths that reduced to an identical slug + hash produced two `HTTPRouteFilter` resources with the same id, failing the post-renderer (`may not add resource with an already registered id`). The HTTPRoute template now dedupes emitted filter names per object.
- **HTTPRoute `backendRef.port` used the nginx targetPort instead of the Service port**: Gateway API routes through the Service (envoy → Service ClusterIP), so `backendRef.port` must equal the Service's `spec.ports[].port`, not the nginx `backend.service.port` (which is the pod/targetPort nginx connects to directly via endpoints). The mismatch caused `ResolvedRefs=False: "TCP Port <n> not found on Service"` and 500s on affected routes (prod6: `/ng/*`, `/platform_ui/*`, registry, harness-intelligence). HTTPRoute `backendRef.port` now defaults to the chart `service.port` and accepts a per-object/per-path `gatewayAPI.backend.service.port` override; the nginx Ingress path is unchanged.
- **HTTPRoute referenced an HTTPRouteFilter that was never emitted**: the per-rule `extensionRef.name` and the `HTTPRouteFilter.metadata.name` were computed in separate blocks and could diverge, producing a dangling reference (`ResolvedRefs=False: "Unable to translate HTTPRouteFilter"` → 500s). Both names now derive from a single shared helper (`harnesscommon.v2.httpRouteFilterName`), so the reference and its target can never differ.

## [1.8.0] - 2026-06-22

### Added
- **Resource Hierarchy Service secrets**: Added global service secrets injection for Resource Hierarchy Service via `harnesscommon.services.rhsEnv` template helper. Supports both Kubernetes secrets and External Secrets Operator (ESO) configuration under `global.services.resourceHierarchy`.

## [1.7.2] - 2026-05-18

### Fixed
- **GRPCRoute & TLSRoute hostname inheritance**: Both now inherit hostnames from `global.ingress.hosts` when `hostnames` is not explicitly set per-route, matching HTTPRoute behavior. Previously these routes only emitted `spec.hostnames` when explicitly set per-route, requiring duplicate hostname configuration.
- Bare `*` filtering also applied to GRPCRoute and TLSRoute hostname sources for consistency with HTTPRoute (Gateway API CRD validation rejects bare `*`).
- Per-route `additionalHostnames` and global `gatewayAPI.grpcRoute.additionalHostnames` / `gatewayAPI.tlsRoute.additionalHostnames` are now supported as additive sources, mirroring the HTTPRoute pattern.

## [1.7.1] - 2026-05-15

### Fixed
- HTTPRoute hostname validation error when `global.ingress.disableHostInIngress: true` or when `global.ingress.hosts` contains bare `"*"`. Gateway API CRD validation rejects bare `*` (regex requires `*.<domain>` or specific hostname). The template now filters bare `*` entries from all hostname sources (`hosts`, `additionalHostnames` global and per-route) and omits the `hostnames` field entirely when the resulting list is empty, so the HTTPRoute inherits from the parent Gateway listener.

## [1.7.0] - 2026-05-14

### Added
- **GRPCRoute**: Native gRPC routing with service/method-level matching (`ingress.grpcRoutes`)
- **TCPRoute**: Raw TCP traffic routing for databases, Redis, custom protocols (`ingress.tcpRoutes`)
- **TLSRoute**: TLS passthrough routing based on SNI hostname (`ingress.tlsRoutes`)
- **UDPRoute**: UDP traffic routing for DNS, game servers, etc. (`ingress.udpRoutes`)
- **BackendTLSPolicy**: TLS configuration for gateway-to-backend connections (`ingress.backendTLSPolicies`)
- All new route types support per-route `parentRef` override of global gateway reference
- All new route types support weighted backend traffic splitting

### Fixed
- Nil pointer safety: all 10 gateway templates now use `dig` instead of direct nested map access for `global.gatewayAPI.enabled` guard

## [1.6.3] - 2026-05-14

### Added
- `renderIngress` now automatically renders all Gateway API resources (HTTPRoute, BackendTrafficPolicy, ClientTrafficPolicy, SecurityPolicy) when `global.gatewayAPI.enabled` is true
- `parentRef.namespace` defaults to `.Release.Namespace` when not explicitly set

### Fixed
- Nil pointer error when consuming charts don't define `global.gatewayAPI` in their values

## [1.5.2] - 2026-04-02

### Added
- **JFR**: Fixed bad CHMOD location

---


## [1.5.2] - 2026-04-01

### Added
- **JFR**: Added init container to create required symlinks for pods to avoid race condition with preStart conditions when referencing the JFR dumps/recording directory.

---


## [1.5.1] - 2026-03-27

### Added
- **Ingress: additive host merging** via `global.ingress.compatibilityHosts` and `ingress.extraHosts`
  - `compatibilityHosts`: environment/cluster-wide additive hosts appended to `global.ingress.hosts`
  - `extraHosts`: service-level additive hosts (e.g. internal FQDNs for a single service)
  - Both lists are de-duplicated against the primary `hosts` list and each other
  - Resolved host list is used for both `spec.rules[].host` and `spec.tls[].hosts`
  - **Breaking Change**: None — when unset, both default to empty lists and behavior is identical to previous versions
  - **Tracking**: CLI-55986

---


## [1.4.2] - 2025-01-23

### Fixed
- **Critical PDB Selector Bug**: Fixed PDB template to respect `nameOverride` parameter for selector labels
  - **Issue**: When creating multiple PDBs with different `nameOverride` values, all PDBs were using the same `matchLabels` selector, causing them to target the same pods instead of their respective deployments
  - **Impact**: Multi-deployment PDB configurations were non-functional - both PDBs would apply to the same pod set
  - **Fix**: PDB selector now correctly uses the `nameOverride` parameter to generate unique selector labels for each PDB
  - **Breaking Change**: None - this fixes a bug in the 1.4.1 implementation
  - Updated documentation to emphasize the importance of `nameOverride` for multi-PDB scenarios

### Changed
- Updated `MULTI_DEPLOYMENT_EXAMPLE.md` to include `nameOverride` in all multi-PDB examples
- Added "Common Pitfalls" section documenting the selector issue and correct usage

---

## [1.4.1] - 2025-01-23

### Fixed
- **Name Collision Fix**: Added `nameOverride` parameter to both HPA and PDB templates to prevent resource name collisions in multi-deployment scenarios
  - When using `configPath` for multiple deployments (e.g., API + worker), HPAs and PDBs would have the same name causing Kubernetes conflicts
  - Both templates now accept an optional `nameOverride` parameter for explicit name control
  - 100% backwards compatible - parameter is optional and doesn't affect existing usage

### Example Usage
```yaml
# Multiple HPAs with different names
{{- include "harnesscommon.hpa.renderHPA" (dict
    "ctx" .
    "kind" "Deployment"
    "nameOverride" "my-api"
    "targetRefNameOverride" "my-api"
    "configPath" .Values.api
) }}

{{- include "harnesscommon.hpa.renderHPA" (dict
    "ctx" .
    "kind" "Deployment"
    "nameOverride" "my-worker"
    "targetRefNameOverride" "my-worker"
    "configPath" .Values.worker
) }}

# Multiple PDBs with different names
{{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict
    "ctx" .
    "configPath" .Values.api
    "nameOverride" "my-api"
) }}

{{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict
    "ctx" .
    "configPath" .Values.worker
    "nameOverride" "my-worker"
) }}
```

---

## [1.4.0] - Previous Release

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

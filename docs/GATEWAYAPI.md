# GatewayAPI HTTPRoute and Envoy Gateway Policies

This document describes how to use the GatewayAPI templates to generate Kubernetes Gateway API resources and Envoy Gateway policies alongside or instead of traditional Ingress resources.

## Overview

The helm-common library provides comprehensive Gateway API support through multiple templates:

- **`_gateway_httproute.tpl`** - HTTPRoute with header manipulation and URL rewriting
- **`_gateway_backendtrafficpolicy.tpl`** - Backend timeouts, connection settings, protocol, retries
- **`_gateway_clienttrafficpolicy.tpl`** - Client-side connection limits and timeouts
- **`_gateway_securitypolicy.tpl`** - IP whitelisting, CORS, JWT authentication
- **`_gateway_migration_helper.tpl`** - Prints migration suggestions for nginx annotations

Gateway API is the next-generation ingress solution for Kubernetes, offering more expressiveness, extensibility, and role-oriented design compared to traditional Ingress resources.

**Key Benefits:**
- Standards-based routing configuration
- Advanced traffic management capabilities via Envoy Gateway policies
- Provider-agnostic API design
- Support for modern proxy features (gRPC, HTTP/2, etc.)
- Hybrid policy approach: shared defaults + per-route overrides

## Migration Approach: Guided, Not Automatic

**Important:** This library does NOT auto-translate nginx annotations to Gateway API policies. Instead, when nginx annotations are detected, the templates **print migration suggestions** in the rendered YAML output showing exactly what to add to your `values.yaml`.

**Why this approach?**
- ✅ **Explicit and predictable** - You control what gets migrated and when
- ✅ **No surprises** - No magic policy generation you didn't ask for
- ✅ **Learn Gateway API** - See the mapping between nginx and Gateway API concepts
- ✅ **Incremental migration** - Migrate one policy at a time, test, and validate

**How it works:**
1. Enable `global.gatewayAPI.enabled: true`
2. Render templates (`helm template` or during deployment)
3. Look for `GATEWAY API MIGRATION SUGGESTION` comments in output
4. Copy the suggested config to your `values.yaml`
5. Re-render to generate the actual policies

## Reusing Ingress Configuration

**A major design goal is configuration reuse**: The GatewayAPI templates reuse existing `ingress.objects` configuration. This means:

✅ **No configuration duplication** - Define routing rules once in `ingress.objects`  
✅ **Smooth migration** - Enable GatewayAPI alongside existing Ingress with minimal changes  
✅ **Guided migration** - Migration suggestions show you exactly what to configure

### Auto-Handled Annotations

Only these annotations are automatically translated (for backward compatibility):

| nginx-ingress Annotation | GatewayAPI Translation | Status |
|-------------------------|------------------------|--------|
| `nginx.ingress.kubernetes.io/rewrite-target` | Creates `HTTPRouteFilter` with `urlRewrite` spec | ✅ Auto-handled |
| `nginx.ingress.kubernetes.io/proxy-read-timeout` | Adds `timeouts.backendRequest` to HTTPRoute | ✅ Auto-handled |

### Migration-Assisted Annotations

These annotations trigger **migration suggestions** (you must add config to `values.yaml`):

| nginx-ingress Annotation | Gateway API Equivalent | Template |
|-------------------------|------------------------|----------|
| `proxy-send-timeout` | `policies.backendTraffic.timeout.http.requestTimeout` | BackendTrafficPolicy |
| `proxy-connect-timeout` | `policies.backendTraffic.timeout.tcp.connectTimeout` | BackendTrafficPolicy |
| `backend-protocol: GRPC` | `policies.backendTraffic.protocol` | BackendTrafficPolicy |
| `proxy-body-size` | `policies.clientTraffic.connection.bufferLimit` | ClientTrafficPolicy |
| `client-max-body-size` | `policies.backendTraffic.connection.bufferLimit` | BackendTrafficPolicy |
| `whitelist-source-range` | `policies.security.authorization` | SecurityPolicy |
| `upstream-vhost` | `httpRoute.upstreamHostOverride` | HTTPRoute RequestHeaderModifier |
| `server-alias` | `httpRoute.additionalHostnames` | HTTPRoute hostnames |
| `configuration-snippet` (headers) | `httpRoute.requestHeaders` | HTTPRoute RequestHeaderModifier |
| `server-snippet` (timeouts) | `policies.backendTraffic.timeout` | BackendTrafficPolicy |

## Configuration

### Enabling GatewayAPI

```yaml
global:
  # Both must be enabled for HTTPRoutes to render
  ingress:
    enabled: true
  gatewayAPI:
    enabled: true
```

### Basic Configuration

```yaml
global:
  ingress:
    enabled: true
    hosts:
      - api.example.com
      - api-staging.example.com
    objects:
      annotations:
        # These annotations apply to both Ingress and HTTPRoute
        cert-manager.io/cluster-issuer: letsencrypt-prod
      
  gatewayAPI:
    enabled: true
    # Reference to the parent Gateway resource
    parentRef:
      name: prod-gateway
      namespace: gateway-system
      # Optional: target a specific listener
      sectionName: https
      # Optional: target a specific port
      port: 443

# Service-level ingress objects configuration
ingress:
  objects:
    - name: api-routes
      annotations:
        # This will create an HTTPRouteFilter for URL rewriting
        nginx.ingress.kubernetes.io/rewrite-target: /$2
        # This will add timeouts to the HTTPRoute rules
        nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
      paths:
        - path: /api(/|$)(.*)
          backend:
            service:
              name: api-service
              port: 8080
```

### Generated Resources

With the above configuration, the template generates:

1. **HTTPRoute resource** - Defines routing rules and references the parent Gateway
2. **HTTPRouteFilter resource** (if `rewrite-target` annotation exists) - Implements URL rewriting using Envoy Gateway CRD

Example output:

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-service-api-routes-0
  namespace: default
spec:
  parentRefs:
    - name: prod-gateway
      namespace: gateway-system
      sectionName: https
      port: 443
  hostnames:
    - api.example.com
    - api-staging.example.com
  rules:
    - matches:
        - path:
            type: RegularExpression
            value: /api(/|$)(.*)
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.envoyproxy.io
            kind: HTTPRouteFilter
            name: my-service-api-routes-0-a1b2c3d4e5
      backendRefs:
        - name: api-service
          port: 8080
      timeouts:
        backendRequest: 300s
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: HTTPRouteFilter
metadata:
  name: my-service-api-routes-0-a1b2c3d4e5
  namespace: default
spec:
  urlRewrite:
    path:
      type: ReplaceRegexMatch
      replaceRegexMatch:
        pattern: /api(/|$)(.*)
        substitution: /$2
```

## Envoy Gateway Policies

The library supports three types of Envoy Gateway policies with a **hybrid approach**: shared global policies with optional per-route overrides.

### BackendTrafficPolicy

Controls traffic from the Gateway to backend Services:
- Timeouts (request, idle, connect)
- Connection settings (buffer limits)
- Backend protocol (gRPC, H2C, HTTP)
- Load balancing
- Retry policies

**Global shared policy example:**
```yaml
global:
  gatewayAPI:
    policies:
      backendTraffic:
        enabled: true
        timeout:
          http:
            requestTimeout: "300s"       # 5 minute default
            connectionIdleTimeout: "600s"
          tcp:
            connectTimeout: "30s"
        connection:
          bufferLimit: "10Gi"            # 10GB max
        protocol: "GRPC"                 # All services use gRPC
        loadBalancer:
          type: "LeastRequest"
```

**Per-route override example:**
```yaml
ingress:
  objects:
    - name: "long-running-reports"
      gatewayAPI:
        backendTraffic:
          timeout:
            http:
              requestTimeout: "3600s"    # Override: 1 hour for reports
      paths:
        - path: "/reports/.*"
```

### ClientTrafficPolicy

Controls traffic from clients to the Gateway (attaches to Gateway, not routes):
- Client connection limits
- Client timeouts
- HTTP/2 settings

**Example:**
```yaml
global:
  gatewayAPI:
    policies:
      clientTraffic:
        enabled: true
        connection:
          bufferLimit: "100Mi"           # 100MB max request body
          connectionIdleTimeout: "300s"
        timeout:
          http:
            requestReceivedTimeout: "60s"
        http2:
          maxConcurrentStreams: 1000
```

### SecurityPolicy

IP whitelisting, CORS, and JWT authentication:

**IP Whitelisting example:**
```yaml
global:
  gatewayAPI:
    policies:
      security:
        enabled: true
        authorization:
          defaultAction: "Deny"
          rules:
            - action: "Allow"
              principal:
                clientCIDRs:
                  - "10.0.0.0/8"
                  - "192.168.1.0/24"
```

**CORS example:**
```yaml
global:
  gatewayAPI:
    policies:
      security:
        enabled: true
        cors:
          allowOrigins:
            - "https://app.example.com"
            - "https://*.staging.example.com"
          allowMethods:
            - "GET"
            - "POST"
            - "PUT"
            - "DELETE"
          allowHeaders:
            - "Content-Type"
            - "Authorization"
          maxAge: "86400"
```

### Header Manipulation

Add, modify, or remove HTTP headers:

**Global shared headers:**
```yaml
global:
  gatewayAPI:
    httpRoute:
      requestHeaders:
        set:
          - name: "X-Forwarded-Proto"
            value: "https"
        add:
          - name: "X-Request-ID"
            value: "${ENVOY_REQ_ID}"
        remove:
          - "X-Legacy-Header"
      responseHeaders:
        set:
          - name: "X-Frame-Options"
            value: "DENY"
```

**Per-route headers:**
```yaml
ingress:
  objects:
    - name: "api-routes"
      gatewayAPI:
        requestHeaders:
          set:
            - name: "X-Script-Name"
              value: "/api"
        upstreamHostOverride: "api.internal.svc.cluster.local"
      paths:
        - path: "/api/.*"
```

### Additional Hostnames (Server Aliases)

Add wildcard or additional hostnames to routes:

```yaml
global:
  gatewayAPI:
    httpRoute:
      additionalHostnames:
        - "*.legacy.example.com"

ingress:
  objects:
    - name: "api-routes"
      gatewayAPI:
        additionalHostnames:
          - "api-staging.example.com"
          - "*.api-dev.example.com"
      paths:
        - path: "/api/.*"
```

**Note:** Gateway API supports wildcards (`*.domain.com`) but NOT regex patterns (unlike nginx `server-alias`).

## Template Usage

Include the templates in your Helm chart:

```yaml
# templates/gateway-policies.yaml
{{- include "harnesscommon.v2.renderBackendTrafficPolicy" (dict "ctx" .) }}
{{- include "harnesscommon.v2.renderClientTrafficPolicy" (dict "ctx" .) }}
{{- include "harnesscommon.v2.renderSecurityPolicy" (dict "ctx" .) }}

# templates/httproute.yaml
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "ctx" .) }}
```

Or include the HTTPRoute template directly:

```yaml
# templates/httproute.yaml
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "ctx" $) }}
```

Or with custom ingress configuration:

```yaml
# templates/httproute.yaml
{{- include "harnesscommon.v2.renderHTTPRoute" (dict 
    "ingress" .Values.customIngress 
    "ctx" $
) }}
```

## Values Reference

### global.gatewayAPI

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Enable GatewayAPI HTTPRoute generation (requires `global.ingress.enabled`) |
| `parentRef.name` | string | `""` | Name of the parent Gateway resource |
| `parentRef.namespace` | string | `""` | Namespace of the parent Gateway resource (optional) |
| `parentRef.sectionName` | string | `""` | Specific listener name on the Gateway (optional) |
| `parentRef.port` | int | - | Specific port on the Gateway (optional) |

### global.gatewayAPI.policies.backendTraffic

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Enable shared BackendTrafficPolicy |
| `timeout.http.requestTimeout` | string | `""` | HTTP request timeout (e.g., "300s") - equivalent to nginx proxy-send-timeout |
| `timeout.http.connectionIdleTimeout` | string | `""` | HTTP connection idle timeout (e.g., "3600s") |
| `timeout.tcp.connectTimeout` | string | `""` | TCP connect timeout (e.g., "30s") - equivalent to nginx proxy-connect-timeout |
| `connection.bufferLimit` | string | `""` | Buffer limit (e.g., "10Gi") - equivalent to nginx client-max-body-size |
| `protocol` | string | `""` | Backend protocol: "GRPC", "H2C", "HTTP" - equivalent to nginx backend-protocol |
| `loadBalancer.type` | string | `""` | Load balancing type: "RoundRobin", "LeastRequest", "Random" |
| `retry.numRetries` | int | `0` | Number of retry attempts |
| `retry.perRetryTimeout` | string | `""` | Per-retry timeout (e.g., "5s") |

### global.gatewayAPI.policies.clientTraffic

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Enable ClientTrafficPolicy (attaches to Gateway) |
| `connection.bufferLimit` | string | `""` | Client request buffer limit (e.g., "100Mi") - equivalent to nginx proxy-body-size |
| `connection.connectionIdleTimeout` | string | `""` | Client connection idle timeout (e.g., "300s") |
| `timeout.http.requestReceivedTimeout` | string | `""` | Request received timeout (e.g., "60s") - equivalent to nginx client_body_timeout |
| `http2.maxConcurrentStreams` | int | `0` | Max concurrent HTTP/2 streams |

### global.gatewayAPI.policies.security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Enable shared SecurityPolicy |
| `authorization.defaultAction` | string | `""` | Default action: "Allow" or "Deny" |
| `authorization.rules` | array | `[]` | Authorization rules with action and principal.clientCIDRs |
| `cors.allowOrigins` | array | `[]` | CORS allowed origins |
| `cors.allowMethods` | array | `[]` | CORS allowed HTTP methods |
| `cors.allowHeaders` | array | `[]` | CORS allowed headers |
| `cors.exposeHeaders` | array | `[]` | CORS exposed headers |
| `cors.maxAge` | string | `""` | CORS preflight cache duration |
| `jwt.providers` | array | `[]` | JWT authentication providers |

### global.gatewayAPI.httpRoute

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `requestHeaders.set` | array | `[]` | Request headers to set (name/value pairs) |
| `requestHeaders.add` | array | `[]` | Request headers to add (name/value pairs) |
| `requestHeaders.remove` | array | `[]` | Request headers to remove (header names) |
| `responseHeaders.set` | array | `[]` | Response headers to set (name/value pairs) |
| `responseHeaders.add` | array | `[]` | Response headers to add (name/value pairs) |
| `responseHeaders.remove` | array | `[]` | Response headers to remove (header names) |
| `upstreamHostOverride` | string | `""` | Override Host header for upstream - equivalent to nginx upstream-vhost |
| `additionalHostnames` | array | `[]` | Additional hostnames (wildcards supported) - equivalent to nginx server-alias |

### global.ingress (relevant fields)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Must be true for HTTPRoutes to render |
| `hosts` | array | `[]` | List of hostnames for the HTTPRoute |
| `disableHostInIngress` | bool | `false` | Use wildcard `*` hostname instead of specific hosts |
| `objects.annotations` | object | `{}` | Annotations applied to all ingress/HTTPRoute objects |

### ingress.objects (service-level)

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Name of the ingress object (optional, auto-generated if not specified) |
| `annotations` | object | Annotations for this ingress object (triggers migration suggestions if nginx annotations) |
| `conditionalAnnotations` | array | Conditional annotations based on value conditions |
| `gatewayAPI.backendTraffic` | object | Per-route BackendTrafficPolicy override (same schema as global policy) |
| `gatewayAPI.security` | object | Per-route SecurityPolicy override (same schema as global policy) |
| `gatewayAPI.requestHeaders` | object | Per-route request headers (set/add/remove) |
| `gatewayAPI.responseHeaders` | object | Per-route response headers (set/add/remove) |
| `gatewayAPI.upstreamHostOverride` | string | Per-route Host header override |
| `gatewayAPI.additionalHostnames` | array | Per-route additional hostnames |
| `paths` | array | List of path configurations with backend service references |
| `paths[].path` | string | Path regex for routing (supports template rendering) |
| `paths[].backend.service.name` | string | Backend service name (defaults to Chart.Name) |
| `paths[].backend.service.port` | int | Backend service port (defaults to `.Values.service.port`) |

## Migration Example with Suggestions

When you have existing nginx annotations, the template prints migration suggestions:

### Input values.yaml
```yaml
global:
  gatewayAPI:
    enabled: true  # Enable to see suggestions
  ingress:
    enabled: true
    hosts:
      - api.example.com

ingress:
  objects:
    - name: "api-routes"
      annotations:
        # Existing nginx annotations
        nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
        nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,34.82.175.27/32"
        nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
        nginx.ingress.kubernetes.io/proxy-body-size: "50m"
      paths:
        - path: "/api/.*"
```

### Generated Output with Suggestions
```yaml
---
# ========================================================================
# GATEWAY API MIGRATION SUGGESTION for route: api-routes-0
# ========================================================================
# The following nginx-ingress annotations were detected:
#
# 1. nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
#    To use with Gateway API, add to your values.yaml:
#
#    global:
#      gatewayAPI:
#        policies:
#          backendTraffic:
#            enabled: true
#            timeout:
#              http:
#                requestTimeout: "1800s"
#
# 2. nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,34.82.175.27/32"
#    To use with Gateway API, add to your values.yaml:
#
#    global:
#      gatewayAPI:
#        policies:
#          security:
#            enabled: true
#            authorization:
#              defaultAction: "Deny"
#              rules:
#                - action: "Allow"
#                  principal:
#                    clientCIDRs:
#                      - "10.0.0.0/8"
#                      - "34.82.175.27/32"
#
# 3. nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
#    To use with Gateway API, add to your values.yaml:
#
#    global:
#      gatewayAPI:
#        policies:
#          backendTraffic:
#            enabled: true
#            protocol: "GRPC"
#
#    OR add to service annotations:
#
#    service:
#      annotations:
#        gateway.envoyproxy.io/backend-protocol: "GRPC"
#
# 4. nginx.ingress.kubernetes.io/proxy-body-size: "50m"
#    To use with Gateway API, add to your values.yaml:
#
#    global:
#      gatewayAPI:
#        policies:
#          clientTraffic:
#            enabled: true
#            connection:
#              bufferLimit: "50Mi"
#
# For per-route overrides instead of shared defaults, add the config
# under: ingress.objects[].gatewayAPI instead of global.gatewayAPI.policies
#
# ========================================================================
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: api-routes-0
...
```

### After Applying Suggestions

Update your `values.yaml` with the suggested config:

```yaml
global:
  gatewayAPI:
    enabled: true
    policies:
      backendTraffic:
        enabled: true
        timeout:
          http:
            requestTimeout: "1800s"
        protocol: "GRPC"
      clientTraffic:
        enabled: true
        connection:
          bufferLimit: "50Mi"
      security:
        enabled: true
        authorization:
          defaultAction: "Deny"
          rules:
            - action: "Allow"
              principal:
                clientCIDRs:
                  - "10.0.0.0/8"
                  - "34.82.175.27/32"
  ingress:
    enabled: true
    hosts:
      - api.example.com

ingress:
  objects:
    - name: "api-routes"
      annotations:
        # Keep nginx annotations for Ingress compatibility
        nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"
        nginx.ingress.kubernetes.io/whitelist-source-range: "10.0.0.0/8,34.82.175.27/32"
        nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
        nginx.ingress.kubernetes.io/proxy-body-size: "50m"
      paths:
        - path: "/api/.*"
```

Now the templates generate:
- Traditional `Ingress` resource (from nginx annotations)
- `HTTPRoute` resource
- `BackendTrafficPolicy` with timeout and gRPC protocol
- `ClientTrafficPolicy` with buffer limit
- `SecurityPolicy` with IP whitelist

## Migration from Ingress

To add GatewayAPI support to an existing service using nginx-ingress:

1. **Enable GatewayAPI** in your values without disabling Ingress:
   ```yaml
   global:
     ingress:
       enabled: true  # Keep existing Ingress
     gatewayAPI:
       enabled: true  # Add GatewayAPI
       parentRef:
         name: your-gateway
   ```

2. **Create the HTTPRoute template** (if it doesn't exist):
   ```yaml
   # templates/httproute.yaml
   {{- include "harnesscommon.v2.renderHTTPRoute" (dict "ctx" $) }}
   ```

3. **Test the generated resources**:
   ```bash
   helm template ./chart-name --values values.yaml | grep -A 50 "kind: HTTPRoute"
   ```

4. **Deploy and validate** that traffic flows through the Gateway

5. **Optional: Disable Ingress** once GatewayAPI is validated:
   ```yaml
   # In the future, you can disable traditional Ingress
   # ingress:
   #   enabled: false  # Disable old Ingress resources
   ```

## Limitations and Caveats

1. **Envoy Gateway dependency**: Policies and HTTPRouteFilter require Envoy Gateway CRDs (`gateway.envoyproxy.io/v1alpha1`)
2. **No auto-translation**: Nginx annotations are NOT automatically converted - you must add policy config to `values.yaml` based on migration suggestions
3. **Path type**: All HTTPRoute paths use `RegularExpression` type to maintain compatibility with nginx regex patterns
4. **Gateway must exist**: The parent Gateway resource must be deployed before HTTPRoutes and policies can bind to it
5. **Server alias regex limitation**: Gateway API supports wildcards (`*.domain.com`) but NOT regex patterns like nginx `server-alias`
6. **ClientTrafficPolicy scope**: ClientTrafficPolicy attaches to the Gateway itself, not individual routes, so settings affect all routes through that Gateway
7. **Policy merge behavior**: When multiple policies target the same resource, Envoy Gateway merges them (Gateway → HTTPRoute → Service precedence)

## Advanced Use Cases

### Wildcard Hostnames

Use wildcard hostnames for catch-all routing:

```yaml
global:
  ingress:
    enabled: true
    disableHostInIngress: true  # Uses "*" as hostname
  gatewayAPI:
    enabled: true
    parentRef:
      name: internal-gateway
```

### Conditional Annotations

Apply annotations conditionally based on values:

```yaml
ingress:
  objects:
    - name: api-routes
      conditionalAnnotations:
        - condition: "global.tls.enabled"
          annotations:
            cert-manager.io/cluster-issuer: letsencrypt-prod
      paths:
        - path: /api/.*
```

### Multiple Gateway Listeners

Target different Gateway listeners for different routes:

```yaml
global:
  gatewayAPI:
    enabled: true
    parentRef:
      name: multi-protocol-gateway
      sectionName: https-listener  # Binds to specific listener
      port: 443
```

## Troubleshooting

### HTTPRoutes not being created

**Check**:
- Both `global.gatewayAPI.enabled` and `global.ingress.enabled` must be `true`
- At least one ingress object must be defined in `ingress.objects`
- Parent Gateway resource exists: `kubectl get gateway -A`

### Migration suggestions not appearing

**Check**:
- `global.gatewayAPI.enabled: true` is set
- Nginx annotations are on `ingress.objects[].annotations` (not `global.ingress.objects.annotations`)
- Run `helm template` to see the suggestions in YAML comments before the HTTPRoute resource

### Policies not being applied

**Check**:
```bash
# Verify policies exist
kubectl get backendtrafficpolicy,securitypolicy,clienttrafficpolicy -n your-namespace

# Check policy status and targetRefs
kubectl describe backendtrafficpolicy <name> -n your-namespace

# Verify targetRefs match HTTPRoute names
kubectl get httproute <name> -n your-namespace -o yaml
```

**Common issues:**
- Policy `enabled: false` (must be `true`)
- `targetRefs` don't match HTTPRoute names (check `metadata.name`)
- ClientTrafficPolicy not attached to correct Gateway
- Policy CRDs not installed (requires Envoy Gateway)

### Timeouts not working

**Check**:
- BackendTrafficPolicy is created and attached: `kubectl get backendtrafficpolicy`
- Timeout values include unit suffix (e.g., "300s", not "300")
- Policy status shows it's accepted: `kubectl describe backendtrafficpolicy <name>`

### IP whitelisting not working

**Check**:
- SecurityPolicy is created: `kubectl get securitypolicy`
- CIDR ranges are valid and quoted in YAML
- `defaultAction` is set correctly ("Allow" or "Deny")
- Policy targets correct HTTPRoutes

### Routes not matching traffic

**Check**:
- Path regex syntax matches GatewayAPI standards (uses RE2 syntax)
- Hostnames in `global.ingress.hosts` match the request Host header
- Parent Gateway exists and has a listener configured for the specified port/protocol
- Use `kubectl describe httproute` to check status and parent attachment

### Rewrite rules not working

**Check**:
- Envoy Gateway is installed and the `HTTPRouteFilter` CRD is available
- The `nginx.ingress.kubernetes.io/rewrite-target` annotation is set on the ingress object
- Regex capture groups in the path match the substitution pattern

### Header modification not working

**Check**:
- `global.gatewayAPI.httpRoute.requestHeaders` or per-route `gatewayAPI.requestHeaders` is configured
- Generated HTTPRoute has `RequestHeaderModifier` filter: `kubectl get httproute -o yaml`
- Header names are properly quoted in YAML

## Resources

- [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway HTTPRouteFilter](https://gateway.envoyproxy.io/latest/api/extension_types/#httproutefilter)
- [Gateway API Migration Guide](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)

## Related Documentation

- [Nginx to Envoy Gateway Mapping](../NGINX_TO_ENVOY_GATEWAY_MAPPING.md) - Complete annotation mapping reference
- [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Policy API Reference](https://gateway.envoyproxy.io/latest/api/extension_types/)
- [Envoy Gateway BackendTrafficPolicy](https://gateway.envoyproxy.io/latest/api/extension_types/#backendtrafficpolicy)
- [Envoy Gateway SecurityPolicy](https://gateway.envoyproxy.io/latest/api/extension_types/#securitypolicy)
- [Envoy Gateway ClientTrafficPolicy](https://gateway.envoyproxy.io/latest/api/extension_types/#clienttrafficpolicy)

## Related Templates

- `_gateway_httproute.tpl` - HTTPRoute generation with header manipulation and additional hostnames
- `_gateway_backendtrafficpolicy.tpl` - Backend timeouts, connection settings, protocol, retries
- `_gateway_clienttrafficpolicy.tpl` - Client-side connection limits and timeouts
- `_gateway_securitypolicy.tpl` - IP whitelisting, CORS, JWT authentication
- `_gateway_migration_helper.tpl` - Prints migration suggestions for nginx annotations
- `_ingress.tpl` - Traditional Ingress template (can run alongside Gateway API)
- `_service.tpl` - Service resource template

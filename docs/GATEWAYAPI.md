# GatewayAPI HTTPRoute and Envoy Gateway Policies

This document describes how to use the GatewayAPI templates to generate Kubernetes Gateway API resources and Envoy Gateway policies alongside or instead of traditional Ingress resources.

## Overview

The helm-common library provides comprehensive Gateway API support through multiple templates:

**Route Types:**
- **`_gateway_httproute.tpl`** - HTTPRoute with header manipulation and URL rewriting
- **`_gateway_grpcroute.tpl`** - Native GRPCRoute with method-level matching
- **`_gateway_tcproute.tpl`** - TCPRoute for raw TCP traffic (databases, Redis, etc.)
- **`_gateway_tlsroute.tpl`** - TLSRoute for TLS passthrough without termination
- **`_gateway_udproute.tpl`** - UDPRoute for UDP traffic (DNS, game servers, etc.)

**Policies:**
- **`_gateway_backendtrafficpolicy.tpl`** - Backend timeouts, connection settings, protocol, retries
- **`_gateway_clienttrafficpolicy.tpl`** - Client-side connection limits and timeouts
- **`_gateway_securitypolicy.tpl`** - IP whitelisting, CORS, JWT authentication
- **`_gateway_backendtlspolicy.tpl`** - TLS configuration for backend connections

**Helpers:**
- **`_gateway_migration_helper.tpl`** - Prints migration suggestions for nginx annotations

Gateway API is the next-generation ingress solution for Kubernetes, offering more expressiveness, extensibility, and role-oriented design compared to traditional Ingress resources.

**Key Benefits:**
- Standards-based routing configuration
- Advanced traffic management capabilities via Envoy Gateway policies
- Provider-agnostic API design
- Support for modern proxy features (gRPC, HTTP/2, etc.)
- Hybrid policy approach: shared defaults + per-route overrides

## Supported Resource Types

All resources are rendered automatically by a single `renderIngress` call when `global.gatewayAPI.enabled: true`.

**Stable Route Types:**

| Resource | API Version | Description | Config Location |
|----------|-------------|-------------|-----------------|
| **HTTPRoute** | `gateway.networking.k8s.io/v1` | L7 HTTP routing with regex paths, header manipulation, URL rewriting | `ingress.objects` |
| **GRPCRoute** | `gateway.networking.k8s.io/v1` | Native gRPC routing with service/method matching | `ingress.grpcRoutes` |

**Experimental Route Types:**

| Resource | API Version | Description | Config Location |
|----------|-------------|-------------|-----------------|
| **TCPRoute** | `gateway.networking.k8s.io/v1alpha2` | Raw TCP traffic (databases, Redis, custom protocols) | `ingress.tcpRoutes` |
| **TLSRoute** | `gateway.networking.k8s.io/v1alpha2` | TLS passthrough without termination (SNI-based) | `ingress.tlsRoutes` |
| **UDPRoute** | `gateway.networking.k8s.io/v1alpha2` | UDP traffic (DNS, game servers, custom protocols) | `ingress.udpRoutes` |

**Envoy Gateway Policies:**

| Resource | API Version | Description | Config Location |
|----------|-------------|-------------|-----------------|
| **BackendTrafficPolicy** | `gateway.envoyproxy.io/v1alpha1` | Timeouts, protocol, retries, load balancing | `global.gatewayAPI.policies.backendTraffic` or per-route |
| **ClientTrafficPolicy** | `gateway.envoyproxy.io/v1alpha1` | Client connection limits, HTTP/2 settings, path handling | `global.gatewayAPI.policies.clientTraffic` |
| **SecurityPolicy** | `gateway.envoyproxy.io/v1alpha1` | IP whitelisting, CORS, JWT | `global.gatewayAPI.policies.security` or per-route |
| **HTTPRouteFilter** | `gateway.envoyproxy.io/v1alpha1` | URL rewrite rules (auto-generated from rewrite-target annotation) | Auto |

**Gateway API Policies:**

| Resource | API Version | Description | Config Location |
|----------|-------------|-------------|-----------------|
| **BackendTLSPolicy** | `gateway.networking.k8s.io/v1alpha3` | TLS config for gateway-to-backend connections | `ingress.backendTLSPolicies` |

## gRPC Support

**A single Envoy Gateway handles both HTTP and gRPC traffic.** You do NOT need a separate gateway for gRPC. There are two approaches:

| Approach | Resource | When to Use |
|----------|----------|-------------|
| **HTTPRoute + protocol** | `HTTPRoute` + `BackendTrafficPolicy.protocol: "GRPC"` | Simple path-based gRPC routing, migrating from nginx |
| **Native GRPCRoute** | `GRPCRoute` | Method-level matching (service + method name), header-based matching |

### Approach 1: HTTPRoute + BackendTrafficPolicy Protocol

The simpler approach. Define gRPC service paths in `ingress.objects` like HTTP paths and set `protocol: "GRPC"` on the BackendTrafficPolicy.

```yaml
global:
  ingress:
    enabled: true
    hosts:
      - api.example.com
  gatewayAPI:
    enabled: true
    parentRef:
      name: envoy-gateway

ingress:
  objects:
    # HTTP service - uses default HTTP protocol
    - name: "web-api"
      paths:
        - path: "/api/v1/.*"
          backend:
            service:
              name: web-api-svc
              port: 8080

    # gRPC service - override protocol per-route
    - name: "grpc-service"
      gatewayAPI:
        backendTraffic:
          protocol: "GRPC"
      paths:
        - path: "/grpc\\.health\\.v1\\.Health/.*"
          backend:
            service:
              name: grpc-svc
              port: 9090
        - path: "/my\\.package\\.MyService/.*"
          backend:
            service:
              name: grpc-svc
              port: 9090
```

This generates:
- One `HTTPRoute` for `web-api` (standard HTTP backend)
- One `HTTPRoute` for `grpc-service` (same kind, same gateway)
- One `BackendTrafficPolicy` for `grpc-service` with `protocol: GRPC`

If **all** services use gRPC, set it globally instead of per-route:

```yaml
global:
  gatewayAPI:
    policies:
      backendTraffic:
        enabled: true
        protocol: "GRPC"
```

### Approach 2: Native GRPCRoute

For native gRPC service/method matching without regex paths. Define routes under `ingress.grpcRoutes`:

```yaml
ingress:
  grpcRoutes:
    - name: grpc-api
      hostnames:
        - grpc.example.com
      rules:
        # Match a specific method on a service
        - matches:
            - method:
                service: my.package.UserService
                method: GetUser
                type: Exact
          backendRefs:
            - name: user-grpc-svc
              port: 9090

        # Match all methods on a service
        - matches:
            - method:
                service: my.package.OrderService
          backendRefs:
            - name: order-grpc-svc
              port: 9090

        # Match with header conditions
        - matches:
            - method:
                service: my.package.AdminService
              headers:
                - name: x-admin-token
                  value: "valid"
          backendRefs:
            - name: admin-grpc-svc
              port: 9090
```

**Generated output:**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: grpc-api
  namespace: default
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: default
  hostnames:
    - "grpc.example.com"
  rules:
    - matches:
        - method:
            service: "my.package.UserService"
            method: "GetUser"
            type: Exact
      backendRefs:
        - name: user-grpc-svc
          port: 9090
    - matches:
        - method:
            service: "my.package.OrderService"
      backendRefs:
        - name: order-grpc-svc
          port: 9090
```

GRPCRoute supports the same `parentRef` override pattern as other routes (local overrides global).

### gRPC Timeouts

gRPC services often need longer timeouts for streaming RPCs:

```yaml
ingress:
  objects:
    - name: "grpc-streaming"
      gatewayAPI:
        backendTraffic:
          protocol: "GRPC"
          timeout:
            http:
              requestTimeout: "3600s"    # 1 hour for long-running streams
              connectionIdleTimeout: "600s"
      paths:
        - path: "/my\\.package\\.StreamService/.*"
```

## TCPRoute

Routes raw TCP traffic to backend services. Use for databases, Redis, custom TCP protocols, or any non-HTTP service.

**Gateway requirement:** The Gateway must have a TCP listener configured for the target port.

### Example: Database and Redis

```yaml
ingress:
  tcpRoutes:
    # PostgreSQL
    - name: postgres-route
      parentRef:
        sectionName: tcp-5432    # Must match a Gateway listener name
        port: 5432
      rules:
        - backendRefs:
            - name: postgres-svc
              port: 5432

    # Redis with weighted traffic splitting
    - name: redis-route
      parentRef:
        sectionName: tcp-6379
        port: 6379
      rules:
        - backendRefs:
            - name: redis-primary
              port: 6379
              weight: 80
            - name: redis-replica
              port: 6379
              weight: 20
```

**Generated output:**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: postgres-route
  namespace: default
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: default
      sectionName: tcp-5432
      port: 5432
  rules:
    - backendRefs:
        - name: postgres-svc
          port: 5432
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: redis-route
  namespace: default
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: default
      sectionName: tcp-6379
      port: 6379
  rules:
    - backendRefs:
        - name: redis-primary
          port: 6379
          weight: 80
        - name: redis-replica
          port: 6379
          weight: 20
```

### TCPRoute `parentRef` Override

Each TCPRoute can override any field from `global.gatewayAPI.parentRef`:

```yaml
ingress:
  tcpRoutes:
    - name: my-tcp-route
      parentRef:
        name: tcp-gateway         # Override gateway name
        sectionName: tcp-3306     # Target specific listener
        port: 3306
      rules:
        - backendRefs:
            - name: mysql-svc
              port: 3306
```

Fields not specified in the local `parentRef` fall back to the global `parentRef`.

## TLSRoute

Routes TLS traffic without termination (passthrough) based on SNI hostname. The Gateway does NOT decrypt the traffic — it forwards the encrypted connection to the backend based on the TLS Server Name Indication.

**Gateway requirement:** The Gateway must have a TLS listener with `mode: Passthrough`.

### Example: TLS Passthrough

```yaml
ingress:
  tlsRoutes:
    - name: db-passthrough
      hostnames:
        - db.example.com
        - db-replica.example.com
      parentRef:
        sectionName: tls-passthrough
      rules:
        - backendRefs:
            - name: db-svc
              port: 5432
```

**Generated output:**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
metadata:
  name: db-passthrough
  namespace: default
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: default
      sectionName: tls-passthrough
  hostnames:
    - "db.example.com"
    - "db-replica.example.com"
  rules:
    - backendRefs:
        - name: db-svc
          port: 5432
```

### When to Use TLSRoute vs TCPRoute

| Use Case | Route Type | Why |
|----------|------------|-----|
| Backend handles its own TLS, you want SNI routing | **TLSRoute** | Routes by hostname without decrypting |
| Raw TCP, no TLS, or gateway terminates TLS | **TCPRoute** | No SNI available for routing |
| Multiple TLS backends on same port, different hostnames | **TLSRoute** | SNI lets you multiplex |

## UDPRoute

Routes UDP traffic to backend services. Use for DNS servers, game servers, or custom UDP protocols.

**Gateway requirement:** The Gateway must have a UDP listener configured for the target port.

### Example: DNS Server

```yaml
ingress:
  udpRoutes:
    - name: dns-route
      parentRef:
        sectionName: udp-53
        port: 53
      rules:
        - backendRefs:
            - name: coredns-svc
              port: 53
```

**Generated output:**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: UDPRoute
metadata:
  name: dns-route
  namespace: default
spec:
  parentRefs:
    - name: envoy-gateway
      namespace: default
      sectionName: udp-53
      port: 53
  rules:
    - backendRefs:
        - name: coredns-svc
          port: 53
```

## BackendTLSPolicy

Configures TLS settings for connections **from the Gateway to backend Services**. Use when your backend expects TLS connections (mTLS, internal TLS).

This is a standard Gateway API resource (not Envoy-specific). Define under `ingress.backendTLSPolicies`.

### Example: CA Certificate Reference

```yaml
ingress:
  backendTLSPolicies:
    - name: api-backend-tls
      targetRef:
        name: api-service         # Target Service name
        port: 8443                # Optional: specific port
      validation:
        hostname: api-service.default.svc.cluster.local
        caCertificateRefs:
          - name: backend-ca-cert  # Secret containing the CA cert
            kind: Secret           # Optional, defaults to Secret
```

**Generated output:**

```yaml
---
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: api-backend-tls
  namespace: default
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: api-service
      sectionName: "8443"
  validation:
    hostname: "api-service.default.svc.cluster.local"
    caCertificateRefs:
      - name: backend-ca-cert
        group: ""
        kind: Secret
```

### Example: System Trust Store

Use the system CA bundle instead of explicit certificates:

```yaml
ingress:
  backendTLSPolicies:
    - name: external-tls
      targetRef:
        name: external-service
      validation:
        hostname: external.example.com
        wellKnownCACertificates: "System"
```

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

Controls traffic from the Gateway to backend Services. **All Envoy Gateway BackendTrafficPolicy spec fields are supported** via passthrough.

**Full API Reference:** https://gateway.envoyproxy.io/docs/api/extension_types#backendtrafficpolicy

**Supported fields include:**
- Timeouts (request, idle, connect)
- Connection settings (buffer limits)
- Backend protocol (gRPC, H2C, HTTP)
- **useClientProtocol** - Mirror downstream protocol to upstream (HTTP/1.1 or HTTP/2)
- Load balancing policies
- Retry policies
- **Circuit breaker** - Connection and request limits
- **Health checks** - Active health checking
- **TCP keepalive** - TCP connection keepalive
- **HTTP/2 settings** - Backend HTTP/2 configuration
- **DNS resolution** - Custom DNS settings
- **Rate limiting** - Request rate limits
- **Fault injection** - Testing delays and errors
- **Compression** - Response compression (gzip, brotli)
- **Proxy protocol** - PROXY protocol support
- And more - see API docs for complete list

**Basic example:**
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

    # Service that requires HTTP/2 upstream (opt-out of gateway-level useClientProtocol)
    - name: "http2-only-service"
      gatewayAPI:
        backendTraffic:
          useClientProtocol: false       # Force HTTP/2 upstream
      paths:
        - path: "/stream/.*"
```

#### useClientProtocol: Per-Route Override

**Background:** The gateway-level policy sets `useClientProtocol: true` (envoy mirrors client protocol to upstream: HTTP/1.1 → HTTP/1.1, HTTP/2 → HTTP/2). This eliminates head-of-line blocking on HTTP/1.1 services.

**When your service needs HTTP/2 upstream:** Some services produce UPE 502s or protocol errors with HTTP/1.1 upstream. Override `useClientProtocol` per-route:

```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          useClientProtocol: false  # Force HTTP/2 upstream for this route only
      paths:
        - path: "/api/.*"
```

**When to override with `false`:**
- Service produces UPE 502s or protocol errors with HTTP/1.1 upstream
- Service has gRPC sibling ports and HTTP/1.1 upstream breaks multiplexing
- Service depends on HTTP/2 connection multiplexing or server push

#### Advanced BackendTrafficPolicy Features

**All Envoy Gateway BackendTrafficPolicy fields are supported.** Examples:

**Circuit Breaker:**
```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          circuitBreaker:
            maxConnections: 1024               # Max connections to backend
            maxPendingRequests: 1024           # Max queued requests
            maxParallelRequests: 1024          # Max concurrent requests
            maxRequestsPerConnection: 1        # Force new connection per request
      paths:
        - path: "/api/.*"
```

**Active Health Checks:**
```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          healthCheck:
            active:
              timeout: 1s
              interval: 5s
              unhealthyThreshold: 3            # Mark unhealthy after 3 failures
              healthyThreshold: 1              # Mark healthy after 1 success
              type: HTTP
              http:
                path: /health
                expectedStatuses:
                  - 200
                  - 204
      paths:
        - path: "/api/.*"
```

**TCP Keepalive:**
```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          tcpKeepalive:
            probes: 3                          # Number of probes before marking dead
            interval: 30s                      # Interval between probes
            idleTime: 300s                     # Time before first probe
      paths:
        - path: "/api/.*"
```

**HTTP/2 Backend Settings:**
```yaml
ingress:
  objects:
    - name: grpc-service
      gatewayAPI:
        backendTraffic:
          protocol: GRPC
          http2:
            maxConcurrentStreams: 100
            initialStreamWindowSize: 64Ki
            initialConnectionWindowSize: 1Mi
      paths:
        - path: "/grpc/.*"
```

**Rate Limiting:**
```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          rateLimit:
            type: Local
            local:
              rules:
                - limit:
                    requests: 100
                    unit: Second                # Minute, Hour, Day also supported
      paths:
        - path: "/api/.*"
```

**Fault Injection (Testing):**
```yaml
ingress:
  objects:
    - name: api-service
      gatewayAPI:
        backendTraffic:
          faultInjection:
            delay:
              fixedDelay: 5s                   # Inject 5s delay
              percentage: 10.0                 # On 10% of requests
            abort:
              httpStatus: 503                  # Return 503
              percentage: 5.0                  # On 5% of requests
      paths:
        - path: "/api/.*"
```

**See the full API documentation for all available fields:**
- https://gateway.envoyproxy.io/docs/api/extension_types#backendtrafficpolicyspec
- https://gateway.envoyproxy.io/docs/tasks/ (task guides for specific features)

### ClientTrafficPolicy

Controls traffic from clients to the Gateway (attaches to Gateway, not routes):
- Client connection limits
- Client timeouts
- HTTP/2 settings
- Path handling (slash merging, encoded slash behavior)

**Example:**
```yaml
global:
  gatewayAPI:
    policies:
      clientTraffic:
        enabled: true
        connection:
          bufferLimit: "100Mi"           # 100MB max request body
        timeout:
          http:
            idleTimeout: "300s"
            requestReceivedTimeout: "60s"
        http2:
          maxConcurrentStreams: 1000
        path:
          disableMergeSlashes: true      # preserve double slashes in paths
          escapedSlashesAction: KeepUnchanged  # preserve %2F / %2f in paths
```

> **`path` use case:** Services that embed encoded slashes or version strings in URL paths (e.g. `/api/v1/repos/org%2Frepo/branches`) require `escapedSlashesAction: KeepUnchanged` — without it envoy decodes `%2F` to `/` before routing, which changes the path the backend receives.

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

The recommended approach is to use a single `renderIngress` call which automatically renders
both traditional Ingress AND Gateway API resources (HTTPRoute + policies) when
`global.gatewayAPI.enabled` is true:

```yaml
# templates/ingress.yaml (renders Ingress + Gateway API resources when enabled)
{{- include "harnesscommon.v1.renderIngress" (dict "ctx" $) }}
```

This single include handles everything:
- Traditional `Ingress` objects (always, when `global.ingress.enabled`)
- `HTTPRoute` resources (when `global.gatewayAPI.enabled`, from `ingress.objects`)
- `GRPCRoute` resources (when `global.gatewayAPI.enabled`, from `ingress.grpcRoutes`)
- `TCPRoute` resources (when `global.gatewayAPI.enabled`, from `ingress.tcpRoutes`)
- `TLSRoute` resources (when `global.gatewayAPI.enabled`, from `ingress.tlsRoutes`)
- `UDPRoute` resources (when `global.gatewayAPI.enabled`, from `ingress.udpRoutes`)
- `BackendTrafficPolicy` (when `global.gatewayAPI.policies.backendTraffic.enabled`)
- `ClientTrafficPolicy` (when `global.gatewayAPI.policies.clientTraffic.enabled`)
- `SecurityPolicy` (when `global.gatewayAPI.policies.security.enabled`)
- `BackendTLSPolicy` (when `global.gatewayAPI.enabled`, from `ingress.backendTLSPolicies`)

With custom ingress configuration:

```yaml
# templates/ingress.yaml
{{- include "harnesscommon.v1.renderIngress" (dict "ingress" .Values.customIngress "ctx" $) }}
```

### Namespace Defaulting

The `parentRef.namespace` defaults to the Helm release namespace (`.Release.Namespace`) when not explicitly set:

```yaml
global:
  gatewayAPI:
    enabled: true
    parentRef:
      name: envoy-gateway
      # namespace: defaults to .Release.Namespace
```

## Values Reference

### global.gatewayAPI

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `false` | Enable GatewayAPI HTTPRoute generation (requires `global.ingress.enabled`) |
| `parentRef.name` | string | `""` | Name of the parent Gateway resource |
| `parentRef.namespace` | string | `""` | Namespace of the parent Gateway resource (defaults to `.Release.Namespace`) |
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
| `timeout.http.idleTimeout` | string | `""` | Client connection idle timeout (e.g., "300s") |
| `timeout.http.requestReceivedTimeout` | string | `""` | Request received timeout (e.g., "60s") - equivalent to nginx client_body_timeout |
| `http2.maxConcurrentStreams` | int | `0` | Max concurrent HTTP/2 streams |
| `path.disableMergeSlashes` | bool | `false` | Preserve consecutive slashes in request paths (envoy merges them by default) |
| `path.escapedSlashesAction` | string | `""` | How to handle `%2F`/`%2f` in paths: `KeepUnchanged`, `UnescapeAndForward`, `UnescapeAndRedirect`, `RejectRequest` |

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

### ingress.objects (service-level, used by HTTPRoute)

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
| `paths[].path` | string | Path value for routing (supports template rendering; regex or segment prefix depending on `pathType`) |
| `paths[].pathType` | string | Ingress-spec path type. Only `Prefix` is honored — maps to HTTPRoute `PathPrefix` and overrides the `use-regex` annotation. Omit to fall back to the annotation branch (`RegularExpression` when `nginx.ingress.kubernetes.io/use-regex: "true"`) or the default `RegularExpression`. |
| `paths[].backend.service.name` | string | Backend service name (defaults to Chart.Name) |
| `paths[].backend.service.port` | int | Backend service port (defaults to `.Values.service.port`) |

### ingress.grpcRoutes

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Route name (optional, auto-generated as `<chart>-grpc-<index>`) |
| `hostnames` | array | SNI hostnames for the route |
| `annotations` | object | Custom annotations |
| `parentRef` | object | Override `global.gatewayAPI.parentRef` (name/namespace/sectionName/port) |
| `rules[].matches[].method.service` | string | gRPC service name (e.g., `my.package.MyService`) |
| `rules[].matches[].method.method` | string | gRPC method name (optional, empty matches all methods) |
| `rules[].matches[].method.type` | string | Match type: `Exact` (default) or `RegularExpression` |
| `rules[].matches[].headers` | array | Header match conditions (name/value/type) |
| `rules[].filters` | array | Request/response filters (rendered as-is) |
| `rules[].backendRefs` | array | Backend services (name/port/weight) |

### ingress.tcpRoutes

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Route name (optional, auto-generated as `<chart>-tcp-<index>`) |
| `annotations` | object | Custom annotations |
| `parentRef` | object | Override `global.gatewayAPI.parentRef` (name/namespace/sectionName/port) |
| `rules[].backendRefs` | array | Backend services (name/port/weight) |

### ingress.tlsRoutes

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Route name (optional, auto-generated as `<chart>-tls-<index>`) |
| `hostnames` | array | SNI hostnames for passthrough routing |
| `annotations` | object | Custom annotations |
| `parentRef` | object | Override `global.gatewayAPI.parentRef` (name/namespace/sectionName/port) |
| `rules[].backendRefs` | array | Backend services (name/port/weight) |

### ingress.udpRoutes

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Route name (optional, auto-generated as `<chart>-udp-<index>`) |
| `annotations` | object | Custom annotations |
| `parentRef` | object | Override `global.gatewayAPI.parentRef` (name/namespace/sectionName/port) |
| `rules[].backendRefs` | array | Backend services (name/port/weight) |

### ingress.backendTLSPolicies

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Policy name (optional, auto-generated as `<chart>-backend-tls-<index>`) |
| `annotations` | object | Custom annotations |
| `targetRef.name` | string | Target Service name (required) |
| `targetRef.port` | int | Target Service port (optional, rendered as sectionName) |
| `validation.hostname` | string | Expected backend certificate hostname (required) |
| `validation.caCertificateRefs` | array | CA certificate references (name, optional group/kind) |
| `validation.wellKnownCACertificates` | string | Use system trust store: `"System"` |

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
     namespace: harness-helm-new
     ingress:
       enabled: true  # Keep existing Ingress
     gatewayAPI:
       enabled: true  # Add GatewayAPI
       parentRef:
         name: envoy-gateway
         # namespace defaults to .Release.Namespace
   ```

2. **No template changes needed** - `renderIngress` automatically generates
   Gateway API resources when `global.gatewayAPI.enabled` is true. Your existing
   `templates/ingress.yaml` with `{{- include "harnesscommon.v1.renderIngress" (dict "ctx" $) }}`
   handles everything.

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
3. **Path match type**: HTTPRoute path `type` is selected by the following precedence: (1) per-path `pathType: Prefix` in `ingress.objects[].paths[].pathType` → `PathPrefix`; (2) `nginx.ingress.kubernetes.io/use-regex: "true"` object annotation → `RegularExpression` (nginx-regex compatibility branch); (3) default → `RegularExpression` (preserves prior hardcoded behavior). To opt into segment-prefix matching for an individual path, set `pathType: Prefix` on that path. Only `Prefix` is honored — `Exact` and `RegularExpression` values fall through to the annotation/default branches.
4. **Gateway must exist**: The parent Gateway resource must be deployed before HTTPRoutes and policies can bind to it
5. **Server alias regex limitation**: Gateway API supports wildcards (`*.domain.com`) but NOT regex patterns like nginx `server-alias`
6. **ClientTrafficPolicy scope**: ClientTrafficPolicy attaches to the Gateway itself, not individual routes, so settings affect all routes through that Gateway
7. **Policy merge behavior**: When multiple policies target the same resource, Envoy Gateway merges them (Gateway → HTTPRoute → Service precedence)
8. **Experimental API versions**: TCPRoute, TLSRoute, and UDPRoute use `v1alpha2`; BackendTLSPolicy uses `v1alpha3`. These APIs may change in future Gateway API releases
9. **Gateway listener requirements**: TCPRoute, TLSRoute, and UDPRoute require matching listeners on the Gateway (TCP/TLS/UDP respectively). HTTPRoute and GRPCRoute use HTTP/HTTPS listeners

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

- `_ingress.tpl` - Unified entry point: renders Ingress + all Gateway API resources via `renderIngress`
- `_gateway_httproute.tpl` - HTTPRoute generation with header manipulation and additional hostnames
- `_gateway_grpcroute.tpl` - Native GRPCRoute with service/method matching
- `_gateway_tcproute.tpl` - TCPRoute for raw TCP traffic
- `_gateway_tlsroute.tpl` - TLSRoute for TLS passthrough
- `_gateway_udproute.tpl` - UDPRoute for UDP traffic
- `_gateway_backendtrafficpolicy.tpl` - Backend timeouts, connection settings, protocol, retries
- `_gateway_clienttrafficpolicy.tpl` - Client-side connection limits and timeouts
- `_gateway_securitypolicy.tpl` - IP whitelisting, CORS, JWT authentication
- `_gateway_backendtlspolicy.tpl` - TLS config for gateway-to-backend connections
- `_gateway_migration_helper.tpl` - Prints migration suggestions for nginx annotations
- `_service.tpl` - Service resource template

# GatewayAPI HTTPRoute Support

This document describes how to use the GatewayAPI HTTPRoute template to generate Kubernetes Gateway API resources alongside or instead of traditional Ingress resources.

## Overview

The `_gateway_httproute.tpl` template enables Harness services to leverage the [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) for routing traffic. Gateway API is the next-generation ingress solution for Kubernetes, offering more expressiveness, extensibility, and role-oriented design compared to traditional Ingress resources.

**Key Benefits:**
- Standards-based routing configuration
- Advanced traffic management capabilities
- Provider-agnostic API design
- Support for modern proxy features (Envoy Gateway, etc.)

## Reusing Ingress Configuration

**A major design goal is annotation reuse**: The GatewayAPI template intelligently reuses existing `ingress.objects` configuration, including annotations designed for nginx-ingress. This means:

✅ **No configuration duplication** - Define routing rules once in `ingress.objects`  
✅ **Smooth migration** - Enable GatewayAPI alongside existing Ingress with minimal changes  
✅ **Annotation translation** - Certain nginx annotations are automatically translated to GatewayAPI equivalents

### Translated Annotations

The template automatically converts these nginx-ingress annotations to GatewayAPI constructs:

| nginx-ingress Annotation | GatewayAPI Translation |
|-------------------------|------------------------|
| `nginx.ingress.kubernetes.io/rewrite-target` | Creates `HTTPRouteFilter` with `urlRewrite` spec using regex replacement |
| `nginx.ingress.kubernetes.io/proxy-read-timeout` | Adds `timeouts.backendRequest` to the route rule |

**Note**: Other ingress annotations (like `ssl-redirect`, `auth-url`, etc.) may not apply directly to GatewayAPI and won't be translated. The template preserves them in the HTTPRoute annotations for visibility, but they won't affect Gateway behavior.

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

## Template Usage

Include the template in your Helm chart:

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
| `annotations` | object | Annotations for this specific ingress object (nginx annotations may be translated) |
| `conditionalAnnotations` | array | Conditional annotations based on value conditions |
| `paths` | array | List of path configurations with backend service references |
| `paths[].path` | string | Path regex for routing (supports template rendering) |
| `paths[].backend.service.name` | string | Backend service name (defaults to Chart.Name) |
| `paths[].backend.service.port` | int | Backend service port (defaults to `.Values.service.port`) |

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

1. **Envoy Gateway dependency**: The URL rewrite feature requires Envoy Gateway's `HTTPRouteFilter` CRD (`gateway.envoyproxy.io/v1alpha1`)
2. **Annotation compatibility**: Not all nginx-ingress annotations translate to GatewayAPI - only `rewrite-target` and `proxy-read-timeout` are currently supported
3. **Path type**: All paths use `RegularExpression` type to maintain compatibility with nginx regex patterns
4. **Gateway must exist**: The parent Gateway resource must be deployed before HTTPRoutes can bind to it

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

### Routes not matching traffic

**Check**:
- Path regex syntax matches GatewayAPI standards (uses RE2 syntax)
- Hostnames in `global.ingress.hosts` match the request Host header
- Parent Gateway exists and has a listener configured for the specified port/protocol

### Rewrite rules not working

**Check**:
- Envoy Gateway is installed and the `HTTPRouteFilter` CRD is available
- The `nginx.ingress.kubernetes.io/rewrite-target` annotation is set on the ingress object
- Regex capture groups in the path match the substitution pattern

## Resources

- [Kubernetes Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway HTTPRouteFilter](https://gateway.envoyproxy.io/latest/api/extension_types/#httproutefilter)
- [Gateway API Migration Guide](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)

## Related Templates

- `_gateway_httproute.tpl` - Main template for HTTPRoute generation
- `_ingress.tpl` - Traditional Ingress template
- `_service.tpl` - Service resource template

{{/*
Gateway API Migration Helper
Prints YAML configuration suggestions when nginx-ingress annotations are detected
Does NOT auto-translate - user must manually add config to values.yaml

USAGE:
{{- include "harnesscommon.v2.printGatewayAPIMigrationSuggestions" (dict "ctx" $ "routeName" "api-service-0" "annotations" $object.annotations) }}
*/}}
{{- define "harnesscommon.v2.printGatewayAPIMigrationSuggestions" }}
{{- $ := .ctx }}
{{- $routeName := .routeName }}
{{- $annotations := .annotations }}

{{- if and $.Values.global.gatewayAPI.enabled $annotations }}
{{- $hasNginxAnnotations := false }}
{{- $suggestions := list }}

{{- /* Check for proxy-send-timeout */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/proxy-send-timeout" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/proxy-send-timeout" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/proxy-send-timeout" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    policies:\n      backendTraffic:\n        enabled: true\n        timeout:\n          http:\n            requestTimeout: \"%ss\"" $value) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for proxy-connect-timeout */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/proxy-connect-timeout" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/proxy-connect-timeout" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/proxy-connect-timeout" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    policies:\n      backendTraffic:\n        enabled: true\n        timeout:\n          tcp:\n            connectTimeout: \"%ss\"" $value) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for backend-protocol: GRPC */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/backend-protocol" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/backend-protocol" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/backend-protocol" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $configOption1 := printf "global:\n  gatewayAPI:\n    policies:\n      backendTraffic:\n        enabled: true\n        protocol: \"%s\"" $value }}
  {{- $configOption2 := printf "service:\n  annotations:\n    gateway.envoyproxy.io/backend-protocol: \"%s\"" $value }}
  {{- $_ := set $suggestion "config" (printf "%s\n\nOR add to service annotations:\n\n%s" $configOption1 $configOption2) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for proxy-body-size */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/proxy-body-size" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/proxy-body-size" }}
  {{- $valueMi := regexReplaceAll "m$" $value "Mi" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/proxy-body-size" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    policies:\n      clientTraffic:\n        enabled: true\n        connection:\n          bufferLimit: \"%s\"" $valueMi) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for client-max-body-size */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/client-max-body-size" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/client-max-body-size" }}
  {{- $valueMi := regexReplaceAll "m$" $value "Mi" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/client-max-body-size" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    policies:\n      backendTraffic:\n        enabled: true\n        connection:\n          bufferLimit: \"%s\"" $valueMi) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for whitelist-source-range */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/whitelist-source-range" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/whitelist-source-range" }}
  {{- $cidrs := splitList "," $value }}
  {{- $cidrList := "" }}
  {{- range $cidr := $cidrs }}
    {{- $trimmed := trim $cidr }}
    {{- $cidrList = printf "%s            - \"%s\"\n" $cidrList $trimmed }}
  {{- end }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/whitelist-source-range" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    policies:\n      security:\n        enabled: true\n        authorization:\n          defaultAction: \"Deny\"\n          rules:\n            - action: \"Allow\"\n              principal:\n                clientCIDRs:\n%s" (trimSuffix "\n" $cidrList)) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for proxy-read-timeout */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/proxy-read-timeout" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/proxy-read-timeout" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/proxy-read-timeout" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "# NOTE: Currently translated to HTTPRoute.spec.rules[].timeouts.backendRequest\n# For proper Gateway API implementation, use BackendTrafficPolicy:\n\nglobal:\n  gatewayAPI:\n    policies:\n      backendTraffic:\n        enabled: true\n        timeout:\n          http:\n            requestTimeout: \"%ss\"\n\nOR per-route:\n\ningress:\n  objects:\n    - name: \"%s\"\n      gatewayAPI:\n        backendTraffic:\n          timeout:\n            http:\n              requestTimeout: \"%ss\"" $value $routeName $value) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for upstream-vhost */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/upstream-vhost" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/upstream-vhost" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/upstream-vhost" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "global:\n  gatewayAPI:\n    httpRoute:\n      upstreamHostOverride: \"%s\"\n\nOR per-route:\n\ningress:\n  objects:\n    - name: \"%s\"\n      gatewayAPI:\n        upstreamHostOverride: \"%s\"" $value $routeName $value) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for server-alias */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/server-alias" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/server-alias" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/server-alias" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $note := "Note: Gateway API supports wildcards (*.domain.com) but NOT regex patterns" }}
  {{- $_ := set $suggestion "config" (printf "# %s\nglobal:\n  gatewayAPI:\n    httpRoute:\n      additionalHostnames:\n        - \"%s\"\n\nOR per-route:\n\ningress:\n  objects:\n    - name: \"%s\"\n      gatewayAPI:\n        additionalHostnames:\n          - \"%s\"" $note $value $routeName $value) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for configuration-snippet (header manipulation) */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/configuration-snippet" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/configuration-snippet" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/configuration-snippet" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- /* Try to detect proxy_set_header */}}
  {{- if regexMatch "proxy_set_header" $value }}
  {{- $_ := set $suggestion "config" (printf "# Detected: %s\n# Manual translation required for complex nginx config\n# If setting headers, use:\n\ningress:\n  objects:\n    - name: \"%s\"\n      gatewayAPI:\n        requestHeaders:\n          set:\n            - name: \"X-Header-Name\"\n              value: \"header-value\"" (trim $value) $routeName) }}
  {{- else }}
  {{- $_ := set $suggestion "config" (printf "# Detected: %s\n# Manual translation required - complex nginx config\n# Consult Envoy Gateway documentation for equivalent" (trim $value)) }}
  {{- end }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Check for server-snippet (complex timeouts) */}}
{{- if hasKey $annotations "nginx.ingress.kubernetes.io/server-snippet" }}
  {{- $hasNginxAnnotations = true }}
  {{- $value := get $annotations "nginx.ingress.kubernetes.io/server-snippet" }}
  {{- $suggestion := dict }}
  {{- $_ := set $suggestion "annotation" "nginx.ingress.kubernetes.io/server-snippet" }}
  {{- $_ := set $suggestion "value" $value }}
  {{- $_ := set $suggestion "config" (printf "# Detected: %s\n# Manual translation required for complex nginx config\n# For timeouts, consider:\n\ningress:\n  objects:\n    - name: \"%s\"\n      gatewayAPI:\n        backendTraffic:\n          timeout:\n            http:\n              requestTimeout: \"3600s\"\n              connectionIdleTimeout: \"3600s\"" (trim $value) $routeName) }}
  {{- $suggestions = append $suggestions $suggestion }}
{{- end }}

{{- /* Print suggestions if any were found */}}
{{- if $hasNginxAnnotations }}
---
# ========================================================================
# GATEWAY API MIGRATION SUGGESTION for route: {{ $routeName }}
# ========================================================================
# The following nginx-ingress annotations were detected:
#
{{- range $idx, $suggestion := $suggestions }}
# {{ add $idx 1 }}. {{ $suggestion.annotation }}: {{ $suggestion.value | quote }}
#    To use with Gateway API, add to your values.yaml:
#
{{ $suggestion.config | nindent 1 | replace "\n" "\n#    " | trimSuffix "#    " }}
#
{{- end }}
# For per-route overrides instead of shared defaults, add the config
# under: ingress.objects[].gatewayAPI instead of global.gatewayAPI.policies
#
# ========================================================================
{{- end }}

{{- end }} {{/* if gatewayAPI enabled and annotations exist */}}
{{- end }} {{/* define */}}

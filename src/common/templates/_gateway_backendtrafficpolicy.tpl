{{/*
BackendTrafficPolicy template for Envoy Gateway
Handles timeouts, connection settings, protocol, load balancing, retries, and all Envoy Gateway BackendTrafficPolicy fields

USAGE:
{{- include "harnesscommon.v2.renderBackendTrafficPolicy" (dict "ctx" $) }}

Supports hybrid approach (Option C):
- Shared global policies that target multiple HTTPRoutes / GRPCRoutes
- Per-route override policies when needed

Applies to both `ingress.objects` (HTTPRoute) and `ingress.grpcRoutes` (GRPCRoute).
GRPCRoute has no timeout/retry fields of its own, so a BackendTrafficPolicy is the
only way to change those for a gRPC backend.

All Envoy Gateway BackendTrafficPolicy spec fields are supported via passthrough.
See https://gateway.envoyproxy.io/docs/api/extension_types#backendtrafficpolicy for full API reference.
*/}}
{{- define "harnesscommon.v2.renderBackendTrafficPolicy" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress | default dict }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if dig "gatewayAPI" "enabled" false $.Values.global -}}

{{- $globalBackendPolicy := dig "policies" "backendTraffic" dict $.Values.global.gatewayAPI }}
{{- $hasGlobalPolicy := and $globalBackendPolicy (dig "enabled" false $globalBackendPolicy) }}

{{- /* Collect routes that need shared policy vs per-route policy.
       $sharedPolicyRoutes keeps the pre-existing HTTPRoute-only list shape so the
       shared policy output stays byte-identical for charts that only use objects.
       $perRouteOverrides maps route name -> {kind, policy}. */}}
{{- $sharedPolicyRoutes := list }}
{{- $sharedGRPCPolicyRoutes := list }}
{{- $perRouteOverrides := dict }}

{{- range $index, $object := $ingress.objects }}
  {{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-" $index) | nospace) $object }}
  {{- $perRoutePolicy := dig "gatewayAPI" "backendTraffic" dict $object }}

  {{- if $perRoutePolicy }}
    {{- /* This route has an override */}}
    {{- $_ := set $perRouteOverrides $routeName (dict "kind" "HTTPRoute" "policy" $perRoutePolicy) }}
  {{- else if $hasGlobalPolicy }}
    {{- /* This route uses shared global policy */}}
    {{- $sharedPolicyRoutes = append $sharedPolicyRoutes $routeName }}
  {{- end }}
{{- end }}

{{- /* Same for GRPCRoutes. gRPC routes are collected separately so they can be
       emitted with kind: GRPCRoute in targetRefs. */}}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) }}
  {{- range $index, $route := (dig "grpcRoutes" list $ingress) }}
    {{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-grpc-" $index) | nospace) $route }}
    {{- $perRoutePolicy := dig "gatewayAPI" "backendTraffic" dict $route }}
    {{- if $perRoutePolicy }}
      {{- $_ := set $perRouteOverrides $routeName (dict "kind" "GRPCRoute" "policy" $perRoutePolicy) }}
    {{- else if $hasGlobalPolicy }}
      {{- $sharedGRPCPolicyRoutes = append $sharedGRPCPolicyRoutes $routeName }}
    {{- end }}
  {{- end }}
{{- end }}

{{- /* Generate shared global BackendTrafficPolicy if any route uses it */}}
{{- if and $hasGlobalPolicy (or (gt (len $sharedPolicyRoutes) 0) (gt (len $sharedGRPCPolicyRoutes) 0)) }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: {{ coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-" }}-backend-policy
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if $.Values.global.commonAnnotations }}
  annotations:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
  {{- end }}
spec:
  targetRefs:
    {{- range $routeName := $sharedPolicyRoutes }}
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: {{ $routeName }}
    {{- end }}
    {{- range $routeName := $sharedGRPCPolicyRoutes }}
    - group: gateway.networking.k8s.io
      kind: GRPCRoute
      name: {{ $routeName }}
    {{- end }}
  {{- if $globalBackendPolicy }}
  {{- toYaml $globalBackendPolicy | nindent 2 }}
  {{- end }}
{{- end }}

{{- /* Generate per-route override BackendTrafficPolicy resources */}}
{{- range $routeName, $override := $perRouteOverrides }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: {{ $routeName }}-backend-policy
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations:
    helm.sh/policy-type: "per-route-override"
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: {{ $override.kind }}
      name: {{ $routeName }}
  {{- if $override.policy }}
  {{- toYaml $override.policy | nindent 2 }}
  {{- end }}
{{- end }}

{{- end }} {{/* if gateway enabled */}}
{{- end }} {{/* define */}}

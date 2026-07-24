{{/*
BackendTrafficPolicy template for Envoy Gateway
Handles timeouts, connection settings, protocol, load balancing, retries, and all Envoy Gateway BackendTrafficPolicy fields

USAGE:
{{- include "harnesscommon.v2.renderBackendTrafficPolicy" (dict "ctx" $) }}

Supports hybrid approach (Option C):
- Shared global policies that target multiple HTTPRoutes
- Per-route override policies when needed

All Envoy Gateway BackendTrafficPolicy spec fields are supported via passthrough.
See https://gateway.envoyproxy.io/docs/api/extension_types#backendtrafficpolicy for full API reference.
*/}}
{{- define "harnesscommon.v2.renderBackendTrafficPolicy" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress | default dict }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) -}}

{{- $globalBackendPolicy := dig "policies" "backendTraffic" dict $.Values.global.gatewayAPI }}
{{- $hasGlobalPolicy := and $globalBackendPolicy (dig "enabled" false $globalBackendPolicy) }}

{{- /* Collect routes that need shared policy vs per-route policy */}}
{{- $sharedPolicyRoutes := list }}
{{- $perRouteOverrides := dict }}

{{- range $index, $object := $ingress.objects }}
  {{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-" $index) | nospace) $object }}
  {{- $perRoutePolicy := dig "gatewayAPI" "backendTraffic" dict $object }}

  {{- if $perRoutePolicy }}
    {{- /* This route has an override */}}
    {{- $_ := set $perRouteOverrides $routeName $perRoutePolicy }}
  {{- else if $hasGlobalPolicy }}
    {{- /* This route uses shared global policy */}}
    {{- $sharedPolicyRoutes = append $sharedPolicyRoutes $routeName }}
  {{- end }}
{{- end }}

{{- /* Generate shared global BackendTrafficPolicy if any routes use it */}}
{{- if and $hasGlobalPolicy (gt (len $sharedPolicyRoutes) 0) }}
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
  {{- if $globalBackendPolicy }}
  {{- toYaml $globalBackendPolicy | nindent 2 }}
  {{- end }}
{{- end }}

{{- /* Generate per-route override BackendTrafficPolicy resources */}}
{{- range $routeName, $policy := $perRouteOverrides }}
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
      kind: HTTPRoute
      name: {{ $routeName }}
  {{- if $policy }}
  {{- toYaml $policy | nindent 2 }}
  {{- end }}
{{- end }}

{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}

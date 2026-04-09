{{/*
BackendTrafficPolicy template for Envoy Gateway
Handles timeouts, connection settings, protocol, load balancing, and retries

USAGE:
{{- include "harnesscommon.v2.renderBackendTrafficPolicy" (dict "ctx" $) }}

Supports hybrid approach (Option C):
- Shared global policies that target multiple HTTPRoutes
- Per-route override policies when needed
*/}}
{{- define "harnesscommon.v2.renderBackendTrafficPolicy" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and $.Values.global.gatewayAPI.enabled $.Values.global.ingress.enabled -}}

{{- $globalBackendPolicy := $.Values.global.gatewayAPI.policies.backendTraffic }}
{{- $hasGlobalPolicy := and $globalBackendPolicy $globalBackendPolicy.enabled }}

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
  {{- if or $globalBackendPolicy.timeout $globalBackendPolicy.connection $globalBackendPolicy.protocol $globalBackendPolicy.loadBalancer $globalBackendPolicy.retry }}
  {{- if $globalBackendPolicy.timeout }}
  timeout:
    {{- if $globalBackendPolicy.timeout.http }}
    http:
      {{- if $globalBackendPolicy.timeout.http.requestTimeout }}
      requestTimeout: {{ $globalBackendPolicy.timeout.http.requestTimeout }}
      {{- end }}
      {{- if $globalBackendPolicy.timeout.http.connectionIdleTimeout }}
      connectionIdleTimeout: {{ $globalBackendPolicy.timeout.http.connectionIdleTimeout }}
      {{- end }}
    {{- end }}
    {{- if $globalBackendPolicy.timeout.tcp }}
    tcp:
      {{- if $globalBackendPolicy.timeout.tcp.connectTimeout }}
      connectTimeout: {{ $globalBackendPolicy.timeout.tcp.connectTimeout }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $globalBackendPolicy.connection }}
  connection:
    {{- if $globalBackendPolicy.connection.bufferLimit }}
    bufferLimit: {{ $globalBackendPolicy.connection.bufferLimit }}
    {{- end }}
  {{- end }}
  {{- if $globalBackendPolicy.protocol }}
  protocol: {{ $globalBackendPolicy.protocol }}
  {{- end }}
  {{- if and $globalBackendPolicy.loadBalancer $globalBackendPolicy.loadBalancer.type }}
  loadBalancer:
    type: {{ $globalBackendPolicy.loadBalancer.type }}
  {{- end }}
  {{- if and $globalBackendPolicy.retry (gt $globalBackendPolicy.retry.numRetries 0) }}
  retry:
    numRetries: {{ $globalBackendPolicy.retry.numRetries }}
    {{- if $globalBackendPolicy.retry.perRetryTimeout }}
    perRetryTimeout: {{ $globalBackendPolicy.retry.perRetryTimeout }}
    {{- end }}
  {{- end }}
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
  {{- if or $policy.timeout $policy.connection $policy.protocol $policy.loadBalancer $policy.retry }}
  {{- if $policy.timeout }}
  timeout:
    {{- if $policy.timeout.http }}
    http:
      {{- if $policy.timeout.http.requestTimeout }}
      requestTimeout: {{ $policy.timeout.http.requestTimeout }}
      {{- end }}
      {{- if $policy.timeout.http.connectionIdleTimeout }}
      connectionIdleTimeout: {{ $policy.timeout.http.connectionIdleTimeout }}
      {{- end }}
    {{- end }}
    {{- if $policy.timeout.tcp }}
    tcp:
      {{- if $policy.timeout.tcp.connectTimeout }}
      connectTimeout: {{ $policy.timeout.tcp.connectTimeout }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $policy.connection }}
  connection:
    {{- if $policy.connection.bufferLimit }}
    bufferLimit: {{ $policy.connection.bufferLimit }}
    {{- end }}
  {{- end }}
  {{- if $policy.protocol }}
  protocol: {{ $policy.protocol }}
  {{- end }}
  {{- if and $policy.loadBalancer $policy.loadBalancer.type }}
  loadBalancer:
    type: {{ $policy.loadBalancer.type }}
  {{- end }}
  {{- if and $policy.retry (gt $policy.retry.numRetries 0) }}
  retry:
    numRetries: {{ $policy.retry.numRetries }}
    {{- if $policy.retry.perRetryTimeout }}
    perRetryTimeout: {{ $policy.retry.perRetryTimeout }}
    {{- end }}
  {{- end }}
  {{- end }}
{{- end }}

{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}

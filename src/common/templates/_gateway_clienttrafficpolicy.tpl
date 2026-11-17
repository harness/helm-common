{{/*
ClientTrafficPolicy template for Envoy Gateway
Handles client-side settings: connection limits, client timeouts, HTTP/2 settings
NOTE: This policy attaches to the Gateway itself, not individual HTTPRoutes.
Envoy Gateway allows only one ClientTrafficPolicy per target, so a second
Gateway-level policy is rejected (Accepted=False, reason=Conflicted). To avoid
that, a chart can target a single Gateway listener instead by setting the
CHART-LOCAL (non-global) value:
  gatewayAPI.policies.clientTraffic.sectionName: <listener-name>
It is deliberately read from .Values (not .Values.global) so it cannot leak
to other charts through global values.

USAGE:
{{- include "harnesscommon.v2.renderClientTrafficPolicy" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.v2.renderClientTrafficPolicy" }}
{{- $ := .ctx }}
{{- if dig "gatewayAPI" "enabled" false $.Values.global -}}

{{- $clientPolicy := dig "policies" "clientTraffic" dict $.Values.global.gatewayAPI }}
{{- if and $clientPolicy (dig "enabled" false $clientPolicy) }}
{{- $parentRef := $.Values.global.gatewayAPI.parentRef }}
{{- if and $parentRef $parentRef.name }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: {{ coalesce $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-" }}-client-policy
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
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: {{ include "harnesscommon.tplvalues.render" ( dict "value" $parentRef.name "context" $) }}
      {{- $sectionName := dig "policies" "clientTraffic" "sectionName" "" (default dict $.Values.gatewayAPI) }}
      {{- if $sectionName }}
      sectionName: {{ include "harnesscommon.tplvalues.render" ( dict "value" $sectionName "context" $) }}
      {{- end }}
  {{- $pathDisableMergeSlashes := dig "path" "disableMergeSlashes" "" $clientPolicy }}
  {{- $pathEscapedSlashesAction := dig "path" "escapedSlashesAction" "" $clientPolicy }}
  {{- $connectionBufferLimit := dig "connection" "bufferLimit" "" $clientPolicy }}
  {{- $timeoutIdleTimeout := dig "timeout" "http" "idleTimeout" "" $clientPolicy }}
  {{- $timeoutRequestReceivedTimeout := dig "timeout" "http" "requestReceivedTimeout" "" $clientPolicy }}
  {{- $http2MaxConcurrentStreams := dig "http2" "maxConcurrentStreams" 0 $clientPolicy | int }}
  {{- if or $pathDisableMergeSlashes $pathEscapedSlashesAction $connectionBufferLimit $timeoutIdleTimeout $timeoutRequestReceivedTimeout (gt $http2MaxConcurrentStreams 0) }}
  {{- if or $pathDisableMergeSlashes $pathEscapedSlashesAction }}
  path:
    {{- if $pathDisableMergeSlashes }}
    disableMergeSlashes: {{ $pathDisableMergeSlashes }}
    {{- end }}
    {{- if $pathEscapedSlashesAction }}
    escapedSlashesAction: {{ $pathEscapedSlashesAction }}
    {{- end }}
  {{- end }}
  {{- if $connectionBufferLimit }}
  connection:
    bufferLimit: {{ $connectionBufferLimit }}
  {{- end }}
  {{- if or $timeoutIdleTimeout $timeoutRequestReceivedTimeout }}
  timeout:
    http:
      {{- if $timeoutIdleTimeout }}
      idleTimeout: {{ $timeoutIdleTimeout }}
      {{- end }}
      {{- if $timeoutRequestReceivedTimeout }}
      requestReceivedTimeout: {{ $timeoutRequestReceivedTimeout }}
      {{- end }}
  {{- end }}
  {{- if gt $http2MaxConcurrentStreams 0 }}
  http2:
    maxConcurrentStreams: {{ $http2MaxConcurrentStreams }}
  {{- end }}
  {{- end }}
{{- end }} {{/* if parentRef.name */}}
{{- end }} {{/* if clientPolicy enabled */}}

{{- end }} {{/* if gateway enabled */}}
{{- end }} {{/* define */}}

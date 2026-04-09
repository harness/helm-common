{{/*
ClientTrafficPolicy template for Envoy Gateway
Handles client-side settings: connection limits, client timeouts, HTTP/2 settings
NOTE: This policy attaches to the Gateway itself, not individual HTTPRoutes

USAGE:
{{- include "harnesscommon.v2.renderClientTrafficPolicy" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.v2.renderClientTrafficPolicy" }}
{{- $ := .ctx }}
{{- if and $.Values.global.gatewayAPI.enabled $.Values.global.ingress.enabled -}}

{{- $clientPolicy := $.Values.global.gatewayAPI.policies.clientTraffic }}
{{- if and $clientPolicy $clientPolicy.enabled }}
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
      {{- if $parentRef.namespace }}
      namespace: {{ include "harnesscommon.tplvalues.render" ( dict "value" $parentRef.namespace "context" $) }}
      {{- end }}
  {{- if or $clientPolicy.connection $clientPolicy.timeout $clientPolicy.http2 }}
  {{- if $clientPolicy.connection }}
  connection:
    {{- if $clientPolicy.connection.bufferLimit }}
    bufferLimit: {{ $clientPolicy.connection.bufferLimit }}
    {{- end }}
    {{- if $clientPolicy.connection.connectionIdleTimeout }}
    connectionIdleTimeout: {{ $clientPolicy.connection.connectionIdleTimeout }}
    {{- end }}
  {{- end }}
  {{- if $clientPolicy.timeout }}
  timeout:
    {{- if $clientPolicy.timeout.http }}
    http:
      {{- if $clientPolicy.timeout.http.requestReceivedTimeout }}
      requestReceivedTimeout: {{ $clientPolicy.timeout.http.requestReceivedTimeout }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if and $clientPolicy.http2 (gt $clientPolicy.http2.maxConcurrentStreams 0) }}
  http2:
    maxConcurrentStreams: {{ $clientPolicy.http2.maxConcurrentStreams }}
  {{- end }}
  {{- end }}
{{- end }} {{/* if parentRef.name */}}
{{- end }} {{/* if clientPolicy enabled */}}

{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}

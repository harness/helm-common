{{/*
TCPRoute template for Gateway API
Routes raw TCP traffic to backend services (databases, Redis, custom TCP protocols)

USAGE (automatically called by renderIngress when gatewayAPI is enabled):
Define routes in your consuming chart's values.yaml under ingress.tcpRoutes:

ingress:
  tcpRoutes:
    - name: postgres-route
      parentRef:            # optional override of global parentRef
        sectionName: tcp-5432
        port: 5432
      rules:
        - backendRefs:
            - name: postgres-svc
              port: 5432
              weight: 1     # optional, defaults to 1
*/}}
{{- define "harnesscommon.v2.renderTCPRoute" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) -}}
{{- $tcpRoutes := dig "tcpRoutes" list $ingress }}
{{- range $index, $route := $tcpRoutes }}
{{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-tcp-" $index) | nospace) $route }}
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: {{ $routeName }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if or $.Values.global.commonAnnotations (dig "annotations" false $route) }}
  annotations:
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $route.annotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $route.annotations "context" $ ) | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  {{- $globalParentRef := $.Values.global.gatewayAPI.parentRef }}
  {{- $localParentRef := dig "parentRef" dict $route }}
  {{- $parentRefName := dig "name" (dig "name" "" $globalParentRef) $localParentRef }}
  {{- $parentRefNamespace := dig "namespace" (dig "namespace" "" $globalParentRef) $localParentRef | default $.Release.Namespace }}
  {{- $parentRefSectionName := dig "sectionName" (dig "sectionName" "" $globalParentRef) $localParentRef }}
  {{- $parentRefPort := dig "port" (dig "port" "" $globalParentRef) $localParentRef }}
  {{- if $parentRefName }}
  parentRefs:
    - name: {{ include "harnesscommon.tplvalues.render" ( dict "value" $parentRefName "context" $) }}
      {{- if $parentRefNamespace }}
      namespace: {{ include "harnesscommon.tplvalues.render" ( dict "value" $parentRefNamespace "context" $) }}
      {{- end }}
      {{- if $parentRefSectionName }}
      sectionName: {{ $parentRefSectionName }}
      {{- end }}
      {{- if $parentRefPort }}
      port: {{ $parentRefPort }}
      {{- end }}
  {{- end }}
  rules:
    {{- range $rule := $route.rules }}
    - backendRefs:
        {{- range $ref := $rule.backendRefs }}
        - name: {{ $ref.name }}
          port: {{ $ref.port }}
          {{- if $ref.weight }}
          weight: {{ $ref.weight }}
          {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
TLSRoute template for Gateway API
Routes TLS traffic without termination (passthrough) based on SNI hostname

USAGE (automatically called by renderIngress when gatewayAPI is enabled):
Define routes in your consuming chart's values.yaml under ingress.tlsRoutes:

ingress:
  tlsRoutes:
    - name: tls-passthrough
      hostnames:
        - db.example.com
      parentRef:            # optional override of global parentRef
        sectionName: tls-passthrough
      rules:
        - backendRefs:
            - name: db-svc
              port: 5432
*/}}
{{- define "harnesscommon.v2.renderTLSRoute" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) -}}
{{- $tlsRoutes := dig "tlsRoutes" list $ingress }}
{{- range $index, $route := $tlsRoutes }}
{{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-tls-" $index) | nospace) $route }}
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TLSRoute
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
  {{- /* Hostname inheritance: per-route hostnames override; otherwise inherit from global.ingress.hosts.
  Gateway API hostname validation rejects bare "*"; filter it from any source. */}}
  {{- $hostnameList := list }}
  {{- if $route.hostnames }}
    {{- range $route.hostnames }}
      {{- if ne . "*" }}
        {{- $hostnameList = append $hostnameList . }}
      {{- end }}
    {{- end }}
  {{- else if not (dig "ingress" "disableHostInIngress" false $.Values.global) }}
    {{- range (dig "ingress" "hosts" list $.Values.global) }}
      {{- if ne . "*" }}
        {{- $hostnameList = append $hostnameList . }}
      {{- end }}
    {{- end }}
    {{- $globalTLSRoute := dig "tlsRoute" dict (dig "gatewayAPI" dict $.Values.global) }}
    {{- if $globalTLSRoute.additionalHostnames }}
      {{- range $hostname := $globalTLSRoute.additionalHostnames }}
        {{- if ne $hostname "*" }}
          {{- $hostnameList = append $hostnameList $hostname }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- if $route.additionalHostnames }}
      {{- range $hostname := $route.additionalHostnames }}
        {{- if ne $hostname "*" }}
          {{- $hostnameList = append $hostnameList $hostname }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $hostnameList }}
  hostnames:
    {{- range $hostname := $hostnameList }}
    - {{ $hostname | quote }}
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

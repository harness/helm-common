{{/*
GRPCRoute template for Gateway API
Native gRPC routing with method-level matching (alternative to HTTPRoute + BackendTrafficPolicy protocol: GRPC)

USAGE (automatically called by renderIngress when gatewayAPI is enabled):
Define routes in your consuming chart's values.yaml under ingress.grpcRoutes:

ingress:
  grpcRoutes:
    - name: grpc-api
      hostnames:
        - grpc.example.com
      rules:
        - matches:
            - method:
                service: mycompany.MyService
                method: MyMethod            # optional, empty matches all methods
                type: Exact                 # optional: Exact (default) or RegularExpression
          backendRefs:
            - name: grpc-svc
              port: 9090
          filters:                          # optional
            - type: RequestHeaderModifier
              requestHeaderModifier:
                set:
                  - name: x-custom
                    value: val
*/}}
{{- define "harnesscommon.v2.renderGRPCRoute" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and (dig "gatewayAPI" "enabled" false $.Values.global) (dig "ingress" "enabled" false $.Values.global) -}}
{{- $grpcRoutes := dig "grpcRoutes" list $ingress }}
{{- range $index, $route := $grpcRoutes }}
{{- $routeName := dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-grpc-" $index) | nospace) $route }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
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
    {{- $globalGRPCRoute := dig "grpcRoute" dict (dig "gatewayAPI" dict $.Values.global) }}
    {{- if $globalGRPCRoute.additionalHostnames }}
      {{- range $hostname := $globalGRPCRoute.additionalHostnames }}
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
    {{- if $rule.matches }}
    - matches:
        {{- range $match := $rule.matches }}
        - method:
            {{- if $match.method.service }}
            service: {{ $match.method.service | quote }}
            {{- end }}
            {{- if $match.method.method }}
            method: {{ $match.method.method | quote }}
            {{- end }}
            {{- if $match.method.type }}
            type: {{ $match.method.type }}
            {{- end }}
          {{- if $match.headers }}
          headers:
            {{- range $header := $match.headers }}
            - name: {{ $header.name | quote }}
              value: {{ $header.value | quote }}
              {{- if $header.type }}
              type: {{ $header.type }}
              {{- end }}
            {{- end }}
          {{- end }}
        {{- end }}
      {{- if $rule.filters }}
      filters:
        {{- include "harnesscommon.tplvalues.render" ( dict "value" $rule.filters "context" $ ) | nindent 8 }}
      {{- end }}
      backendRefs:
        {{- range $ref := $rule.backendRefs }}
        - name: {{ $ref.name }}
          port: {{ $ref.port }}
          {{- if $ref.weight }}
          weight: {{ $ref.weight }}
          {{- end }}
        {{- end }}
    {{- else }}
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
{{- end }}

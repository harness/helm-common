{{/*
USAGE:
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "ctx" $) }}
or
{{- include "harnesscommon.v2.renderHTTPRoute" (dict "gateway" .Values.other.gateway "ctx" $) }}
*/}}
{{- define "harnesscommon.v2.renderHTTPRoute" }}
{{- $ := .ctx }}
{{- $ingress := $.Values.ingress }}
{{- if .ingress -}}
    {{- $ingress = .ingress }}
{{- end }}
{{- if and $.Values.global.gateway.enabled $.Values.global.ingress.enabled -}}
{{- range $index, $object := $ingress.objects }}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: {{ dig "name" ((cat (coalesce $ingress.name $.Values.nameOverride $.Chart.Name | trunc 63 | trimSuffix "-") "-" $index) | nospace) $object }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations: {{/* The usual Ingress annotation to influence the beavior of nginx location rules won't apply here, so we will
          not render these annotations in the HTTPRoute objects
    {{- include "harnesscommon.tplvalues.render" (dict "value" $object.annotations "context" $) | nindent 4 }}
    */}}
    {{- if $ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $ingress.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.ingress.objects.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.ingress.objects.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- range $ca := $object.conditionalAnnotations }}
        {{- $condition := "false" }}
        {{- if hasKey $ca "condition" }}
            {{- $condition = include "harnesscommon.utils.getValueFromKey" (dict "key" $ca.condition "context" $ ) }}
        {{- end }}
        {{- if eq $condition "true" }}
            {{- include "harnesscommon.tplvalues.render" (dict "value" $ca.annotations "context" $) | nindent 4 }}
        {{- end }}
    {{- end }}
spec:
  {{- if $.Values.global.gateway.parentRef }}
  # Default parentRef from global config
  parentRefs:
    - name: {{ include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.gateway.parentRef.name "context" $) }}
      {{- if $.Values.global.gateway.parentRef.namespace }}
      namespace: {{ include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.gateway.parentRef.namespace "context" $) }}
      {{- end }}
      {{- if $.Values.global.gateway.parentRef.sectionName }}
      sectionName: {{ $.Values.global.gateway.parentRef.sectionName }}
      {{- end }}
      {{- if $.Values.global.gateway.parentRef.port }}
      port: {{ $.Values.global.gateway.parentRef.port }}
      {{- end }}
  {{- end }}
  hostnames:
  {{- if $.Values.global.ingress.disableHostInIngress }}
    - "*"
  {{- else }}
    {{- range $.Values.global.ingress.hosts }}
    - {{ . | quote }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $idx := $object.paths }}
    {{- $serviceName := dig "backend" "service" "name" $.Chart.Name $idx }}
    {{- $servicePort := dig "backend" "service" "port" $.Values.service.port $idx }}
    - matches:
        - path:
            type: RegularExpression
            value: {{ include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
      {{- if hasKey $object.annotations "nginx.ingress.kubernetes.io/rewrite-target" }}
      filters:
        - type: ExtensionRef
          extensionRef:
            group: gateway.envoyproxy.io
            kind: HTTPRouteFilter
            name: {{ cat (get $object "name" | trunc 50 | trimSuffix "-") "-" $index "-" (sha1sum $idx.path | trunc 10) | nospace }}
      {{- end }}
      # Backend services
      backendRefs:
        - name: {{ $serviceName }}
          port: {{ $servicePort }}
      {{- if hasKey $object.annotations "nginx.ingress.kubernetes.io/proxy-read-timeout" }}
      # Timeouts for this rule
      timeouts: {{/* Add timeouts if the nginx annotation for timeouts was set. Not ideal, as these settings are not equivalent.
                     TODO: Improve? */}}
        backendRequest: {{ printf "%s%s" (get $object.annotations "nginx.ingress.kubernetes.io/proxy-read-timeout") "s" }}
      {{- end }}
    {{- end }}
{{- if hasKey $object.annotations "nginx.ingress.kubernetes.io/rewrite-target" }}
{{- range $idx := $object.paths }}
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: HTTPRouteFilter
metadata:
  name: {{ cat (get $object "name" | trunc 50 | trimSuffix "-") "-" $index "-" (sha1sum $idx.path | trunc 10) | nospace }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations: {{/* The usual Ingress annotation to influence the beavior of nginx location rules won't apply here, so we
                    will not render these annotations in the HTTPRoute objects
    {{- include "harnesscommon.tplvalues.render" (dict "value" $object.annotations "context" $) | nindent 4 }}
  */}}
    {{- if $ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $ingress.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.ingress.objects.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.ingress.objects.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- range $ca := $object.conditionalAnnotations }}
        {{- $condition := "false" }}
        {{- if hasKey $ca "condition" }}
            {{- $condition = include "harnesscommon.utils.getValueFromKey" (dict "key" $ca.condition "context" $ ) }}
        {{- end }}
        {{- if eq $condition "true" }}
            {{- include "harnesscommon.tplvalues.render" (dict "value" $ca.annotations "context" $) | nindent 4 }}
        {{- end }}
    {{- end }}
spec:
  urlRewrite:
    path:
      type: ReplaceRegexMatch
      replaceRegexMatch:
        pattern: {{ include "harnesscommon.tplvalues.render" ( dict "value" $idx.path "context" $) }}
        substitution: {{ include "harnesscommon.tplvalues.render" ( dict "value" ( regexReplaceAll "\\$" (get $object.annotations "nginx.ingress.kubernetes.io/rewrite-target") "\\" ) "context" $) }}
{{- end }} {{/* Range over paths */}}
{{- end }} {{/* If to create HTTPRouteFilter */}}
{{- end }} {{/* Range over all the ingress keys */}}
{{- end }} {{/* if gateway / ingress enabled */}}
{{- end }} {{/* define */}}

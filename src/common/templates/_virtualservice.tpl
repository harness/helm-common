{{/*
USAGE:
{{- include "harnesscommon.v1.renderVirtualService" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.v1.renderVirtualService" }}
{{- $ := .ctx }}
{{- if $.Values.global.istio.enabled -}}
{{- range $index, $object := $.Values.virtualService.objects }}
{{- if or (and (eq $object.pathMatchType "regex") $.Values.global.istio.enableRegexRoutes) (eq $object.pathMatchType "prefix") (eq $object.pathMatchType "exact") }}
{{- $objName := dig "name" ((cat (default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-") "-" $index)| nospace)  $object }}
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ $objName }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels:
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  annotations:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $object.annotations "context" $) | nindent 4 }}
    {{- if $.Values.ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.virtualService.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
spec:
  gateways:
    {{- if and ($.Values.global.istio.virtualService.gateways) (eq (len $.Values.global.istio.virtualService.gateways) 0) }}
    - istio-system/public
    {{- else }}
    {{- range $.Values.global.istio.virtualService.gateways }}
    - {{ . }}
    {{- end }}
    {{- end }}
  hosts:
    {{- range $.Values.global.istio.virtualService.hosts }}
    - {{ . }}
    {{- end }}
  http:
  {{- range $i, $path := $object.paths }}
  {{- $serviceName := dig "backend" "service" "name" $.Chart.Name $path }}
  {{- $servicePort := dig "backend" "service" "port" $.Values.service.port $path }}
  - match:
    - uri:
        {{ $object.pathMatchType }}: {{ include "harnesscommon.tplvalues.render" ( dict "value" $path.path "context" $) }}
    name: {{ (cat $objName "-" $i) | nospace }}
    rewrite:
    {{- if eq $object.pathMatchType "regex" }}
      uriRegexRewrite:
        match: {{ include "harnesscommon.tplvalues.render" ( dict "value" $path.path "context" $) }}
        rewrite: {{ include "harnesscommon.tplvalues.render" ( dict "value" $object.pathRewrite "context" $) }}
    {{- else if eq $object.pathMatchType "prefix" }}
      uri: {{ include "harnesscommon.tplvalues.render" ( dict "value" $object.pathRewrite "context" $) }}
    {{- else }}
      uri: {{ include "harnesscommon.tplvalues.render" ( dict "value" $object.pathRewrite "context" $) }}
    {{- end }}
    route:
    - destination:
        host: {{ $serviceName }}
        port:
          number: {{ $servicePort }}
  {{- end }}
---
{{- end }}
{{- end }}
{{- end }}
{{- end }}

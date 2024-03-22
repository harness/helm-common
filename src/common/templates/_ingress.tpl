{{/*
USAGE:
{{- include "harnesscommon.v1.renderIngress" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.v1.renderIngress" }}
{{- $ := .ctx }}
{{- if $.Values.global.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
  labels:
    {{- if $.Values.global.commonLabels }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
    {{- end }}
  annotations:
    {{- if $.Values.ingress.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.ingress.annotations "context" $) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.commonAnnotations }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if $.Values.global.ingress.objects.annotations }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.ingress.objects.annotations "context" $) | nindent 4 }}
    {{- end }}
spec:
  ingressClassName: {{ $.Values.global.ingress.className | quote }}
  rules:
    {{- if $.Values.global.ingress.disableHostInIngress }}
    - http:
        paths:
        {{- range $idx := $.Values.ingress.paths }}
        {{- $serviceName := dig "backend" "service" "name" $.Chart.Name $idx }}
        {{- $servicePort := dig "backend" "service" "port" $.Values.service.port $idx }}
        {{- $pathType := dig "pathType" "ImplementationSpecific" $idx }}
        - backend:
            service:
              name: {{ $serviceName }}
              port:
                number: {{ $servicePort }}
          path: {{ $idx.path }}
          pathType: {{ $pathType }}
        {{- end }}
    {{- else }}
    {{- range $.Values.global.ingress.hosts }}
    - host: {{ . | quote }}
      http:
        paths:
        {{- range $idx := $.Values.ingress.paths }}
        {{- $serviceName := dig "backend" "service" "name" $.Chart.Name $idx }}
        {{- $servicePort := dig "backend" "service" "port" $.Values.service.port $idx }}
        {{- $pathType := dig "pathType" "ImplementationSpecific" $idx }}
        - backend:
            service:
              name: {{ $serviceName }}
              port:
                number: {{ $servicePort }}
          path: {{ $idx.path }}
          pathType: {{ $pathType }}
        {{- end }}
    {{- end }}
    {{- end}}
  {{- if $.Values.global.ingress.tls.enabled }}
  tls:
    - hosts:
        {{- range $.Values.global.ingress.hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ $.Values.global.ingress.tls.secretName }}
  {{- end }}
{{- end }}

{{- end}}
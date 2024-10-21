{{/*
Create Horizontal Pod Autoscaler Configuration
Usage example:
{{- include "harnesscommon.hpa.renderHPA" . (dict "ctx" .  "kind" "deployment") }}
*/}}
{{- define "harnesscommon.hpa.renderHPA" -}}
{{- $ := .ctx }}
{{- if or $.Values.global.autoscaling.enabled $.Values.autoscaling.enabled }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
{{- $serviceName := default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- $minReplicas := 2 }}
{{- $maxReplicas := 100 }}

{{- if $.Values.global.autoscaling.minReplicas }}
    {{- $minReplicas = $.Values.global.autoscaling.minReplicas }}
{{- end }}
{{- if $.Values.autoscaling.minReplicas }}
    {{- $minReplicas = $.Values.autoscaling.minReplicas }}
{{- end }}
{{- if $.Values.global.autoscaling.maxReplicas }}
    {{- $maxReplicas = $.Values.global.autoscaling.maxReplicas }}
{{- end }}
{{- if $.Values.autoscaling.maxReplicas }}
    {{- $maxReplicas = $.Values.autoscaling.maxReplicas }}
{{- end }}
apiVersion: {{ include "harnesscommon.capabilities.hpa.apiVersion" ( dict "context" $ ) }}
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $serviceName }}
  namespace: {{ $.Release.Namespace }}
  labels:
    {{- include $labelsFunction $ | nindent 4 }}
    {{- if $.Values.global.commonLabels }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
    {{- end }}
  {{- if $.Values.global.commonAnnotations }}
  annotations: {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
  {{- end }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ .kind }}
    name: {{ $serviceName }}
  minReplicas: {{ $minReplicas }}
  maxReplicas: {{ $maxReplicas }}
  {{- include "harnesscommon.hpa.metrics.apiVersion" $ }}
{{- end }}
{{- end }}


{{/*
Define targetCPU and targetMemory based on K8s version
Required because there was a change between supported versions
{{- include "harnesscommon.hpa.metrics.apiVersion" . }}
*/}}
{{- define "harnesscommon.hpa.metrics.apiVersion" -}}
  {{- if or .Values.autoscaling.targetMemory .Values.autoscaling.targetCPU }}
  metrics:
    {{- if .Values.autoscaling.targetMemory }}
    - type: Resource
      resource:
        name: memory
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ .Values.autoscaling.targetMemory }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemory }}
        {{- end }}
    {{- end }}
    {{- if .Values.autoscaling.targetCPU }}
    - type: Resource
      resource:
        name: cpu
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ .Values.autoscaling.targetCPU }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPU }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- if .Values.autoscaling.behavior }}
  behavior:
    {{- include "harnesscommon.tplvalues.render" (dict "value" .Values.autoscaling.behavior "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}
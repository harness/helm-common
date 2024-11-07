{{/*
Create Horizontal Pod Autoscaler Configuration
Usage example:
{{- include "harnesscommon.hpa.renderHPA" . (dict "ctx" .  "kind" "deployment" "targetRefNameOverride" "custom-target-name") }}
*/}}
{{- define "harnesscommon.hpa.renderHPA" -}}
{{- $ := .ctx }}
{{- $serviceName := default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- $targetRefName := default $serviceName .targetRefNameOverride }}
{{- if or $.Values.global.autoscaling.enabled $.Values.autoscaling.enabled }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
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
    name: {{ $targetRefName }}
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
  {{- $targetMemory := "" }}
  {{- $targetCPU := "" }}
  {{/* For backward compatibility */}}
  {{- if .Values.global.autoscaling }}
    {{- if $.Values.global.autoscaling.targetMemory }}
        {{- $targetMemory = $.Values.global.autoscaling.targetMemory }}
    {{- end }}
    {{- if $.Values.global.autoscaling.targetCPU }}
      {{- $targetCPU = $.Values.global.autoscaling.targetCPU }}
    {{- end }}
  {{- end }}
  {{- if $.Values.autoscaling.targetMemory }}
      {{- $targetMemory = $.Values.autoscaling.targetMemory }}
  {{- end }}
  {{- if $.Values.autoscaling.targetCPU }}
      {{- $targetCPU = $.Values.autoscaling.targetCPU }}
  {{- end }}
  {{- if or $targetMemory $targetCPU }}
  metrics:
    {{- if $targetMemory }}
    - type: Resource
      resource:
        name: memory
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ $targetMemory }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ $targetMemory }}
        {{- end }}
    {{- end }}
    {{- if $targetCPU }}
    - type: Resource
      resource:
        name: cpu
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" .) }}
        targetAverageUtilization: {{ $targetCPU }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ $targetCPU }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- if .Values.autoscaling.behavior }}
  behavior:
    {{- include "harnesscommon.tplvalues.render" (dict "value" .Values.autoscaling.behavior "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}
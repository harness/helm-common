{{/*
Create Horizontal Pod Autoscaler Configuration
Usage examples:
  Legacy (backward compatible):
    {{- include "harnesscommon.hpa.renderHPA" (dict "ctx" .  "kind" "Deployment" "targetRefNameOverride" "custom-target-name") }}

  Multi-deployment with configPath:
    {{- include "harnesscommon.hpa.renderHPA" (dict "ctx" . "kind" "Deployment" "nameOverride" "my-worker" "targetRefNameOverride" "my-worker" "configPath" .Values.worker) }}

Parameters:
  - ctx: Required. The root context (usually .)
  - kind: Required. The kind of resource to target (e.g., "Deployment", "StatefulSet")
  - nameOverride: Optional. Override the HPA resource name (useful for multi-deployment to avoid name collisions)
  - targetRefNameOverride: Optional. Override the target reference name
  - configPath: Optional. Custom values path for multi-deployment scenarios. If not provided, uses $.Values (legacy behavior)

Supported autoscaling values:
  - enabled: Enable/disable HPA creation
  - minReplicas: Minimum number of replicas
  - maxReplicas: Maximum number of replicas
  - targetCPU: Target CPU utilization percentage (simple mode)
  - targetMemory: Target memory utilization percentage (simple mode)
  - behavior: Custom scaling behavior (scaleUp/scaleDown policies)
  - metrics: Custom metrics array (advanced mode - overrides targetCPU/targetMemory)
      Supports: Resource, ContainerResource, Pods, Object, External metrics
      When specified, targetCPU and targetMemory are ignored

Example with custom metrics:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 80
      - type: External
        external:
          metric:
            name: my-custom-metric
          target:
            type: AverageValue
            averageValue: "100"
*/}}
{{- define "harnesscommon.hpa.renderHPA" -}}
{{- $ := .ctx }}
{{- $serviceName := default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- $hpaName := $serviceName }}
{{- if .nameOverride }}
  {{- $hpaName = .nameOverride }}
{{- end }}
{{- if .targetRefNameOverride }}
  {{- $hpaName = .targetRefNameOverride }}
{{- end }}
{{- $targetRefName := default $serviceName .targetRefNameOverride }}

{{/* Determine config source: use configPath if provided, otherwise use root $.Values (legacy) */}}
{{- $config := $.Values }}
{{- if .configPath }}
  {{- $config = .configPath }}
{{- end }}

{{/* Check if autoscaling is enabled - check both configPath and global */}}
{{- $autoscalingEnabled := false }}
{{- if $.Values.global.autoscaling.enabled }}
  {{- $autoscalingEnabled = true }}
{{- end }}
{{- if $config.autoscaling.enabled }}
  {{- $autoscalingEnabled = true }}
{{- end }}

{{- if $autoscalingEnabled }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
{{- $minReplicas := 2 }}
{{- $maxReplicas := 100 }}

{{/* Priority: global < legacy root < configPath */}}
{{- if $.Values.global.autoscaling.minReplicas }}
    {{- $minReplicas = $.Values.global.autoscaling.minReplicas }}
{{- end }}
{{- if and (not .configPath) $.Values.autoscaling.minReplicas }}
    {{- $minReplicas = $.Values.autoscaling.minReplicas }}
{{- end }}
{{- if and .configPath $config.autoscaling.minReplicas }}
    {{- $minReplicas = $config.autoscaling.minReplicas }}
{{- end }}

{{- if $.Values.global.autoscaling.maxReplicas }}
    {{- $maxReplicas = $.Values.global.autoscaling.maxReplicas }}
{{- end }}
{{- if and (not .configPath) $.Values.autoscaling.maxReplicas }}
    {{- $maxReplicas = $.Values.autoscaling.maxReplicas }}
{{- end }}
{{- if and .configPath $config.autoscaling.maxReplicas }}
    {{- $maxReplicas = $config.autoscaling.maxReplicas }}
{{- end }}
apiVersion: {{ include "harnesscommon.capabilities.hpa.apiVersion" ( dict "context" $ ) }}
kind: HorizontalPodAutoscaler
metadata:
  name: {{ $hpaName }}
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
  {{- include "harnesscommon.hpa.metrics.apiVersion" (dict "ctx" $ "config" $config "configPath" .configPath) }}
{{- end }}
{{- end }}

{{/*
Define targetCPU and targetMemory based on K8s version
Required because there was a change between supported versions
{{- include "harnesscommon.hpa.metrics.apiVersion" (dict "ctx" $ "config" $config "configPath" .configPath) }}
*/}}
{{- define "harnesscommon.hpa.metrics.apiVersion" -}}
  {{- $ := .ctx }}
  {{- $config := .config }}
  {{- $targetMemory := "" }}
  {{- $targetCPU := "" }}

  {{/* Priority: global < legacy root < configPath */}}
  {{- if $.Values.global.autoscaling }}
    {{- if $.Values.global.autoscaling.targetMemory }}
        {{- $targetMemory = $.Values.global.autoscaling.targetMemory }}
    {{- end }}
    {{- if $.Values.global.autoscaling.targetCPU }}
      {{- $targetCPU = $.Values.global.autoscaling.targetCPU }}
    {{- end }}
  {{- end }}
  {{- if and (not .configPath) $.Values.autoscaling.targetMemory }}
      {{- $targetMemory = $.Values.autoscaling.targetMemory }}
  {{- end }}
  {{- if and (not .configPath) $.Values.autoscaling.targetCPU }}
      {{- $targetCPU = $.Values.autoscaling.targetCPU }}
  {{- end }}
  {{- if and .configPath $config.autoscaling.targetMemory }}
      {{- $targetMemory = $config.autoscaling.targetMemory }}
  {{- end }}
  {{- if and .configPath $config.autoscaling.targetCPU }}
      {{- $targetCPU = $config.autoscaling.targetCPU }}
  {{- end }}

  {{/* Check for custom metrics - priority: configPath > legacy root */}}
  {{- $customMetrics := "" }}
  {{- if and (not .configPath) $.Values.autoscaling.metrics }}
      {{- $customMetrics = $.Values.autoscaling.metrics }}
  {{- end }}
  {{- if and .configPath $config.autoscaling.metrics }}
      {{- $customMetrics = $config.autoscaling.metrics }}
  {{- end }}

  {{/* If custom metrics are provided, use them; otherwise use auto-generated CPU/Memory metrics */}}
  {{- if $customMetrics }}
  metrics:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $customMetrics "context" $) | nindent 4 }}
  {{- else if or $targetMemory $targetCPU }}
  metrics:
    {{- if $targetMemory }}
    - type: Resource
      resource:
        name: memory
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" $) }}
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
        {{- if semverCompare "<1.23-0" (include "harnesscommon.capabilities.kubeVersion" $) }}
        targetAverageUtilization: {{ $targetCPU }}
        {{- else }}
        target:
          type: Utilization
          averageUtilization: {{ $targetCPU }}
        {{- end }}
    {{- end }}
  {{- end }}
  {{- if or (and (not .configPath) $.Values.autoscaling.behavior) (and .configPath $config.autoscaling.behavior) }}
  behavior:
    {{- if .configPath }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $config.autoscaling.behavior "context" $) | nindent 4 }}
    {{- else }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.autoscaling.behavior "context" $) | nindent 4 }}
    {{- end }}
  {{- end }}
{{- end -}}
{{/*
Create Pod Distribution Budget Configurations
Usage examples:
  Legacy (backward compatible):
    {{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict "ctx" .) }}

  Multi-deployment with configPath:
    {{- include "harnesscommon.pdb.renderPodDistributionBudget" (dict "ctx" . "configPath" .Values.worker "nameOverride" "my-worker") }}

Parameters:
  - ctx: Required. The root context (usually .)
  - configPath: Optional. Custom values path for multi-deployment scenarios. If not provided, uses $.Values (legacy behavior)
  - nameOverride: Optional. Override the PDB resource name (useful for multi-deployment to avoid name collisions)

Supported PDB values:
  - create: Enable/disable PDB creation
  - minAvailable: Minimum number/percentage of pods that must be available
  - maxUnavailable: Maximum number/percentage of pods that can be unavailable
  - unhealthyPodEvictionPolicy: Policy for evicting unhealthy pods (AlwaysAllow or IfHealthyBudget, K8s 1.26+)
*/}}
{{- define "harnesscommon.pdb.renderPodDistributionBudget" -}}
{{- $ := .ctx }}

{{/* Determine config source: use configPath if provided, otherwise use root $.Values (legacy) */}}
{{- $config := $.Values }}
{{- if .configPath }}
  {{- $config = .configPath }}
{{- end }}

{{/* Check if PDB creation is enabled - check both configPath and global */}}
{{- $pdbCreate := false }}
{{- if $.Values.global.pdb.create }}
  {{- $pdbCreate = true }}
{{- end }}
{{- if $config.pdb.create }}
  {{- $pdbCreate = true }}
{{- end }}

{{- if $pdbCreate }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
{{- $pdbName := default $.Chart.Name $.Values.nameOverride }}
{{- if .nameOverride }}
  {{- $pdbName = .nameOverride }}
{{- end }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ $pdbName | trunc 63 | trimSuffix "-" }}
  namespace: {{ $.Release.Namespace }}
  labels: {{ include $labelsFunction $ | nindent 4 }}
  {{- if $.Values.global.commonLabels }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if $.Values.global.commonAnnotations }}
  annotations: {{- include "harnesscommon.tplvalues.render" ( dict "value" $.Values.global.commonAnnotations "context" $ ) | nindent 4 }}
  {{- end }}
spec:
  {{- $minAvailable := "" }}
  {{- $maxUnavailable := "" }}

  {{/* Priority: global < legacy root < configPath */}}
  {{- if $.Values.global.pdb.minAvailable }}
      {{- $minAvailable = $.Values.global.pdb.minAvailable }}
  {{- end }}
  {{- if and (not .configPath) $.Values.pdb.minAvailable }}
      {{- $minAvailable = $.Values.pdb.minAvailable }}
  {{- end }}
  {{- if and .configPath $config.pdb.minAvailable }}
      {{- $minAvailable = $config.pdb.minAvailable }}
  {{- end }}

  {{- if $.Values.global.pdb.maxUnavailable }}
      {{- $maxUnavailable = $.Values.global.pdb.maxUnavailable }}
  {{- end }}
  {{- if and (not .configPath) $.Values.pdb.maxUnavailable }}
      {{- $maxUnavailable = $.Values.pdb.maxUnavailable }}
  {{- end }}
  {{- if and .configPath $config.pdb.maxUnavailable }}
      {{- $maxUnavailable = $config.pdb.maxUnavailable }}
  {{- end }}

  {{- if $minAvailable }}
  minAvailable: {{ $minAvailable }}
  {{- else }}
  {{- if $maxUnavailable }}
  maxUnavailable: {{ $maxUnavailable }}
  {{- else }}
  minAvailable: "50%"
  {{- end }}
  {{- end }}
  {{- $selectorLabelsBase := default $.Chart.Name $.Values.nameOverride }}
  {{- if .nameOverride }}
    {{- $selectorLabelsBase = .nameOverride }}
  {{- end }}
  {{- $selectorFunction := printf "%s.selectorLabels" $selectorLabelsBase }}
  selector:
    matchLabels: {{ include $selectorFunction $ | nindent 6 }}
  {{- $unhealthyPodEvictionPolicy := "" }}
  {{- if $.Values.global.pdb.unhealthyPodEvictionPolicy }}
      {{- $unhealthyPodEvictionPolicy = $.Values.global.pdb.unhealthyPodEvictionPolicy }}
  {{- end }}
  {{- if and (not .configPath) $.Values.pdb.unhealthyPodEvictionPolicy }}
      {{- $unhealthyPodEvictionPolicy = $.Values.pdb.unhealthyPodEvictionPolicy }}
  {{- end }}
  {{- if and .configPath $config.pdb.unhealthyPodEvictionPolicy }}
      {{- $unhealthyPodEvictionPolicy = $config.pdb.unhealthyPodEvictionPolicy }}
  {{- end }}
  {{- if $unhealthyPodEvictionPolicy }}
  unhealthyPodEvictionPolicy: {{ $unhealthyPodEvictionPolicy }}
  {{- end }}
{{- end }}
{{- end }}
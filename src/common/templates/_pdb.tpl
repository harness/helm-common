{{/*
Create Pod Distribution Budget Configurations
Usage example:
{{- include "harnesscommon.pdb.renderPodDistributionBudget" . }}
*/}}
{{- define "harnesscommon.pdb.renderPodDistributionBudget" -}}
{{- $ := .ctx }}
{{- if or $.Values.global.pdb.create $.Values.pdb.create }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
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

  {{- if $.Values.global.pdb.minAvailable }}
      {{- $minAvailable = $.Values.global.pdb.minAvailable }}
  {{- end }}
  {{- if $.Values.pdb.minAvailable }}
      {{- $minAvailable = $.Values.pdb.minAvailable }}
  {{- end }}
  {{- if $.Values.global.pdb.maxUnavailable }}
      {{- $maxUnavailable = $.Values.global.pdb.maxUnavailable }}
  {{- end }}
  {{- if $.Values.pdb.maxUnavailable }}
      {{- $maxUnavailable = $.Values.pdb.maxUnavailable }}
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
  {{- $selectorFunction := printf "%s.selectorLabels" (default $.Chart.Name $.Values.nameOverride) }}
  selector:
    matchLabels: {{ include $selectorFunction $ | nindent 6 }}
{{- end }}
{{- end }}
{{/*
Create Pod Distribution Budget Configurations
Usage example:
{{- include "harnesscommon.pdb.renderPodDistributionBudget" . }}
*/}}
{{- define "harnesscommon.pdb.renderPodDistributionBudget" -}}
{{- $ := .ctx }}
{{- if or $.Values.global.pdb.create $.Values.pdb.create }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ default $.Chart.Name $.Values.nameOverride | trunc 63 | trimSuffix "-" }}
  namespace: {{ $.Release.Namespace }}
  {{- if $.Values.global.commonLabels }}
  labels: {{- include "harnesscommon.tplvalues.render" ( dict "value" .Values.global.commonLabels "context" $ ) | nindent 4 }}
  {{- end }}
  {{- if $.Values.global.commonAnnotations }}
  annotations: {{- include "harnesscommon.tplvalues.render" ( dict "value" .Values.global.commonAnnotations "context" $ ) | nindent 4 }}
  {{- end }}
spec:
  {{- $minAvailable := "50%" }}
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
  {{- end }}
  {{- if $maxUnavailable }}
  maxUnavailable: {{ $maxUnavailable }}
  {{- end }}
  {{- $selectorFunction := printf "%s.selectorLabels" $.Chart.Name }}
  selector:
    matchLabels: {{ include $selectorFunction $ | nindent 6 }}
{{- end }}
{{- end }}

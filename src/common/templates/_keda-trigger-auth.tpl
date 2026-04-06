{{/*
Create KEDA TriggerAuthentication for scaler credentials (optional).

Usage:
  Single deployment:
    {{- include "harnesscommon.keda.renderTriggerAuthentication" (dict "ctx" .) }}

  With name override:
    {{- include "harnesscommon.keda.renderTriggerAuthentication" (dict "ctx" . "nameOverride" "my-prometheus-auth") }}

  Multi-deployment with configPath:
    {{- include "harnesscommon.keda.renderTriggerAuthentication" (dict "ctx" . "configPath" .Values.worker "nameOverride" "worker-keda-auth") }}

Parameters:
  - ctx: Required. Root context (.)
  - nameOverride: Optional. TriggerAuthentication resource name (default: from keda.triggerAuthentication.name or release fullname + -keda-auth).
  - configPath: Optional. Values path for this deployment. If not set, uses $.Values.

Values (under keda or configPath.keda):
  - triggerAuthentication.create: If true, create the TriggerAuthentication.
  - triggerAuthentication.name: Resource name (used if nameOverride not provided).
  - triggerAuthentication.spec: Full KEDA TriggerAuthentication spec (passthrough). e.g. podIdentity, secretTargetRef, env.
*/}}
{{- define "harnesscommon.keda.renderTriggerAuthentication" -}}
{{- $ := .ctx }}
{{- $config := $.Values }}
{{- if .configPath }}
  {{- $config = .configPath }}
{{- end }}

{{- if and $config.keda $config.keda.triggerAuthentication (index $config.keda.triggerAuthentication "create") $config.keda.triggerAuthentication.spec }}
{{- $ta := $config.keda.triggerAuthentication }}
{{- $authName := default (printf "%s-keda-auth" (include "harnesscommon.names.fullname" $)) $ta.name }}
{{- if .nameOverride }}
  {{- $authName = .nameOverride }}
{{- end }}
{{- $labelsFunction := printf "%s.labels" (default $.Chart.Name $.Values.nameOverride) }}
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: {{ $authName | trunc 63 | trimSuffix "-" }}
  namespace: {{ include "harnesscommon.names.namespace" $ }}
  labels:
    {{- include $labelsFunction $ | nindent 4 }}
    {{- if $.Values.global.commonLabels }}
    {{- include "harnesscommon.tplvalues.render" (dict "value" $.Values.global.commonLabels "context" $) | nindent 4 }}
    {{- end }}
spec:
  {{- include "harnesscommon.tplvalues.render" (dict "value" $ta.spec "context" $) | nindent 2 }}
{{- end }}
{{- end -}}

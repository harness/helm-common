{{/* vim: set filetype=mustache: */}}

{{/*
Templates determining which Kubernetes API versions to use for required API
kinds.
*/}}

{{/*
Define which `policy` apiVersion to use. Relevant kinds include:
- PodDisruptionBudget

Usage:
{{ include "harnesscommon.apiVersions.policy" $ }}

Params:
  - root context
*/}}
{{- define "harnesscommon.apiVersions.policy" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}
policy/v1
{{- else if .Capabilities.APIVersions.Has "policy/v1beta1" -}}
policy/v1beta1
{{- else -}}
{{- fail "no compatible 'policy' API version was found; ensure available Kubernetes APIs satisfy Harness compatibility requirements" -}}
{{- end -}}
{{- end -}}

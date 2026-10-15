{{/*
Render Harness Engine custom resources from values.

Usage:
  {{- include "harnesscommon.engine.renderResources" (dict "ctx" .) }}

Values:
  engineResources:
    schedules:
      <name>:             # rendered as metadata.name "<release name>-<name>"
        enabled: true     # optional; only false skips the entry
        spec: {}          # required; copied verbatim

Renders nothing for a kind whose API the cluster does not serve (.Capabilities.APIVersions).
With `helm template`, pass --api-versions engine.harness.io/v1alpha1/Schedule.
*/}}
{{- define "harnesscommon.engine.renderResources" -}}
{{- $ctx := .ctx }}
{{- $resources := $ctx.Values.engineResources | default dict }}
{{- include "harnesscommon.engine.renderKind" (dict "ctx" $ctx "apiVersion" "engine.harness.io/v1alpha1" "kind" "Schedule" "valuesKey" "schedules" "entries" ($resources.schedules | default dict)) }}
{{- end -}}

{{- define "harnesscommon.engine.renderKind" -}}
{{- $ctx := .ctx }}
{{- $apiVersion := .apiVersion }}
{{- $kind := .kind }}
{{- $valuesKey := .valuesKey }}
{{- $entries := .entries }}
{{- if $ctx.Capabilities.APIVersions.Has (printf "%s/%s" $apiVersion $kind) }}
{{- range $name := keys $entries | sortAlpha }}
{{- $entry := index $entries $name | default dict }}
{{- if ne (toString (index $entry "enabled")) "false" }}
{{- if not $entry.spec }}
{{- fail (printf "engineResources.%s.%s.spec is required" $valuesKey $name) }}
{{- end }}
{{- $crName := printf "%s-%s" $ctx.Release.Name $name }}
{{- if gt (len $crName) 253 }}
{{- fail (printf "engineResources.%s.%s: resource name %q exceeds 253 characters" $valuesKey $name $crName) }}
{{- end }}
---
apiVersion: {{ $apiVersion }}
kind: {{ $kind }}
metadata:
  name: {{ $crName | quote }}
  namespace: {{ $ctx.Release.Namespace }}
  labels:
    {{- include "harnesscommon.labels.labels" $ctx | nindent 4 }}
spec:
  {{- toYaml $entry.spec | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

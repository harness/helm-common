{{/* Checks if Error Tracking Agent is enabled (either locally or globally).
Example:
{{ include "harnesscommon.cet.isAgentEnabled" (dict "context" $ )}}
*/}}
{{- define "harnesscommon.cet.isAgentEnabled" -}}
{{- $ := .ctx }}
{{- $isCetAgentEnabled := "false" -}}
{{- $localEnabled := default (dict) ((pluck "enabled" $.Values.cet.agent) | first) -}}
{{- $globalEnabled := default (dict) ((pluck "enabled" $.Values.global.cet.agent) | first) -}}
{{- if or $globalEnabled $localEnabled }}
    {{- $isCetAgentEnabled = "true" }}
{{- end }}
{{- print $isCetAgentEnabled }}
{{- end }}


{{/* Configurations to be added for java based applications' configmaps

1. The ET Agent requires an appName which matches a monitor-service defined in the
   target Harness Instance. This is the id so something like "pipeline-service" is "pipelineservice"
Example:
{{ include "harnesscommon.cet.config" (dict "ctx" $ "appName" "exampleservice") }}
*/}}
{{- define "harnesscommon.cet.config" -}}
  {{- $ := .ctx }}
  {{- $appName := .appName }}
  {{- $localCetEnabled :=  (pluck "enabled" $.Values.cet.agent) | first -}}
  {{- $globalCetEnabled := (pluck "enabled" $.Values.global.cet.agent) | first -}}
  {{- if or $localCetEnabled $globalCetEnabled -}}
ENABLE_ET: "true"
  {{- if $globalCetEnabled }}
ET_COLLECTOR_URL: {{ (pluck "collectorURL" $.Values.global.cet.agent | first )}}
  {{- else }}
ET_COLLECTOR_URL: {{ (pluck "collectorURL" $.Values.cet.agent) | first }}
  {{- end }}
ET_APPLICATION_NAME: {{ $appName  | quote }}
ET_ENV_ID: {{ $.Release.Namespace }}
ET_DEPLOYMENT_NAME: {{ $.Values.image.tag | quote }}
  {{- end -}}
{{- end -}}
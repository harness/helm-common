{{/* Configurations to be added for java based applications' configmaps
{{ include "harnesscommon.monitoring.config" . }}
*/}}
{{- define "harnesscommon.monitoring.config" -}}
{{- $localMonitoring := default (dict) ((pluck "monitoring" .Values) | first) -}}
{{- $globalMonitoring := default (dict) ((pluck "monitoring" .Values.global) | first) -}}
{{- $monitoring := (mergeOverwrite $globalMonitoring $localMonitoring ) -}}
{{- $enabled := (pluck "enabled" $monitoring) | first -}}
{{- $port := (pluck "port" $monitoring) | first -}}
ENABLE_PROMETHEUS_COLLECTOR: {{ default "false" $enabled | quote }}
PROMETHEUS_COLLECTOR_PORT: {{ default "8889" $port | quote }}
{{- end -}}

{{/* Generates monitoring annotations to be added for java based deployments
{{ include "harnesscommon.monitoring.annotations" . }}
*/}}
{{- define "harnesscommon.monitoring.annotations" -}}
{{- $localMonitoring := default (dict) ((pluck "monitoring" .Values) | first) -}}
{{- $globalMonitoring := default (dict) ((pluck "monitoring" .Values.global) | first) -}}
{{- $monitoring := (mergeOverwrite $globalMonitoring $localMonitoring ) }}
{{- $path := (pluck "path" $monitoring) | first }}
{{- $port := (pluck "port" $monitoring) | first }}
{{- $enabled := (pluck "enabled" $monitoring) | first }}
{{- if $enabled }}
prometheus.io/path: {{ $path | quote }}
prometheus.io/port: {{ default "8889" $port | quote }}
prometheus.io/scrape: {{ $enabled | quote}}
{{- end }}
{{- end -}}

{{/* Port to be added in deployment.yaml for java based applications
{{ include "harnesscommon.monitoring.containerPort" . }}
*/}}
{{- define "harnesscommon.monitoring.containerPort" -}}
{{- $localMonitoring := default (dict) ((pluck "monitoring" .Values) | first) -}}
{{- $globalMonitoring := default (dict) ((pluck "monitoring" .Values.global) | first) }}
{{- $monitoring := (mergeOverwrite $globalMonitoring $localMonitoring ) }}
{{- $port := (pluck "port" $monitoring) | first }}
{{- $enabled := (pluck "enabled" $monitoring) | first }}
{{- if $enabled }}
- name: metrics
  containerPort: {{ default "8889" $port }}
  protocol: "TCP"
{{- end }}
{{- end -}}

{{/* Podmonitor template to be added for Google Managed prometheus
{{ include "harnesscommon.monitoring.podMonitor" (dict "name" "ng-manager" "ctx" $ "label" "app.kubernetes.io/name") }}
*/}}
{{- define "harnesscommon.monitoring.podMonitor" -}}
{{- $ := .ctx }}
{{- $enabled := and $.Values.global.monitoring.enabled (eq $.Values.global.monitoring.managedPlatform "google") -}}
{{- $localMonitoring := default (dict) ((pluck "monitoring" $.Values) | first) -}}
{{- $globalMonitoring := default (dict) ((pluck "monitoring" $.Values.global) | first) -}}
{{- $monitoring := (mergeOverwrite $globalMonitoring $localMonitoring ) }}
{{- $port := (pluck "port" $monitoring) | first }}
{{- $path := (pluck "path" $monitoring) | first }}
{{- $namespace := $.Release.Namespace }}
{{- if $enabled -}}
apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: {{ $.Chart.Name }}
  namespace:  {{ $namespace }}
spec:
  selector:
    matchLabels:
      {{ .label }}: {{ default $.Chart.Name .name }}
  endpoints:
    - port: {{ default "8889" $port }}
      interval: 120s
      path: {{ default "/metrics" $path | quote }}
{{- end }}
{{- end -}}

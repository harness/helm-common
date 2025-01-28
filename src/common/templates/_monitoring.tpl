{{/* Configurations to be added for all applications' configmaps
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
{{- $otelEnabled := default false (or ((.Values.monitoring).otel).enabled (((.Values.global).monitoring).otel).enabled) }}
{{- $enableOtelVariable := default "ENABLE_OPENTELEMETRY" .enableOtelVariable }}
{{- $otelCollectorEndpoint := default "http://opentelemetry-collector-service.otel.svc.cluster.local:4317/" (default (((.Values.global).monitoring).otel).collectorEndpoint ((.Values.monitoring).otel).collectorEndpoint) }}
{{- $otelCollectorVariable := default "OTEL_EXPORTER_OTLP_ENDPOINT" .otelCollectorVariable }}
{{- $otelServiceNameVariable := default "OTEL_SERVICE_NAME" .otelServiceNameVariable}}
{{- if $otelEnabled }}
{{- printf "\n%s: '%s'" $otelCollectorVariable $otelCollectorEndpoint}}
{{- printf "\n%s: '%s'" $otelServiceNameVariable .Chart.Name }}
{{- printf "\n%s: '%t'" $enableOtelVariable $otelEnabled }}
{{- end }}
{{- end -}}

{{/* Generates monitoring annotations to be added all deployments
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

{{/* Port to be added in deployment.yaml for all applications
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

{{/* Podmonitor template to be added for Different prometheus CRDs google or oss
{{ include "harnesscommon.monitoring.podMonitor" (dict "name" "ng-manager" "ctx" $ "label" "app.kubernetes.io/name") }}
*/}}
{{- define "harnesscommon.monitoring.podMonitor" -}}
{{- $ := .ctx }}
{{- $googleEnabled := and $.Values.global.monitoring.enabled (eq $.Values.global.monitoring.managedPlatform "google") -}}
{{- $ossEnabled := and $.Values.global.monitoring.enabled (eq $.Values.global.monitoring.managedPlatform "oss") -}}
{{- $localMonitoring := default (dict) ((pluck "monitoring" $.Values) | first) -}}
{{- $globalMonitoring := default (dict) ((pluck "monitoring" $.Values.global) | first) -}}
{{- $monitoring := (mergeOverwrite $globalMonitoring $localMonitoring ) }}
{{- $port := (pluck "port" $monitoring) | first }}
{{- $path := (pluck "path" $monitoring) | first }}
{{- $interval := (pluck "interval" $monitoring) | first }}
{{- $namespace := $.Release.Namespace }}
{{- $podMonitorName := default $.Chart.Name .podMonitorName}}
{{- if $googleEnabled -}}
apiVersion: monitoring.googleapis.com/v1
kind: PodMonitoring
metadata:
  name: {{ $podMonitorName }}
  namespace: {{ $namespace }}
spec:
  selector:
    matchLabels:
      {{ .label }}: {{ default $.Chart.Name .name }}
  endpoints:
    - port: {{ default "8889" $port }}
      interval: 120s
      path: {{ default "/metrics" $path | quote }}
{{- end }}
{{- if $ossEnabled -}}
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ $podMonitorName }}
  namespace: {{ $namespace }}
  {{- if or (((.Values).monitoring).labels) (((.Values).global).commonLabels) }}
  labels:
    {{- if (((.Values).global).commonLabels) }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" (((.Values).global).commonLabels) "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if (((.Values).monitoring).labels) }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" (((.Values).monitoring).labels) "context" $ ) | nindent 4 }}
    {{- end }}
  {{- end }}
  {{- if or (((.Values).monitoring).annotations) (((.Values).global).commonAnnotations) }}
  annotations:
    {{- if (((.Values).monitoring).annotations) }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" (((.Values).monitoring).annotations) "context" $ ) | nindent 4 }}
    {{- end }}
    {{- if (((.Values).global).commonAnnotations) }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" (((.Values).global).commonAnnotations) "context" $ ) | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  selector:
    matchLabels:
      {{ .label }}: {{ default $.Chart.Name .name }}
  podMetricsEndpoints:
    - port: {{ default "8889" $port | quote }}
      interval: {{ default "120s" $interval }}
      path: {{ default "/metrics" $path | quote }}
      {{- include "harnesscommon.tplvalues.render" ( dict "value" ((($.Values).monitoring).PodMetricsEndpointsConfig) "context" $ ) | nindent 6 }}
    {{- include "harnesscommon.tplvalues.render" ( dict "value" ((($.Values).monitoring).additionalPodMetricsEndpoints) "context" $ ) | nindent 4 }}
  {{- include "harnesscommon.tplvalues.render" ( dict "value" ((($.Values).monitoring).additionalPodMonitorSpec) "context" $ ) | nindent 2 }}
{{- end }}
{{- end -}}
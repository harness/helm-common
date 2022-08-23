{{/*
Common labels
*/}}
{{- define "harnesscommon.labels.labels" -}}
helm.sh/chart: {{ include "harnesscommon.names.chart" . }}
{{ include "harnesscommon.labels.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "harnesscommon.labels.selectorLabels" -}}
app.kubernetes.io/name: {{ include "harnesscommon.names.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

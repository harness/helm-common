{{/*
Test chart must define <chartname>.labels and <chartname>.selectorLabels
because the library's HPA/PDB/KEDA templates call include with that name.
Delegate to the library's label helpers.
*/}}
{{- define "harness-common-test.labels" -}}
{{- include "harnesscommon.labels.labels" . }}
{{- end -}}

{{- define "harness-common-test.selectorLabels" -}}
{{- include "harnesscommon.labels.selectorLabels" . }}
{{- end -}}

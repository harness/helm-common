{{- define "harnesscommon.storage.class" -}}
{{- $storageClass := "" -}}
{{- if .global -}}
    {{- if .global.storageClass -}}
        {{- $storageClass = .global.storageClass -}}
    {{- end -}}
{{- end -}}
{{- if .persistence }}
    {{- if .persistence.storageClass -}}
        {{- $storageClass = .persistence.storageClass -}}
    {{- end }}
{{- end }}

{{- if $storageClass -}}
  {{- if (eq "-" $storageClass) -}}
      {{- printf "storageClassName: \"\"" -}}
  {{- else }}
      {{- printf "storageClassName: %s" $storageClass -}}
  {{- end -}}
{{- end -}}
{{- end -}}

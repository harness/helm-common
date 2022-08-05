{{/* vim: set filetype=mustache: */}}

{{/*
Generate container image name
*/}}
{{- define "harnesscommon.names.imagename" -}}
{{- if .Values.global.imageRegistryOverride -}}
{{- printf "%s/%s:%s" .Values.global.imageRegistryOverride ((splitList "/" .Values.image.repository) | last) .Values.image.tag -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
{{- end -}}


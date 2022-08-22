{{/* vim: set filetype=mustache: */}}

{{/*
Return proper image name
{{ include "harnesscommon.images.name" (dict "imageRoot" .Values.path.to.the.image "global" .Values.global )}}
*/}}
{{- define "harnesscommon.images.name " -}}
{{ include "common.images.image" (dict "imageRoot" .imageRoot "global" .global) }}
{{- end -}}


{{/*
Return the proper Docker Image Registry Secret Names evaluating values as templates
{{ include "common.images.renderPullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "context" $) }}
*/}}
{{- define "harnesscommon.images.renderPullSecrets" -}}
{{ include "common.images.renderPullSecrets" (dict "images" .images "context" .context )}}
{{- end -}}

{{/* vim: set filetype=mustache: */}}

{{/* This file is directly copied from BitNami's common chart.  We only use these methods, so including here instead of a full dependency /*}}

{{/*
Return the proper image name
{{ include "common.images.image" ( dict "imageRoot" .Values.path.to.the.image "global" $) }}
*/}}
{{- define "common.images.image" -}}
{{- $registryName := .imageRoot.registry -}}
{{- $repositoryName := .imageRoot.repository -}}
{{- $separator := ":" -}}
{{- $termination := "" -}}
{{- $ignoreGlobalImageRegistry := default false .imageRoot.ignoreGlobalImageRegistry }}
{{- $tag := default "" .imageRoot.tag -}}
{{- $digest := default "" .imageRoot.digest -}}
{{- $preferDigest := default false .global.preferDigest }}
{{- if .global }}
    {{- if and .global.imageRegistry (not $ignoreGlobalImageRegistry) }}
     {{- $registryName = .global.imageRegistry -}}
    {{- end -}}
{{- end -}}
{{- if and (ne $tag "") (ne $digest "") }}
    {{- if $preferDigest }}
        {{- if not (hasPrefix "sha256:" $digest) }}
            {{- fail (printf "Error: Digest must start with 'sha256:', got '%s'" $digest) -}}
        {{- end -}}
        {{- $separator = "@" -}}
        {{- $termination = $digest -}}
    {{- else }}
        {{- $separator = ":" -}}
        {{- $termination = $tag -}}
    {{- end -}}
{{- else if ne $digest "" }}
    {{- if not (hasPrefix "sha256:" $digest) }}
        {{- fail (printf "Error: Digest must start with 'sha256:', got '%s'" $digest) -}}
    {{- end -}}
    {{- $separator = "@" -}}
    {{- $termination = $digest -}}
{{- else if ne $tag "" }}
    {{- $separator = ":" -}}
    {{- $termination = $tag -}}
{{- else }}
    {{- fail "Error: Either tag or digest must be provided for the image!" -}}
{{- end -}}
{{- printf "%s/%s%s%s" $registryName $repositoryName $separator $termination -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names (deprecated: use common.images.renderPullSecrets instead)
{{ include "common.images.pullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "global" .Values.global) }}
*/}}
{{- define "common.images.pullSecrets" -}}
  {{- $pullSecrets := list }}

  {{- if .global }}
    {{- if .global.imagePullSecrets }}
      {{- range .global.imagePullSecrets -}}
        {{- $pullSecrets = append $pullSecrets . -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- if .pullSecrets }}
      {{- range .pullSecrets -}}
        {{- $pullSecrets = append $pullSecrets . -}}
      {{- end -}}
    {{- else if .imagePullSecrets }}
      {{- range .imagePullSecrets -}}
        {{- $pullSecrets = append $pullSecrets . -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names evaluating values as templates
{{ include "common.images.renderPullSecrets" ( dict "images" (list .Values.path.to.the.image1, .Values.path.to.the.image2) "context" $) }}
*/}}
{{- define "common.images.renderPullSecrets" -}}
  {{- $pullSecrets := list }}
  {{- $context := .context }}

  {{- if $context.Values.global }}
    {{- range $context.Values.global.imagePullSecrets -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
    {{- end -}}
  {{- end -}}

  {{- range .images -}}
    {{- range .pullSecrets -}}
      {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" . "context" $context)) -}}
    {{- end -}}
  {{- end -}}

  {{- if (not (empty $pullSecrets)) }}
imagePullSecrets:
    {{- range $pullSecrets }}
  - name: {{ . }}
    {{- end }}
  {{- end }}
{{- end -}}

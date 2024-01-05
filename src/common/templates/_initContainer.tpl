{{/* vim: set filetype=mustache: */}}

{{/*
Create initContainer with wait for label app

Usage:
{{ include "harnesscommon.initContainer.waitForApp" (dict "image" .Values.initContainer.image "app" "label.of.app.to.wait" "context" $) }}

Params:
  - app - String - Required, app to wait on
  - context - Object -Required. context scope
*/}}
{{- define "harnesscommon.initContainer.waitForApp" -}}
- name: waitForAppReady
  image: {{ include "common.images.image" (dict "imageRoot" .image "global" .context.global ) }}
  imagePullPolicy: IfNotPresent
  env:
    - name: APP
      value: .app
  command: ['sh', "-c"]
  args: ['while [[ $(kubectl get pods -l app=$(APP) -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done']
{{- end -}}


{{/*

Create initContainer with wait for label app
Usage: {{ include "common.initContainer.waitForContainer" (dict "root" . "containerName" "container-name" "appName" "app-name") }}

Params:
  - values - Object - Required. helm values
  - containerName - String - Required. name of the container to set
  - appName - String - Required. name of the app to wait for
*/}}

{{- define "common.initContainer.waitForContainer" -}}
{{- $values := .root.Values }}
{{- $local := $values.waitForInitContainer }}
{{- $global := $values.global.waitForInitContainer }}
{{- $containerNameDerived := printf "wait-for-%s" $.appName }}
{{- if .containerName }}
  {{- $containerNameDerived = $.containerName }}
{{- end }}

{{- if $local }}
  {{- if $local.enabled }}
- name: {{ $containerNameDerived }}
  image: {{ include "common.images.image" (dict "imageRoot" $local.image "global" $values.global) }}
  imagePullPolicy: {{ $local.image.pullPolicy }}
  {{- if $local.resources }}
  resources:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $local.resources "context" .root) | nindent 4 }}
  {{- end }}
  {{- if $local.containerSecurityContext }}
  securityContext:
    {{- toYaml $local.containerSecurityContext | nindent 4 }}
  {{- end }}
  args:
    - "pod"
    - "-lapp={{ .appName }}"
  {{- end }}
{{- else }}
  {{- if and $global $global.enabled }}
- name: {{ $containerNameDerived }}
  image: {{ include "common.images.image" (dict "imageRoot" $global.image "global" $values.global) }}
  imagePullPolicy: {{ $global.image.pullPolicy }}
  {{- if $global.resources }}
  resources:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $global.resources "context" .root) | nindent 4 }}
  {{- end }}
  {{- if $global.containerSecurityContext }}
  securityContext:
    {{- toYaml $global.containerSecurityContext | nindent 4 }}
  {{- end }}
  args:
    - "pod"
    - "-lapp={{ .appName }}"
  {{- end }}
{{- end }}
{{- end }}
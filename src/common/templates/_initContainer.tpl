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
Usage: {{ include "harnesscommon.initContainer.waitForContainer" (dict "root" . "containerName" "container-name" "appName" "app-name") }}

Params:
  - values - Object - Required. helm values
  - containerName - String - Optional. name of the container to set
  - appName - String - Required. name of the app to wait for
*/}}

{{- define "harnesscommon.initContainer.waitForContainer" -}}
{{- $values := .root.Values }}
{{- $local := $values.waitForInitContainer }}
{{- $global := $values.global.waitForInitContainer }}
{{- $containerNameDerived := printf "wait-for-%s" $.appName }}
{{- if .containerName }}
  {{- $containerNameDerived = .containerName }}
{{- end }}
{{- $globalCopy := deepCopy $global }}
{{- $waitForContainer := $globalCopy }}
{{- if $local }}
    {{- $waitForContainer = deepCopy $local | mergeOverwrite $globalCopy }}
{{- end }}
{{- if and $waitForContainer $waitForContainer.enabled }}
- name: {{ $containerNameDerived }}
  image: {{ include "common.images.image" (dict "imageRoot" $waitForContainer.image "global" $values.global) }}
  imagePullPolicy: {{ $waitForContainer.image.pullPolicy }}
  {{- if $waitForContainer.resources }}
  resources:
    {{- include "harnesscommon.tplvalues.render" (dict "value" $waitForContainer.resources "context" .root) | nindent 4 }}
  {{- end }}
  {{- if $waitForContainer.containerSecurityContext }}
  securityContext:
    {{- toYaml $waitForContainer.containerSecurityContext | nindent 4 }}
  {{- end }}
  args:
    - "pod"
    - "-lapp={{ .appName }}"
{{- end }}
{{- end }}
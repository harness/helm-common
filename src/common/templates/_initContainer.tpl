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
{{/*
Create an initContainer to copy files from a source to a destination.

Usage:
{{ include "harnesscommon.initContainer.setupWritable" (dict "image" .Values.image "imagePullPolicy" .Values.image.pullPolicy "sourcePath" "/opt/harness" "destinationPath" "/shared/volume" "volumeName" "harness-opt" "securityContext" .Values.securityContext "context" $) }}

Params:
  - image: String - Required. Container image.
  - imagePullPolicy: String - Optional. Image pull policy.
  - sourcePath: String - Required. Source path to copy from.
  - destinationPath: String - Required. Destination path to copy to.
  - volumeName: String - Required. Name of the volume to mount.
  - securityContext: Object - Optional. Security context for the container.
*/}}
{{- define "harnesscommon.initContainer.setupWritable" -}}
{{- $sourcePath := required "initContainer.setupWritable: sourcePath is required" .sourcePath }}
{{- $destinationPath := required "initContainer.setupWritable: destinationPath is required" .destinationPath }}
{{- $volumeName := required "initContainer.setupWritable: volumeName is required" .volumeName }}
{{- $values := .root.Values }}
- name: setup-harness-writable
  image: {{ include "common.images.image" (dict "imageRoot" $values.image "global" $values.global) }}
  imagePullPolicy: {{ $values.imagePullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      cp -r {{ .sourcePath }}/. {{ .destinationPath }}/
  volumeMounts:
    - name: {{ .volumeName }}
      mountPath: {{ .destinationPath }}
  {{- if $values.securityContext }}
  securityContext:
    {{- toYaml $values.securityContext | nindent 4 }}
  {{- end }}
{{- end }}

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
Create an initContainer to copy files from one or more sources to one or more destinations.

USAGE EXAMPLES:

# 1. Single Mount (Legacy/Backward Compatible)
{{ include "harnesscommon.initContainer.setupWritable" (dict
  "root" .
  "destinationPath" "/shared/volume"
  "sourcePath" "/opt/harness"
  "volumeName" "harness-opt"
) | nindent 8 }}

# 2. Multiple Mounts (Recommended for multiple sources/destinations)
{{ include "harnesscommon.initContainer.setupWritable" (dict
  "root" .
  "mounts" (list
    (dict "sourcePath" "/opt/ng-auth-ui" "destinationPath" "/shared/volume" "volumeName" "ng-auth-ui-opt")
    (dict "sourcePath" "/etc/nginx" "destinationPath" "/shared/nginx" "volumeName" "nginx-etc")
  )
) | nindent 8 }}

PARAMS:
  - root: Object - Required. Helm context scope (usually .)
  - sourcePath: String - Required for single mount. Source path to copy from.
  - destinationPath: String - Required for single mount. Destination path to copy to.
  - volumeName: String - Required for single mount. Name of the volume to mount.
  - mounts: List - Optional. List of maps, each with sourcePath, destinationPath, and volumeName.
  - image: String - Optional. Container image.
  - imagePullPolicy: String - Optional. Image pull policy.
  - securityContext: Object - Optional. Security context for the container.
*/}}
{{- define "harnesscommon.initContainer.setupWritable" -}}
{{- $values := .root.Values }}
- name: setup-harness-writable
  image: {{ include "common.images.image" (dict "imageRoot" $values.image "global" $values.global) }}
  imagePullPolicy: {{ $values.imagePullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      {{- if .mounts }}
      {{- range $i, $mnt := .mounts }}
        {{- $src := required (printf "initContainer.setupWritable: mounts[%d].sourcePath is required" $i) $mnt.sourcePath }}
        {{- $dst := required (printf "initContainer.setupWritable: mounts[%d].destinationPath is required" $i) $mnt.destinationPath }}
        {{- $vol := required (printf "initContainer.setupWritable: mounts[%d].volumeName is required" $i) $mnt.volumeName }}
      cp -r {{ $src }}/. {{ $dst }}/
      {{- end }}
      {{- else }}
        {{- $src := required "initContainer.setupWritable: sourcePath is required" .sourcePath }}
        {{- $dst := required "initContainer.setupWritable: destinationPath is required" .destinationPath }}
        {{- $vol := required "initContainer.setupWritable: volumeName is required" .volumeName }}
      cp -r {{ $src }}/. {{ $dst }}/
      {{- end }}
  volumeMounts:
    {{- if .mounts }}
    {{- range $i, $mnt := .mounts }}
      {{- $vol := required (printf "initContainer.setupWritable: mounts[%d].volumeName is required" $i) $mnt.volumeName }}
      {{- $dst := required (printf "initContainer.setupWritable: mounts[%d].destinationPath is required" $i) $mnt.destinationPath }}
    - name: {{ $vol }}
      mountPath: {{ $dst }}
    {{- end }}
    {{- else }}
    - name: {{ .volumeName }}
      mountPath: {{ .destinationPath }}
    {{- end }}
  {{- if $values.securityContext }}
  securityContext:
    {{- toYaml $values.securityContext | nindent 4 }}
  {{- end }}
{{- end }}
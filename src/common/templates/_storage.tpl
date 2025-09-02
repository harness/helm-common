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
{{/*
Define a list of volumes for a pod.

Usage:
{{ include "harnesscommon.volumes" (dict "volumes" (list (dict "name" "harness-opt") (dict "name" "tmp")) ) }}

Params:
  - volumes: List - Required. List of volume definitions, each as a dict:
      - name: String - Required.
*/}}
{{- define "harnesscommon.volumes" -}}
{{- range .volumes }}
- name: {{ .name }}
  emptyDir: {}
{{- end }}
{{- end }}
{{/*
Define a list of volumeMounts for a container.

Usage:
{{ include "harnesscommon.volumeMounts" (dict "mounts" (list (dict "name" "harness-opt" "mountPath" "/opt/harness") (dict "name" "tmp" "mountPath" "/tmp")) ) }}

Params:
  - mounts: List - Required. List of mount definitions, each as a dict:
      - name: String - Required. Name of the volume.
      - mountPath: String - Required. Path to mount the volume.
*/}}
{{- define "harnesscommon.volumeMounts" -}}
{{- range .mounts }}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
{{- end }}
{{- end }}
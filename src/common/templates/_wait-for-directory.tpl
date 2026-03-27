{{/* vim: set filetype=mustache: */}}

{{/*
Create an initContainer that waits for a directory to exist on the Kubernetes node.

USAGE EXAMPLE:

{{ include "harnesscommon.initContainer.waitForDirectory" (dict
  "root" .
  "directoryPath" "/var/lib/data"
  "containerName" "wait-for-data-dir"
  "image" .Values.busyboxImage
  "timeout" 300
) | nindent 8 }}

IMAGE OVERRIDE EXAMPLES:

# Override globally for all images
global:
  imageRegistry: my-registry.io

# Override per-template
image:
  registry: docker.io
  repository: busybox
  tag: "1.36"
  pullPolicy: IfNotPresent

PARAMS:
  - root: Object - Required. Helm context scope (usually .)
  - directoryPath: String - Required. The directory path on the node to wait for.
  - containerName: String - Optional. Name of the init container (default: wait-for-directory).
  - image: Object - Optional. Container image configuration.
      Default: {registry: "docker.io", repository: "busybox", tag: "1.36", pullPolicy: "IfNotPresent"}
      Respects global.imageRegistry override.
  - timeout: Integer - Optional. Maximum time in seconds to wait (default: 300).
  - checkInterval: Integer - Optional. Seconds between checks (default: 2).
*/}}
{{- define "harnesscommon.initContainer.waitForDirectory" -}}
{{- $values := .root.Values }}
{{- $directoryPath := required "initContainer.waitForDirectory: directoryPath is required" .directoryPath }}
{{- $containerName := .containerName | default "wait-for-directory" }}
{{- $timeout := .timeout | default 300 }}
{{- $checkInterval := .checkInterval | default 2 }}
{{- $image := .image | default (dict "registry" "docker.io" "repository" "busybox" "tag" "1.36" "pullPolicy" "IfNotPresent") }}
- name: {{ $containerName }}
  image: {{ include "common.images.image" (dict "imageRoot" $image "global" $values.global) }}
  imagePullPolicy: {{ $image.pullPolicy | default "IfNotPresent" }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      echo "Waiting for directory {{ $directoryPath }} to exist on node..."
      ELAPSED=0
      while [ ! -d "{{ $directoryPath }}" ]; do
        if [ $ELAPSED -ge {{ $timeout }} ]; then
          echo "Timeout after {{ $timeout }} seconds waiting for {{ $directoryPath }}"
          exit 1
        fi
        echo "Directory {{ $directoryPath }} does not exist yet. Waiting... ($ELAPSED/{{ $timeout }}s)"
        sleep {{ $checkInterval }}
        ELAPSED=$((ELAPSED + {{ $checkInterval }}))
      done
      echo "Directory {{ $directoryPath }} found!"
  volumeMounts:
    - name: host-directory-check
      mountPath: {{ $directoryPath }}
      readOnly: true
{{- end }}

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
  args: ['while [[ $(kubectl get pods -l app=$(APP) -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done'']
{{- end -}}

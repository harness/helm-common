{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.renderEnvironmentVars" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.renderEnvironmentVars" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: POD_NAME
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: metadata.name
- name: SERVICE_NAME
  value: {{ $.Chart.Name }}
- name: ENV_TYPE
  value: {{ default "default" $.Values.envType }}
- name: JFR_DUMP_ROOT_LOCATION
  value: {{ default "/opt/harness" $.Values.jfrDumpRootLocation }}
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.volumes" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.volumes" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: dumps
  hostPath:
    path: /var/dumps
    type: DirectoryOrCreate
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.volumeMounts" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: dumps
  mountPath: {{ default "/opt/harness" $.Values.jfrDumpRootLocation }}/dumps
{{- end }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.printJavaAdvancedFlags" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.printJavaAdvancedFlags" }}
{{- $ := .ctx }}
{{- $javaAdvancedFlags := default "" $.Values.javaAdvancedFlags }}
{{- $jfrDumpRootLocation := default "/opt/harness" $.Values.jfrDumpRootLocation }}
{{- $jfrFlags := printf "-XX:StartFlightRecording=disk=true,name=jfrRecording,maxage=12h,dumponexit=true,filename=%s/POD_NAME/jfr_dumponexit.jfr,settings=/opt/harness/profile.jfc -XX:FlightRecorderOptions=maxchunksize=20M,memorysize=20M,repository=%s/POD_NAME --add-reads jdk.jfr=ALL-UNNAMED -Dotel.instrumentation.redisson.enabled=false"  $jfrDumpRootLocation $jfrDumpRootLocation}}
{{- if $.Values.global.jfr.enabled }}
{{- $javaAdvancedFlags = printf "%s %s" $javaAdvancedFlags $jfrFlags }}
{{- end }}
{{- printf "%s" $javaAdvancedFlags }}
{{- end }}

{{/*
USAGE:
{{- include "harnesscommon.jfr.v1.initContainer" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.jfr.v1.initContainer" }}
{{- $ := .ctx }}
{{- if $.Values.global.jfr.enabled }}
- name: init-chmod
  image: {{ include "common.images.image" (dict "imageRoot" $.Values.jfr.image "global" $.Values.global) }}
  command: [ 'chmod', '-R', '777', '{{ default "/opt/harness" $.Values.jfrDumpRootLocation }}/dumps' ]
  volumeMounts:
  {{- include "harnesscommon.jfr.v1.volumeMounts" (dict "ctx" $) | indent 2 }}
{{- end }}
{{- end }}


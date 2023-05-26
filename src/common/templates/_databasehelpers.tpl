
{{- define "harnesscommon.dbconnection.dbenvuser" }}
{{- $dbType := upper .type }}
{{- $name := default (printf "%s_USER" $dbType) .variableName }}
- name: {{ $name }}
{{- if .userValue }}
  value: {{ printf "%s" .userValue }}
{{- else }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" .secret }}
      key: {{ printf "%s" .userKey }}
{{- end }}
{{- end }}

{{- define "harnesscommon.dbconnection.dbenvpassword" }}
{{- $dbType := upper .type }}
{{- $name := default (printf "%s_PASSWORD" $dbType) .variableName }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" .secret }}
      key: {{ printf "%s" .passwordKey }}
{{- end }}

{{- define "harnesscommon.dbconnection.connection" -}}
{{- $dbType := upper .type -}}
{{- $firsthost := (index .hosts 0) -}}
{{- $protocol := .protocol -}}
{{- $extraArgs := .extraArgs -}}
{{- $connectionString := (include "harnesscommon.dbconnection.singleConnectString" (dict "protocol" $protocol "host" $firsthost "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName) ) }}
{{- range $host := (rest .hosts) -}}
  {{- $connectionType := default "string" .connectionType }}
  {{- if eq $connectionType "string" }}
  {{- $connectionString = printf "%s,%s" $connectionString $host -}}
  {{- else }}
  {{- $connectionString = printf "%s,%s" $connectionString (include "harnesscommon.dbconnection.singleConnectString" . ) -}}
  {{- end }}
{{- end -}}
{{- if $extraArgs -}}
  {{- $connectionString = (printf "%s%s" $connectionString $extraArgs ) -}}
{{- end -}}
{{- printf "%s" $connectionString -}}
{{- end -}}

{{- define "harnesscommon.dbconnection.singleConnectString" }}
{{- $connectionString := "" }}
{{- if empty .protocol }}
  {{- $connectionString = (printf "%s" .host) }}
{{- else }}
  {{- if or (empty .userVariableName) (empty .passwordVariableName) }}
    {{- $connectionString = (printf "%s://%s" .protocol .host) -}}
  {{- else }}
    {{- $connectionString = (printf "%s://$(%s):$(%s)@%s" .protocol .userVariableName .passwordVariableName .host) -}}
  {{- end }}
{{- end }}
{{- printf "%s" $connectionString }}
{{- end }}

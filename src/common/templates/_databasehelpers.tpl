
{{/* Generates db user environment reference. If variableName is not provided, default one is generated using db type.
Secret and userValue are mutually exclusive
{{ include "harnesscommon.dbconnection.dbenvuser" (dict "type" "redis" "variableName" "REDIS_USER" "userValue" "test-user" "secret" "redis-secret" "userKey" "redis-user-key" )}}
*/}}
{{- define "harnesscommon.dbconnection.dbenvuser" }}
{{- $dbType := upper .type }}
{{- $name := default (printf "%s_USER" $dbType) .variableName }}
{{- if .userValue }}
- name: {{ $name }}
  value: {{ printf "%s" .userValue }}
{{- else if .userKey }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" .secret }}
      key: {{ printf "%s" .userKey }}
{{- end }}
{{- end }}

{{/* Generates db password environment reference. If variableName is not provided, default one is generated using db type.
{{ include "harnesscommon.dbconnection.dbenvpassword" (dict "type" "redis" "variableName" "REDIS_PASSWORD" "secret" "redis-secret" "passwordKey" "redis-password-key" )}}
*/}}
{{- define "harnesscommon.dbconnection.dbenvpassword" }}
{{- $dbType := upper .type }}
{{- $name := default (printf "%s_PASSWORD" $dbType) .variableName }}
{{- if .passwordKey }}
- name: {{ $name }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" .secret }}
      key: {{ printf "%s" .passwordKey }}
{{- end }}
{{- end }}

{{/* Generates db connection string. If userVariableName or passwordVariableName is not provided, no credentials are added to connection string.
If connectionType is set other than "string" then protocol and credentials are added to every host
{{ include "harnesscommon.dbconnection.connection" (dict "type" "redis" "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" "hosts" (list "redis-1:6379" "redis-2:6379") "protocol" "redis" "connectionType" "string" )}}
*/}}
{{- define "harnesscommon.dbconnection.connection" -}}
{{- $dbType := upper .type -}}
{{- $firsthost := (index .hosts 0) -}}
{{- $protocol := .protocol -}}
{{- $extraArgs := .extraArgs -}}
{{- $connectionString := (include "harnesscommon.dbconnection.singleConnectString" (dict "protocol" $protocol "host" $firsthost "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName) ) }}
{{- $localContext := . }}
{{- $connectionType := default "string" .connectionType }}
{{- range $host := (rest .hosts) -}}
  {{- if eq $connectionType "string" }}
  {{- $connectionString = printf "%s,%s" $connectionString $host -}}
  {{- else }}
  {{- $connectionString = printf "%s,%s" $connectionString (include "harnesscommon.dbconnection.singleConnectString" (dict "protocol" $protocol "host" $host "userVariableName" $localContext.userVariableName "passwordVariableName" $localContext.passwordVariableName) ) -}}
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

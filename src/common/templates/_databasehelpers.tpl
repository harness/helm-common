
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
{{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName -}}
{{- $connectionString := (printf "%s://$(%s):$(%s)@%s" $protocol $userVariableName $passwordVariableName $firsthost) -}}
{{- range $host := (rest .hosts) -}}
  {{- $connectionString = printf "%s,%s" $connectionString $host -}}
{{- end -}}
{{- if $extraArgs -}}
  {{- $connectionString = (printf "%s%s" $connectionString $extraArgs ) -}}
{{- end -}}
{{- printf "%s" $connectionString -}}
{{- end -}}

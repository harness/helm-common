{{- define "harnesscommon.dbconnection.dbenvuser" }}
{{- $dbType := upper .type }}
- name: {{ printf "%s_USER" $dbType }}
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
- name: {{ printf "%s_PASSWORD" $dbType }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" .secret }}
      key: {{ printf "%s" .passwordKey }}
{{- end }}

{{- define "harnesscommon.dbconnection.connection" }}
{{- $dbType := upper .type }}
{{- $firsthost := (index .hosts 0) }}
{{- $protocol := .protocol }}
{{- $extraArgs := .extraArgs }}
{{- $connectionString := (printf "%s://${%s_USER}:$(%s_PASSWORD)@%s" $protocol $dbType $dbType $firsthost) }}
{{- if $extraArgs }}
{{- $connectionString = (printf "%s%s" $connectionString $extraArgs ) }}
{{- end }}
{{- range $host := (rest .hosts) }}
{{- $connectionString = printf "%s,%s://${%s_USER}:$(%s_PASSWORD)@%s" $connectionString $protocol $dbType $dbType $host }}
{{- if $extraArgs }}
{{- $connectionString = (printf "%s%s" $connectionString $extraArgs ) }}
{{- end }}
{{- end}}
{{- printf "%s" $connectionString }}
{{- end }}

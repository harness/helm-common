{{/* Generates mongo environment variables
{{ include "harnesscommon.dbconnection.mongoEnv" . | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.mongoEnv" }}
{{- $type := "mongo" }}
{{- $installed := (pluck $type .Values.global.database | first ).installed }}
{{- $passwordSecret := (pluck $type .Values.global.database | first ).secretName }}
{{- $passwordKey := (pluck $type .Values.global.database | first).passwordKey }}
{{- $userKey := (pluck $type .Values.global.database | first).userKey }}
{{- if $installed }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" "harness-secrets" "userKey" "mongodbUsername") }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" "mongodb-replicaset-chart" "passwordKey" "mongodb-root-password" ) }}
{{- else }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret "userKey" $userKey) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- end }}
{{- end }}

{{/* Generates Mongo Connection string
{{ include "harnesscommon.dbconnection.mongoConnection" (dict "database" "foo" "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.mongoConnection" }}
{{- $type := "mongo" }}
{{- $hosts := (pluck $type .context.Values.global.database | first ).hosts }}
{{- $dbType := $type | upper}}
{{- $installed := (pluck $type .context.Values.global.database | first ).installed }}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- $extraArgs:= (pluck $type .context.Values.global.database | first ).extraArgs }}
{{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName -}}
{{- if $installed }}
  {{- $namespace := .context.Release.Namespace }}
  {{- if .context.Values.global.ha -}}
{{- printf "'mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $namespace $namespace $namespace .database -}}
  {{- else }}
{{- printf "'mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $namespace .database -}}
  {{- end }}
{{- else }}
{{- $args := (printf "/%s?%s" .database $extraArgs )}}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
{{- end }}
{{- end }}

{{/* Generates postgres environment variables
{{ include "harnesscommon.dbconnection.postgresEnv" . | nindent 10 }}
*/}}
{{- define "harnesscommon.dbconnection.postgresEnv" }}
{{- $type := "postgres" }}
{{- $passwordSecret := (pluck $type .Values.global.database | first ).secretName }}
{{- $passwordKey := (pluck $type .Values.global.database | first).passwordKey }}
{{- $userKey := (pluck $type .Values.global.database | first).userKey }}
{{- $installed := (pluck $type .Values.global.database | first).installed }}
{{- if $installed }}
{{- $passwordSecret := ( .Values.postgresPassword ).name }}
{{- $passwordKey := ( .Values.postgresPassword ).key }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret "userValue" "postgres" ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- else }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret  "userKey" $userKey ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- end }}
{{- end }}

{{/* Generates Postgres Connection string
{{ include "harnesscommon.dbconnection.postgresConnection" (dict "database" "foo" "args" "bar" "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.postgresConnection" }}
{{- $type := "postgres" }}
{{- $dbType := upper $type }}
{{- $hosts := (pluck $type .context.Values.global.database | first ).hosts }}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- $installed := (pluck $type .context.Values.global.database | first).installed }}
{{- $extraArgs:= (pluck $type .context.Values.global.database | first ).extraArgs }}
{{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName -}}
{{- if $installed }}
{{- $connectionString := (printf "%s://$(%s_USER):$(%s_PASSWORD)@%s/%s?%s" "postgres" $dbType $dbType "postgres:5432" .database .args) }}
{{- printf "%s" $connectionString }}
{{- else }}
{{- $paramArgs := default "" .args }}
{{- $finalArgs := (printf "/%s" .database) }}
{{- if and $paramArgs $extraArgs }}
{{- $finalArgs = (printf "%s?%s&%s" $finalArgs $paramArgs $extraArgs) }}
{{- else if or $paramArgs $extraArgs }}
{{- $finalArgs = (printf "%s?%s" $finalArgs (default $paramArgs $extraArgs)) }}
{{- end }}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $finalArgs "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
{{- end }}
{{- end }}

{{/* Generates TimeScale environment variables
{{ include "harnesscommon.dbconnection.timescaleEnv" (dict "passwordVariableName" "TIMESCALEDB_PASSWORD" "userVariableName" "TIMESCALEDB_USERNAME" "context" $) | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.timescaleEnv" }}
{{- $type := "timescaledb" }}
{{- $dbType := upper $type }}
{{- $passwordSecret := (pluck $type .context.Values.global.database | first ).secretName }}
{{- $passwordKey := (pluck $type .context.Values.global.database | first).passwordKey }}
{{- $userKey := (pluck $type .context.Values.global.database | first).userKey }}
{{- $installed := (pluck $type .context.Values.global.database | first).installed }}
{{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName -}}
{{- if $installed }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "variableName" $userVariableName "secret" $passwordSecret "userValue" "postgres" ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "variableName" $passwordVariableName "secret" "harness-secrets" "passwordKey" "timescaledbPostgresPassword" ) }}
{{- else }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "variableName" $userVariableName "secret" $passwordSecret  "userKey" $userKey ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "variableName" $passwordVariableName "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- end }}
{{- end }}

{{/* Generates TimeScale environment variables
{{ include "harnesscommon.dbconnection.timescaleSslEnv" . | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.timescaleSslEnv" }}
{{- $type := "timescaledb" }}
{{- $dbType := upper $type }}
{{- $certSecret := (pluck $type .context.Values.global.database | first ).certName }}
{{- $certKey := (pluck $type .context.Values.global.database | first).certKey }}
{{- $sslEnabled := (pluck $type .context.Values.global.database | first).sslEnabled }}
{{- if $sslEnabled }}
{{- if .certPathValue }}
{{- $certPathVariableName := default (printf "%s_SSL_CERT_PATH" $dbType) .certPathVariableName -}}
- name: {{ $certPathVariableName }}
  value: {{ printf "%s\n" .certPathValue }}
{{- end }}
{{- if .enableSslVariableName }}
- name: {{ printf "%s" .enableSslVariableName }}
  value: {{ (printf "%s\n" "'true'") }}
{{- end }}
{{- if .certVariableName }}
- name: {{ .certVariableName  }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" $certSecret }}
      key: {{ printf "%s\n" $certKey }}
{{- end }}
{{- if .sslModeValue }}
{{- $sslModeVariableName := default (printf "%s_SSL_MODE" $dbType) .sslModeVariableName -}}
- name: {{ $sslModeVariableName }}
  value: {{ printf "%s\n" .sslModeValue }}
{{- end }}
{{- end }}
{{- end }}

{{- define "harnesscommon.dbconnection.timescaleHost" }}
{{- $connectionString := "" }}
{{- $type := "timescaledb" }}
{{- $installed := (pluck $type .context.Values.global.database | first).installed }}
{{- if $installed }}
{{- printf "%s.%s" "timescaledb-single-chart" .context.Release.Namespace }}
{{- else }}
{{- printf "%s"  (split ":" (index .context.Values.global.database.timescaledb.hosts 0))._0 }}
{{- end }}
{{- end }}

{{- define "harnesscommon.dbconnection.timescalePort" }}
{{- $connectionString := "" }}
{{- $type := "timescaledb" }}
{{- $installed := (pluck $type .context.Values.global.database | first).installed }}
{{- if $installed }}
{{- printf "%s" "5432" }}
{{- else }}
{{- printf "%s" (split ":" (index .context.Values.global.database.timescaledb.hosts 0))._1 }}
{{- end }}
{{- end }}

{{/* Generates Timescale Connection string
{{ include "harnesscommon.dbconnection.timescaleConnection" (dict "database" "foo" "args" "bar" "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.timescaleConnection" }}
{{- $host := include "harnesscommon.dbconnection.timescaleHost" (dict "context" .context ) }}
{{- $port := include "harnesscommon.dbconnection.timescalePort" (dict "context" .context ) }}
{{- $connectionString := "" }}
{{- $protocol := "" }}
{{- if not (empty .protocol) }}
{{- $protocol = (printf "%s://" .protocol) }}
{{- end }}
{{- $userAndPassField := "" }}
{{- if and (.userVariableName) (.passwordVariableName) }}
{{- $userAndPassField = (printf "$(%s):$(%s)@" .userVariableName .passwordVariableName) }}
{{- end }}
{{- $connectionString = (printf "%s%s%s:%s/%s" $protocol $userAndPassField  $host $port .database) }}
{{- if .args }}
{{- $connectionString = (printf "%s?%s" $connectionString .args) }}
{{- end }}
{{- printf "%s" $connectionString -}}
{{- end }}

{{/* Generates Redis environment variables
{{ include "harnesscommon.dbconnection.redisEnv" (dict "context" .Values.global.database.redis "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD") | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.redisEnv" }}
{{- $type := "redis" }}
{{- $dbType := $type | upper}}
{{- $passwordSecret := .context.secretName }}
{{- $passwordKey := .context.passwordKey }}
{{- $userKey := .context.userKey }}
{{- $installed := .context.installed }}
{{- if and (not $installed) $passwordSecret }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret  "userKey" $userKey "variableName" .userVariableName ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey "variableName" .passwordVariableName ) }}
{{- end }}
{{- end }}

{{/* Outputs whether redis password is set or not
{{ include "harnesscommon.dbconnection.isRedisPasswordSet" (dict "context" .Values.global.database.redis) }}
*/}}
{{- define "harnesscommon.dbconnection.isRedisPasswordSet" }}
{{- $passwordSecret := .context.secretName }}
{{- $passwordKey := .context.passwordKey }}
{{- $installed := .context.installed }}
{{- if and (not $installed) $passwordSecret $passwordKey }}
{{- printf "true" }}
{{- else }}
{{- printf "false" }}
{{- end }}
{{- end }}

{{/* Generates Redis Connection string. If userVariableName or passwordVariableName is not provided, a connection string is generated without creds
{{ include "harnesscommon.dbconnection.redisConnection" (dict "context" .Values.global.database.redis "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" )}}
*/}}
{{- define "harnesscommon.dbconnection.redisConnection" -}}
{{- $type := "redis" -}}
{{- $hosts := .context.hosts -}}
{{- $protocol := .context.protocol -}}
{{- if .context.installed -}}
  {{- $hosts = list "redis-sentinel-harness-announce-0:26379" "redis-sentinel-harness-announce-1:26379" "redis-sentinel-harness-announce-2:26379" }}
{{- end -}}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" .context.extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
{{- end -}}

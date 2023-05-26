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
{{- $installed := (pluck $type .context.Values.global.database | first ).installed }}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- $extraArgs:= (pluck $type .context.Values.global.database | first ).extraArgs }}
{{- $userVariableName := default (printf "%s_USER" $type) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $type) .passwordVariableName -}}
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
{{ include "harnesscommon.dbconnection.postgresConnection" (dict "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.postgresConnection" }}
{{- $type := "postgres" }}
{{- $dbType := upper $type }}
{{- $hosts := (pluck $type .context.Values.global.database | first ).hosts }}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- $installed := (pluck $type .context.Values.global.database | first).installed }}
{{- $userVariableName := default (printf "%s_USER" $type) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $type) .passwordVariableName -}}
{{- if $installed }}
{{- $connectionString := (printf "%s://$(%s_USER):$(%s_PASSWORD)@%s" "postgres" $dbType $dbType "postgres:5432") }}
{{- printf "%s" $connectionString }}
{{- else }}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
{{- end }}
{{- end }}

{{/* Generates TimeScale environment variables
{{ include "harnesscommon.dbconnection.timescaleEnv" . | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.timescaleEnv" }}
{{- $type := "timescaledb" }}
{{- $passwordSecret := (pluck $type .Values.global.database | first ).secretName }}
{{- $passwordKey := (pluck $type .Values.global.database | first).passwordKey }}
{{- $userKey := (pluck $type .Values.global.database | first).userKey }}
{{- $installed := (pluck $type .Values.global.database | first).installed }}
{{- if $installed }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret "userValue" "postgres" ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" "harness-secrets" "passwordKey" "timescaledbPostgresPassword" ) }}
{{- else }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret  "userKey" $userKey ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- end }}
{{- end }}

{{/* Generates Timescale Connection string
{{ include "harnesscommon.dbconnection.timescaleConnection" (dict "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.timescaleConnection" }}
{{- $type := "timescaledb" }}
{{- $hosts := (pluck $type .context.Values.global.database | first ).hosts }}
{{- $userVariableName := default (printf "%s_USER" $type) .userVariableName -}}
{{- $passwordVariableName := default (printf "%s_PASSWORD" $type) .passwordVariableName -}}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" "/harness" "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName) }}
{{- end}}

{{/* Generates Redis environment variables
{{ include "harnesscommon.dbconnection.redisEnv" (dict "context" .Values.global.database.redis "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD") | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.redisEnv" }}
{{- $type := "redis" }}
{{- $passwordSecret := .context.secretName }}
{{- $passwordKey := .context.passwordKey }}
{{- $userKey := .context.userKey }}
{{- $installed := .context.installed }}
{{- if not $installed }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret  "userKey" $userKey "variableName" .userVariableName ) }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey "variableName" .passwordVariableName ) }}
{{- end }}
{{- end }}

{{/* Generates Redis Connection string. If userVariableName or passwordVariableName is not provided, a connection string is generated without creds
{{ include "harnesscommon.dbconnection.redisConnection" (dict "context" .Values.global.database.redis "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" )}}
*/}}
{{- define "harnesscommon.dbconnection.redisConnection" -}}
{{- $type := "redis" -}}
{{- $hosts := .context.hosts -}}
{{- $protocol := .context.protocol -}}
{{- if and (.context.installed) (empty $hosts) -}}
  {{- $hosts = list "redis-sentinel-harness-announce-0:26379" "redis-sentinel-harness-announce-1:26379" "redis-sentinel-harness-announce-2:26379" }}
{{- end -}}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" .context.extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
{{- end -}}

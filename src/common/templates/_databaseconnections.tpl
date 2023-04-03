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
{{- if $installed }}
  {{ $namespace := .context.Release.Namespace}}
  {{- if .context.Values.global.ha -}}
{{- printf "'mongodb://$(MONGO_USERNAME):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $namespace $namespace $namespace .database -}}
  {{- else }}
{{- printf "'mongodb://$(MONGO_USERNAME):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $namespace .database -}}
  {{- end }}
{{- else }}
{{- $args := (printf "/%s?%s" .database $extraArgs )}}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $args )}}
{{- end }}
{{- end }}

{{/* Generates postgres environment variables
{{ include "harnesscommon.dbconnection.postgresEnv" . | nident 10 }}
*/}}
{{- define "harnesscommon.dbconnection.postgresEnv" }}
{{- $type := "postgres" }}
{{- $passwordSecret := (pluck $type .Values.global.database | first ).secretName }}
{{- $passwordKey := (pluck $type .Values.global.database | first).passwordKey }}
{{- $userKey := (pluck $type .Values.global.database | first).userKey }}
{{- $installed := (pluck $type .Values.global.database | first).installed }}
{{- if $installed }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret "userValue" "postgres" ) }}
{{- else }}
{{- include "harnesscommon.dbconnection.dbenvuser" (dict "type" $type "secret" $passwordSecret  "userKey" $userKey ) }}
{{- end }}
{{- include "harnesscommon.dbconnection.dbenvpassword" (dict "type" $type "secret" $passwordSecret "passwordKey" $passwordKey ) }}
{{- end }}

{{/* Generates Postgres Connection string
{{ include "harnesscommon.dbconnection.postgresConnection" (dict "context" $) }}
*/}}
{{- define "harnesscommon.dbconnection.postgresConnection" }}
{{- $type := "postgres" }}
{{- $hosts := (pluck $type .context.Values.global.database | first ).hosts }}
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol )}}
{{- end}}

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
{{- $protocol := (pluck $type .context.Values.global.database | first ).protocol }}
{{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" "/harness") }}
{{- end}}

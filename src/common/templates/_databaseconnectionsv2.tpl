{{/*
Generates TimescaleDB environment variables

USAGE:
{{ include "harnesscommon.dbconnectionv2.timescaleEnv" (dict "ctx" . "localTimescaleDBCtx" .Values.timescaledb "globalTimescaleDBCtx" .Values.global.database.timescaledb) | indent 12 }}
*/}}
{{- define "harnesscommon.dbconnectionv2.timescaleEnv" }}
    {{- $ := .ctx }}
    {{- $localTimescaleDBCtx := $.Values.timescaledb }}
    {{- if .localTimescaleDBCtx }}
        {{- $localTimescaleDBCtx = .localTimescaleDBCtx }}
    {{- end }}
    {{- $globalTimescaleDBCtx := $.Values.global.database.timescaledb }}
    {{- if .globalTimescaleDBCtx }}
        {{- $globalTimescaleDBCtx = .globalTimescaleDBCtx }}
    {{- end }}
    {{- if and $ $localTimescaleDBCtx $globalTimescaleDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalTimescaleDBCtx.installed true }}
            {{- $installed = $globalTimescaleDBCtx.installed }}
        {{- end }}
        {{- $localTimescaleDBESOSecretIdentifier := include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $  "additionalCtxIdentifier" "timescaledb") }}
        {{- $globalTimescaleESOSecretIdentifier := include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $  "ctxIdentifier" "timescaledb") }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "defaultValue" "postgres" "defaultKubernetesSecretName" "" "defaultKubernetesSecretKey" "" "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "timescaledbPostgresPassword" "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "defaultKubernetesSecretName" $globalTimescaleDBCtx.secretName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.userKey "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "defaultKubernetesSecretName" $globalTimescaleDBCtx.secretName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
        {{- $sslEnabled := false }}
        {{- $sslEnabledVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "bool" "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled"))) }}
        {{- if eq $sslEnabledVar "true" }}
            {{- $sslEnabled = true }}
        {{- end }}
        {{- if $sslEnabled }}
- name: TIMESCALEDB_SSL_MODE
  value: require
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_SSL_ROOT_CERT" "defaultKubernetesSecretName" $globalTimescaleDBCtx.certName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.certKey  "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}

{{- define "harnesscommon.dbconnectionv2.timescaleHost" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "timescaledb" }}
    {{- $installed := (pluck $type $.Values.global.database | first).installed }}
    {{- if $installed }}
        {{- printf "%s.%s" "timescaledb-single-chart" $.Release.Namespace }}
    {{- else }}
        {{- $hosts := list }}
        {{- if gt (len $.Values.timescaledb.hosts) 0 }}
            {{- $hosts = $.Values.timescaledb.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.timescaledb.hosts }}
        {{- end }}
    {{- printf "%s"  (split ":" (index $hosts 0))._0 }}
    {{- end }}
{{- end }}

{{- define "harnesscommon.dbconnectionv2.timescalePort" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "timescaledb" }}
    {{- $installed := (pluck $type $.Values.global.database | first).installed }}
    {{- if $installed }}
        {{- printf "%s" "5432" }}
    {{- else }}
        {{- $hosts := list }}
        {{- if gt (len $.Values.timescaledb.hosts) 0 }}
            {{- $hosts = $.Values.timescal.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.mongo.hosts }}
        {{- end }}
        {{- printf "%s" (split ":" (index $.Values.global.database.timescaledb.hosts 0))._1 }}
    {{- end }}
{{- end }}

{{/*
Generates Timescale Connection string

USAGE:
{{ include "harnesscommon.dbconnectionv2.timescaleConnection" (dict "database" "foo" "args" "bar" "context" $) }}
*/}}
{{- define "harnesscommon.dbconnectionv2.timescaleConnection" }}
    {{- $host := include "harnesscommon.dbconnectionv2.timescaleHost" (dict "context" .context ) }}
    {{- $port := include "harnesscommon.dbconnectionv2.timescalePort" (dict "context" .context ) }}
    {{- $connectionString := "" }}
    {{- $protocol := "" }}
    {{- if not (empty .protocol) }}
        {{- $protocol = (printf "%s://" .protocol) }}
    {{- end }}
    {{- $protocolVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "keys" (list ".Values.global.database.timescaledb.protocol" ".Values.timescaledb.protocol"))) }}
    {{- if not (empty $protocolVar) }}
        {{- $protocol = (printf "%s://" $protocolVar) }}
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

{{/*
Generates Redis environment variables

USAGE:
{{ include "harnesscommon.dbconnectionv2.redisEnv" (dict "ctx" . "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" "localRedisCtx" .Values.redis "globalRedisCtx" .Values.global.database.redis) | indent 12 }}
*/}}
{{- define "harnesscommon.dbconnectionv2.redisEnv" }}
    {{- $ := .ctx }}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
    {{- if empty $userVariableName }}
    {{- $userVariableName = "REDIS_USERNAME" }}
    {{- end }}
    {{- if empty $passwordVariableName }}
    {{- $passwordVariableName = "REDIS_PASSWORD" }}
    {{- end }}
    {{- $localRedisCtx := $.Values.redis }}
    {{- if .localRedisCtx }}
        {{- $localRedisCtx = .localRedisCtx }}
    {{- end }}
    {{- $globalRedisCtx := $.Values.global.database.redis }}
    {{- if .globalRedisCtx }}
        {{- $globalRedisCtx = .globalRedisCtx }}
    {{- end }}
    {{- if and $ $localRedisCtx $globalRedisCtx }}
        {{- $installed := false }}
        {{- if eq $globalRedisCtx.installed true }}
            {{- $installed = $globalRedisCtx.installed }}
        {{- end }}
        {{- $localRedisESOSecretIdentifier := include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $  "additionalCtxIdentifier" "redis") }}
        {{- $globalRedisESOSecretIdentifier := include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $  "ctxIdentifier" "redis") }}
        {{- if not $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" $userVariableName "defaultKubernetesSecretName" $globalRedisCtx.secretName "defaultKubernetesSecretKey" $globalRedisCtx.userKey "extKubernetesSecretCtxs" (list $globalRedisCtx.secrets.kubernetesSecrets $localRedisCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalRedisESOSecretIdentifier "secretCtx" $globalRedisCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localRedisESOSecretIdentifier "secretCtx" $localRedisCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" $passwordVariableName "defaultKubernetesSecretName" $globalRedisCtx.secretName "defaultKubernetesSecretKey" $globalRedisCtx.passwordKey "extKubernetesSecretCtxs" (list $globalRedisCtx.secrets.kubernetesSecrets $localRedisCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalRedisESOSecretIdentifier "secretCtx" $globalRedisCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localRedisESOSecretIdentifier "secretCtx" $localRedisCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}

{{/*
Generates Redis Connection string. 
If userVariableName or passwordVariableName are not provided, a connection string is generated without creds

USAGE:
{{ include "harnesscommon.dbconnection.redisConnection" (dict "context" $ "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" )}}
*/}}
{{- define "harnesscommon.dbconnectionv2.redisConnection" }}
    {{- $ := .context }}
    {{- $type := "redis" }}
    {{- $localDBCtx := $.Values.redis }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- $hosts := list }}
    {{- $protocol := "" }}
    {{- $extraArgs := "" }}
    {{- if $globalDBCtx.installed }}
        {{- $protocol = $globalDBCtx.protocol }}
        {{- $hosts = list "redis-sentinel-harness-announce-0:26379" "redis-sentinel-harness-announce-1:26379" "redis-sentinel-harness-announce-2:26379" }}
        {{- $extraArgs = $globalDBCtx.extraArgs }}
    {{- else }}
        {{- $protocol = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.redis.protocol" ".Values.redis.protocol"))) }}
        {{- if gt (len $localDBCtx.hosts) 0 }}
            {{- $hosts = $localDBCtx.hosts }}
        {{- else }}
            {{- $hosts = $globalDBCtx.hosts }}
        {{- end }}
        {{- $extraArgs = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "keys" (list ".Values.global.database.mongo.extraArgs" ".Values.mongo.extraArgs"))) }}
    {{- end }}
    {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
{{- end }}

{{/*
Generates MongoDB environment variables

USAGE:
{{ include "harnesscommon.dbconnectionv2.mongoEnv" (dict "ctx" . "localDBCtx" .Values.mongo "globalDBCtx" .Values.global.database.mongo) | indent 12 }}
*/}}
{{- define "harnesscommon.dbconnectionv2.mongoEnv" }}
    {{- $ := .ctx }}

    {{- $localDBCtx := $.Values.mongo }}
    {{- if .localDBCtx }}
        {{- $localDBCtx = .localDBCtx }}
    {{- end }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if .globalDBCtx }}
        {{- $globalDBCtx = .globalDBCtx }}
    {{- end }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalDBCtx.installed true }}
            {{- $installed = $globalDBCtx.installed }}
        {{- end }}
        {{- $localMongoESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" "mongo" )) }}
        {{- $globalMongoESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "mongo" )) }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER" "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER" "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}

{{/*
Generates Mongo Connection string

USAGE:
{{ include "harnesscommon.dbconnectionv2.mongoConnection" (dict "ctx" $ "database" "foo") }}
*/}}
{{- define "harnesscommon.dbconnectionv2.mongoConnection" }}
    {{- $ := .ctx }}
    {{- $type := "mongo" }}
    {{- $dbType := $type | upper}}
    {{- $installed := true }}
    {{- if eq $.Values.global.database.mongo.installed false }}
        {{- $installed = false }}
    {{- end }}
    {{- $hosts := list }}
    {{- if gt (len $.Values.mongo.hosts) 0 }}
        {{- $hosts = $.Values.mongo.hosts }}
    {{- else }}
        {{- $hosts = $.Values.global.database.mongo.hosts }}
    {{- end }}
    {{- $protocol := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "keys" (list ".Values.global.database.mongo.protocol" ".Values.mongo.protocol"))) }}
    {{- $extraArgs := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "keys" (list ".Values.global.database.mongo.extraArgs" ".Values.mongo.extraArgs"))) }}
    {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
    {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
    {{- if $installed }}
        {{- $namespace := $.Release.Namespace }}
        {{- if $.Values.global.ha }}
        {{- printf "'mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $namespace $namespace $namespace .database }}
        {{- else }}
            {{- printf "'mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $namespace .database }}
        {{- end }}
    {{- else }}
        {{- $args := (printf "/%s?%s" .database $extraArgs )}}
        {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
    {{- end }}
{{- end }}

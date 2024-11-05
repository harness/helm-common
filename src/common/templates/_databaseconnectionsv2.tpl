{{/*
Generates TimescaleDB environment variables

USAGE:
{{ include "harnesscommon.dbconnectionv2.timescaleEnv" (dict "ctx" $ "userVariableName" "TIMESCALEDB_USERNAME" "passwordVariableName" "TIMESCALEDB_PASSWORD" "sslModeVariableName" "TIMESCALEDB_SSL_MODE" "certVariableName" "TIMESCALEDB_SSL_ROOT_CERT" "localTimescaleDBCtx" .Values.timescaledb "globalTimescaleDBCtx" .Values.global.database.timescaledb) | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. localTimescaleDBCtx
    DEFAULT: $.Values.timescaledb
2. globalTimescaleDBCtx
    DEFAULT: $.Values.global.database.timescaledb
3. userVariableName
    DEFAULT: TIMESCALEDB_USERNAME
4. passwordVariableName
    DEFAULT: TIMESCALEDB_PASSWORD
5. sslModeVariableName
6. sslModeValue
7. certVariableName
8. certPathVariableName
9. certPathValue


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
    {{- $userVariableName := default "TIMESCALEDB_USERNAME" .userVariableName }}
    {{- $passwordVariableName := default "TIMESCALEDB_PASSWORD" .passwordVariableName }}
    {{- $sslModeVariableName := default "TIMESCALEDB_SSL_MODE" .sslModeVariableName }}
    {{- $sslModeValue := "" }}
    {{- $handleSSLModeDisable := default false .handleSSLModeDisable }}
    {{- $certVariableName := default "TIMESCALEDB_SSL_ROOT_CERT" .certVariableName }}
    {{- $enableSslVariableName := default "" .enableSslVariableName }}
    {{- if and $ $localTimescaleDBCtx $globalTimescaleDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalTimescaleDBCtx.installed true }}
            {{- $installed = $globalTimescaleDBCtx.installed }}
        {{- end }}
        {{- $additionalCtxIdentifier := default "timescaledb" .additionalCtxIdentifier }}
        {{- $localTimescaleDBESOSecretIdentifier := include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $  "additionalCtxIdentifier" $additionalCtxIdentifier) }}
        {{- $globalTimescaleESOSecretIdentifier := include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $  "ctxIdentifier" "timescaledb") }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "overrideEnvName" $userVariableName "defaultValue" "postgres" "defaultKubernetesSecretName" "" "defaultKubernetesSecretKey" "" "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "timescaledbPostgresPassword" "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_USERNAME" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalTimescaleDBCtx.secretName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.userKey "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalTimescaleDBCtx.secretName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
        {{- $sslEnabled := false }}
        {{- $sslEnabledVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "bool" "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled"))) }}
        {{- if eq $sslEnabledVar "true" }}
            {{- $sslEnabled = true }}
        {{- end }}
        {{- if $sslEnabled }}
            {{- $sslModeValue = default "require" .sslModeValue }}
- name: {{ print $sslModeVariableName }}
  value: {{ print $sslModeValue }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "TIMESCALEDB_SSL_ROOT_CERT" "overrideEnvName" $certVariableName "defaultKubernetesSecretName" $globalTimescaleDBCtx.certName "defaultKubernetesSecretKey" $globalTimescaleDBCtx.certKey  "extKubernetesSecretCtxs" (list $globalTimescaleDBCtx.secrets.kubernetesSecrets $localTimescaleDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalTimescaleESOSecretIdentifier "secretCtx" $globalTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localTimescaleDBESOSecretIdentifier "secretCtx" $localTimescaleDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- $certPathVariableName := default "TIMESCALEDB_SSL_CERT_PATH" .certPathVariableName }}
            {{- $certPathValue := default "" .certPathValue }}
            {{- if $certPathValue }}
- name: {{ print $certPathVariableName }}
  value: {{ print $certPathValue }}
            {{- end }}
            {{- if $enableSslVariableName }}
- name: {{ print $enableSslVariableName }}
  value: "true"
            {{- end }}
        {{- else if $handleSSLModeDisable }}
            {{- $sslModeValue = "disable" }}
- name: {{ print $sslModeVariableName }}
  value: {{ print $sslModeValue }}
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
            {{- $hosts = $.Values.timescaledb.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.timescaledb.hosts }}
        {{- end }}
        {{- printf "%s" (split ":" (index $.Values.global.database.timescaledb.hosts 0))._1 }}
    {{- end }}
{{- end }}

{{/*
Generates Timescale Connection string

USAGE:
{{ include "harnesscommon.dbconnectionv2.timescaleConnection" (dict "database" "foo" "args" "bar" "context" $ "addSSLModeArg" false) }}
*/}}
{{- define "harnesscommon.dbconnectionv2.timescaleConnection" }}
    {{- $database := default .database .context.Values.timescaledb.database }}
    {{- $addSSLModeArg := default false .addSSLModeArg }}
    {{- $sslEnabled := false }}
    {{- $sslEnabledVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" .context "valueType" "bool" "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled"))) }}
    {{- if eq $sslEnabledVar "true" }}
        {{- $sslEnabled = true }}
    {{- end }}
    {{- $host := include "harnesscommon.dbconnectionv2.timescaleHost" (dict "context" .context ) }}
    {{- $port := include "harnesscommon.dbconnectionv2.timescalePort" (dict "context" .context ) }}
    {{- $connectionString := "" }}
    {{- $protocol := "" }}
    {{- if not (empty .protocol) }}
        {{- $protocol = (printf "%s://" .protocol) }}
    {{- else }}
        {{- $protocolVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" .context "valueType" "string" "keys" (list ".Values.global.database.timescaledb.protocol" ".Values.timescaledb.protocol"))) }}
        {{- if not (empty $protocolVar) }}
            {{- $protocol = (printf "%s://" $protocolVar) }}
        {{- end }}
    {{- end }}
    {{- $userAndPassField := "" }}
    {{- if and (.userVariableName) (.passwordVariableName) }}
        {{- $userAndPassField = (printf "$(%s):$(%s)@" .userVariableName .passwordVariableName) }}
    {{- end }}
    {{- $connectionString = (printf "%s%s%s:%s/%s" $protocol $userAndPassField  $host $port $database) }}
    {{- if .args }}
        {{- if $addSSLModeArg }}
            {{- if $sslEnabled }}
                {{- $connectionString = (printf "%s?%s&%s" $connectionString .args "sslmode=require") }}
            {{- else }}
                {{- $connectionString = (printf "%s?%s&%s" $connectionString .args "sslmode=disable") }}
            {{- end }}
        {{- else }}
            {{- $connectionString = (printf "%s?%s" $connectionString .args) }}
        {{- end }}
    {{- else }}
        {{- if $addSSLModeArg }}
            {{- if $sslEnabled }}
                {{- $connectionString = (printf "%s?%s" $connectionString "sslmode=require") }}
            {{- else }}
                {{- $connectionString = (printf "%s?%s" $connectionString "sslmode=disable") }}
            {{- end }}
        {{- end }}
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
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_USERNAME" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalRedisCtx.secretName "defaultKubernetesSecretKey" $globalRedisCtx.userKey "extKubernetesSecretCtxs" (list $globalRedisCtx.secrets.kubernetesSecrets $localRedisCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalRedisESOSecretIdentifier "secretCtx" $globalRedisCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localRedisESOSecretIdentifier "secretCtx" $localRedisCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalRedisCtx.secretName "defaultKubernetesSecretKey" $globalRedisCtx.passwordKey "extKubernetesSecretCtxs" (list $globalRedisCtx.secrets.kubernetesSecrets $localRedisCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalRedisESOSecretIdentifier "secretCtx" $globalRedisCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localRedisESOSecretIdentifier "secretCtx" $localRedisCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}

{{/*
Generates Redis Connection string.
If userVariableName or passwordVariableName are not provided, a connection string is generated without creds

USAGE:
{{ include "harnesscommon.dbconnection.redisConnection" (dict "context" $ "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" "unsetProtocol" false)}}
*/}}
{{- define "harnesscommon.dbconnectionv2.redisConnection" }}
    {{- $ := .context }}
    {{- $type := "redis" }}
    {{- $localDBCtx := $.Values.redis }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- $hosts := list }}
    {{- $protocol := "" }}
    {{- $extraArgs := "" }}
    {{- $unsetProtocol := default false .unsetProtocol }}
    {{- if $globalDBCtx.installed }}
        {{- if not $unsetProtocol }}
            {{- $protocol = $globalDBCtx.protocol }}
        {{- end }}
        {{- $hosts = list "redis-sentinel-harness-announce-0:26379" "redis-sentinel-harness-announce-1:26379" "redis-sentinel-harness-announce-2:26379" }}
        {{- $extraArgs = $globalDBCtx.extraArgs }}
    {{- else }}
        {{- if not $unsetProtocol }}
            {{- $protocol = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.redis.protocol" ".Values.redis.protocol"))) }}
        {{- end }}
        {{- if gt (len $localDBCtx.hosts) 0 }}
            {{- $hosts = $localDBCtx.hosts }}
        {{- else }}
            {{- $hosts = $globalDBCtx.hosts }}
        {{- end }}
        {{- $extraArgs = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.redis.extraArgs" ".Values.redis.extraArgs"))) }}
    {{- end }}
    {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
{{- end }}

{{/*
    Redis Host

USAGE:
{{ include "harnesscommon.dbconnection.redisHost" (dict "context" $ "userVariableName" "REDIS_USER" "passwordVariableName" "REDIS_PASSWORD" "unsetProtocol" false)}}
*/}}
{{- define "harnesscommon.dbconnectionv2.redisHost" }}
    {{- $ := .context }}
    {{- $type := "redis" }}
    {{- $localDBCtx := $.Values.redis }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- $hosts := list }}
    {{- $protocol := "" }}
    {{- $extraArgs := "" }}
    {{- $unsetProtocol := default false .unsetProtocol }}
    {{- if $globalDBCtx.installed }}
        {{- if not $unsetProtocol }}
            {{- $protocol = $globalDBCtx.protocol }}
        {{- end }}
        {{- $hosts = list "redis-sentinel-harness-announce-0" "redis-sentinel-harness-announce-1" "redis-sentinel-harness-announce-2" }}
        {{- $extraArgs = $globalDBCtx.extraArgs }}
    {{- else }}
        {{- if not $unsetProtocol }}
            {{- $protocol = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.redis.protocol" ".Values.redis.protocol"))) }}
        {{- end }}
        {{- if gt (len $localDBCtx.hosts) 0 }}
            {{- $hosts = $localDBCtx.hosts }}
        {{- else }}
            {{- $hosts = $globalDBCtx.hosts }}
        {{- end }}
        {{- $updatedHosts := list }}
        {{- range $hostIdx, $host := $hosts}}
            {{- $hostParts := split ":" $host }}
            {{- $updatedHosts = append $updatedHosts $hostParts._0 }}
        {{- end }}
        {{- $host = $updatedHosts }}
        {{- $extraArgs = (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.mongo.extraArgs" ".Values.mongo.extraArgs"))) }}
    {{- end }}
    {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
{{- end }}

{{/*
Outputs whether redis password is set or not

USAGE:
{{ include "harnesscommon.dbconnectionv2.isRedisPasswordSet" (dict "context" $ "passwordVariableName" "REDIS_PASSWORD" "localRedisCtx" .Values.redis "globalRedisCtx" .Values.global.database.redis) | indent 12 }}
*/}}
{{- define "harnesscommon.dbconnectionv2.isRedisPasswordSet" }}
  {{- $ := .context }}
  {{- $isRedisPasswordSet := "false" -}}
  {{- $passwordVariableName := .passwordVariableName }}
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
          {{- $secretRefContent := include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalRedisCtx.secretName "defaultKubernetesSecretKey" $globalRedisCtx.passwordKey "extKubernetesSecretCtxs" (list $globalRedisCtx.secrets.kubernetesSecrets $localRedisCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalRedisESOSecretIdentifier "secretCtx" $globalRedisCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localRedisESOSecretIdentifier "secretCtx" $localRedisCtx.secrets.secretManagement.externalSecretsOperator))) }}
          {{- if $secretRefContent }}
            {{- $isRedisPasswordSet = "true" }}
          {{- end }}
      {{- end }}
  {{- end }}
  {{- print $isRedisPasswordSet }}
{{- end }}

{{/*
Generates MongoDB environment variables
USAGE:
{{ include "harnesscommon.dbconnectionv2.mongoEnv" (dict "ctx" $ "localDBCtx" "userVariableName" "" "passwordVariableName" "" .Values.mongo "globalDBCtx" .Values.global.database.mongo) | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. localDBCtx
   Default: $.Values.mongo
2. globalDBCtx
   Default: $.Values.global.database.mongo
3. userVariableName
   Default: MONGO_USER
4. passwordVariableName
   Default: MONGO_PASSWORD

*/}}
{{- define "harnesscommon.dbconnectionv2.mongoEnv" }}
    {{- $ := .ctx }}
    {{- $type := "mongo" }}
    {{- $dbType := $type | upper}}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
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
        {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
        {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
        {{- $localMongoESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" "mongo" )) }}
        {{- $globalMongoESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "mongo" )) }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
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
    {{- $protocol := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.mongo.protocol" ".Values.mongo.protocol"))) }}
    {{- $extraArgs := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.mongo.extraArgs" ".Values.mongo.extraArgs"))) }}
    {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
    {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
    {{- if $installed }}
        {{- $namespace := $.Release.Namespace }}
        {{- if $.Values.global.ha }}
        {{- printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $userVariableName $passwordVariableName $namespace $namespace $namespace .database }}
        {{- else }}
            {{- printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $userVariableName $passwordVariableName $namespace .database }}
        {{- end }}
    {{- else }}
        {{- $args := (printf "/%s?%s" .database $extraArgs )}}
        {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
    {{- end }}
{{- end }}


{{/*
Generates Postgres environment variables
USAGE:
{{ include "harnesscommon.dbconnectionv2.postgresEnv" (dict "ctx" $ "localDBCtx" "userVariableName" "" "passwordVariableName" "" .Values.postgres "globalDBCtx" .Values.global.database.postgres) | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. localDBCtx
   Default: $.Values.mongo
2. globalDBCtx
   Default: $.Values.global.database.mongo
3. userVariableName
   Default: POSTGRES_USER
4. passwordVariableName
   Default: POSTGRES_PASSWORD
5. Use additionalCtxIdentifier to use any other block instead of .Values.postgres
*/}}
{{- define "harnesscommon.dbconnectionv2.postgresEnv" }}
    {{- $ := .ctx }}
    {{- $type := "postgres" }}
    {{- $dbType := $type | upper}}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
    {{- $localDBCtx := $.Values.postgres }}
    {{- if .localDBCtx }}
        {{- $localDBCtx = .localDBCtx }}
    {{- end }}
    {{- $globalDBCtx := $.Values.global.database.postgres }}
    {{- if .globalDBCtx }}
        {{- $globalDBCtx = .globalDBCtx }}
    {{- end }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalDBCtx.installed true }}
            {{- $installed = $globalDBCtx.installed }}
        {{- end }}
        {{- if eq $localDBCtx.enabled true }}
            {{- $installed = false }}
        {{- end }}
        {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
        {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
        {{- $additionalCtxIdentifier := default "postgres" .additionalCtxIdentifier }}
        {{- $localMongoESOSecretCtxIdentifier := include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $  "additionalCtxIdentifier" $additionalCtxIdentifier) }}
        {{- $globalMongoESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "postgres" )) }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_USER" "overrideEnvName" $userVariableName "defaultValue" "postgres" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" "postgres" "defaultKubernetesSecretKey" "postgres-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_USER" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}



{{/* Generates Postgres Connection string
USAGE:
{{ include "harnesscommon.dbconnectionv2.postgresConnection" (dict "ctx" $ "database" "foo" "args" "bar" "keywordValueConnectionString" true "setPasswordEmpty" true "setUsernameEmpty" true) }}
*/}}
{{- define "harnesscommon.dbconnectionv2.postgresConnection" }}
    {{- $ := .ctx }}
    {{- $type := "postgres" }}
    {{- $dbType := upper $type }}
    {{- $installed := true }}
    {{- $globalDBCtx := $.Values.global.database.postgres }}
    {{- $mergedDBCtx := $globalDBCtx }}
    {{- $localDBCtx := $.Values.postgres }}
    {{- if .localDBCtx }}
        {{- $localDBCtx = .localDBCtx }}
    {{- end }}
    {{- $args := default "" .args }}
    {{- if eq $.Values.global.database.postgres.installed false }}
        {{- $installed = false }}
    {{- end }}
    {{- if eq $localDBCtx.enabled true }}
        {{- $mergedDBCtx = $localDBCtx }}
        {{- $installed = false }}
    {{- end }}
    {{- $hosts := list }}
    {{- if gt (len $localDBCtx.hosts) 0 }}
        {{- $hosts = $localDBCtx.hosts }}
    {{- else }}
        {{- $hosts = $.Values.global.database.postgres.hosts }}
    {{- end }}
    {{- $keywordValueConnectionString := .keywordValueConnectionString }}
    {{- $protocol := default "postgres" .protocol }}
    {{- $extraArgs := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.postgres.extraArgs" ))) }}
    {{- $extraArgs = default $extraArgs $localDBCtx.extraArgs }}
    {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
    {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}

    {{- if .setUsernameEmpty }}
        {{- $userVariableName = "" }}
    {{- end }}
    {{- if .setPasswordEmpty }}
        {{- $passwordVariableName = "" }}
    {{- end }}
    {{- $sslMode := default "disable" $mergedDBCtx.sslMode }}
    {{- $database := default .database $localDBCtx.database }}
    {{- if $installed }}
        {{- if $keywordValueConnectionString }}
            {{- $connectionString := (printf " host=%s user=%s password=%s dbname=%s sslmode=%s%s" $protocol $userVariableName $passwordVariableName $database $sslMode $extraArgs) }}
            {{- printf "%s" $connectionString }}
        {{- else if or (empty $userVariableName) (empty $passwordVariableName) }}
            {{- $connectionString := (printf "%s://%s/%s?%s" $protocol "postgres:5432" $database $extraArgs) }}
            {{- printf "%s" $connectionString }}
        {{- else }}
            {{- $connectionString := (printf "%s://$(%s):$(%s)@%s/%s?%s" $protocol $userVariableName $passwordVariableName "postgres:5432" $database $extraArgs) }}
            {{- printf "%s" $connectionString }}
        {{- end }}
    {{- else }}
        {{- $paramArgs := default "" $args }}
        {{- $finalArgs := (printf "/%s" $database) }}
        {{- if and $paramArgs $extraArgs }}
            {{- $finalArgs = (printf "%s?%s&%s" $finalArgs $paramArgs $extraArgs) }}
        {{- else if or $paramArgs $extraArgs }}
            {{- $finalArgs = (printf "%s?%s" $finalArgs (default $paramArgs $extraArgs)) }}
        {{- end }}
        {{- $firsthostport := (index $hosts 0) -}}
        {{- $hostport := split ":" $firsthostport -}}
        {{- if $keywordValueConnectionString }}
            {{- $connectionString := (printf " host=%s user=%s password=%s dbname=%s sslmode=%s%s" $hostport._0 $userVariableName $passwordVariableName $database $sslMode $extraArgs) }}
            {{- printf "%s" $connectionString }}
        {{- else }}
            {{- include "harnesscommon.dbconnection.connection" (dict "type" $type "hosts" $hosts "protocol" $protocol "extraArgs" $finalArgs "userVariableName" $userVariableName "passwordVariableName" $passwordVariableName)}}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
 Postgres Host Port

*/}}
{{- define "harnesscommon.dbconnectionv2.PostgresHostPort" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "postgres" }}
    {{- $installed := and ( (pluck $type $.Values.global.database | first).installed ) (not (pluck $type $.Values | first).enabled ) }}
    {{- if $installed }}
        {{- print "postgres:5432" }}
    {{- else }}
        {{- $hosts := list }}
        {{- if gt (len $.Values.postgres.hosts) 0 }}
            {{- $hosts = $.Values.postgres.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.postgres.hosts }}
        {{- end }}
    {{- printf "%s" (index $hosts 0) }}
    {{- end }}
{{- end }}

{{- define "harnesscommon.dbconnectionv2.postgresHost" }}
  {{- $ := .context }}
  {{- $connectionString := "" }}
  {{- $type := "postgres" }}
  {{- $installed := and ( (pluck $type $.Values.global.database | first).installed ) (not (pluck $type $.Values | first).enabled ) }}
  {{- if $installed }}
      {{- print "postgres" }}
  {{- else }}
      {{- $hosts := list }}
      {{- if gt (len $.Values.postgres.hosts) 0 }}
          {{- $hosts = $.Values.postgres.hosts }}
      {{- else }}
          {{- $hosts = $.Values.global.database.postgres.hosts }}
      {{- end }}
  {{- printf "%s" (split ":" (index $hosts 0))._0 }}
  {{- end }}
{{- end }}

{{- define "harnesscommon.dbconnectionv2.postgresPort" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "postgres" }}
    {{- $installed := and ( (pluck $type $.Values.global.database | first).installed ) (not (pluck $type $.Values | first).enabled ) }}
    {{- if $installed }}
        {{- printf "%s" "5432" }}
    {{- else }}
    {{- $hosts := list }}
    {{- if gt (len $.Values.postgres.hosts) 0 }}
        {{- $hosts = $.Values.postgres.hosts }}
    {{- else }}
        {{- $hosts = $.Values.global.database.postgres.hosts }}
    {{- end }}
  {{- printf "%s" (split ":" (index $hosts 0))._1 }}
  {{- end }}
{{- end }}


{{/*
Generates Postgres environment variables
USAGE:
{{- include "harnesscommon.dbconnectionv2.elasticEnv" (dict "ctx" $ "userVariableName" "ELASTIC_USERNAME" "passwordVariableName" "ELASTIC_PASSWORD" "apiKeyVariableName" "ELASTIC_API_KEY") | indent 12 }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. localElasticCtx
   Default: $.Values.elastic
2. globalElasticCtx
   Default: $.Values.global.database.mongo
3. userVariableName
   Default: ELASTIC_USERNAME
4. passwordVariableName
   Default: ELASTIC_PASSWORD
5. apiKeyVariableName
   Default: ELASTIC_API_KEY

*/}}
{{- define "harnesscommon.dbconnectionv2.elasticEnv" }}
    {{- $ := .ctx }}
    {{- $type := "elastic" }}
    {{- $dbType := $type | upper}}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
    {{- $apiKeyVariableName:= .apiKeyVariableName }}
    {{- $localElasticCtx := $.Values.elastic }}
    {{- if .localElasticCtx }}
        {{- $localElasticCtx = .localElasticCtx }}
    {{- end }}
    {{- $globalElasticCtx := $.Values.global.database.elastic }}
    {{- if .globalElasticCtx }}
        {{- $globalElasticCtx = .globalElasticCtx }}
    {{- end }}
    {{- if and $ $localElasticCtx $globalElasticCtx }}
        {{- $installed := false }}
        {{- if eq $globalElasticCtx.installed true }}
            {{- $installed = $globalElasticCtx.installed }}
        {{- end }}
        {{- if eq $localElasticCtx.enabled true }}
            {{- $installed = false }}
        {{- end }}
        {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
        {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
        {{- $apiKeyVariableName := default (printf "%s_API_KEY" $dbType) .apiKeyVariableName }}
        {{- $localElasticESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" "elastic" )) }}
        {{- $globalElasticESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "elastic" )) }}
        {{- if not $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "ELASTIC_USER" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalElasticCtx.secretName "defaultKubernetesSecretKey" $globalElasticCtx.userKey "extKubernetesSecretCtxs" (list $globalElasticCtx.secrets.kubernetesSecrets $localElasticCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalElasticESOSecretIdentifier "secretCtx" $globalElasticCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localElasticESOSecretCtxIdentifier "secretCtx" $localElasticCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "ELASTIC_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalElasticCtx.secretName "defaultKubernetesSecretKey" $globalElasticCtx.passwordKey "extKubernetesSecretCtxs" (list $globalElasticCtx.secrets.kubernetesSecrets $localElasticCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalElasticESOSecretIdentifier "secretCtx" $globalElasticCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localElasticESOSecretCtxIdentifier "secretCtx" $localElasticCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "ELASTIC_API_KEY" "overrideEnvName" $apiKeyVariableName "defaultKubernetesSecretName" $globalElasticCtx.secretName "defaultKubernetesSecretKey" $globalElasticCtx.apiKey "extKubernetesSecretCtxs" (list $globalElasticCtx.secrets.kubernetesSecrets $localElasticCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalElasticESOSecretIdentifier "secretCtx" $globalElasticCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localElasticESOSecretCtxIdentifier "secretCtx" $localElasticCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}


{{/*
Define environment variable value based on ENABLE_ELASTIC
*/}}
{{- define "harnesscommon.dbconnectionv2.elasticConnection" -}}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "elastic" }}
    {{- $installed := (pluck $type $.Values.global.database | first).installed }}
    {{- if not $installed }}
        {{- $hosts := list }}
        {{- if gt (len $.Values.elastic.hosts) 0 }}
            {{- $hosts = $.Values.elastic.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.elastic.hosts }}
        {{- end }}
    {{- printf "%s" (index $hosts 0) }}
    {{- end }}
{{- end -}}



{{- define "harnesscommon.dbconnectionv3.postgresEnv" }}
    {{- $ := .ctx }}
    {{- $type := "postgres" }}
    {{- $dbType := $type | upper}}
    {{- $userVariableName := .userVariableName }}
    {{- $passwordVariableName := .passwordVariableName }}
    {{- $localDBCtx := $.Values.postgres }}
    {{- if .localDBCtx }}
        {{- $localDBCtx = .localDBCtx }}
    {{- end }}
    {{- $globalDBCtx := $.Values.global.database.postgres }}
    {{- if .globalDBCtx }}
        {{- $globalDBCtx = .globalDBCtx }}
    {{- end }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $installed := false }}
        {{- if eq $globalDBCtx.installed true }}
            {{- $installed = $globalDBCtx.installed }}
        {{- end }}
        {{- if eq $localDBCtx.enabled true }}
            {{- $installed = false }}
        {{- end }}
        {{- $userVariableName := default (printf "%s_USER" $dbType) .userVariableName }}
        {{- $passwordVariableName := default (printf "%s_PASSWORD" $dbType) .passwordVariableName }}
        {{- $localMongoESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" (default "postgres" .additionalCtxIdentifier) )) }}
        {{- $globalMongoESOSecretIdentifier := (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" "postgres" )) }}
        {{- if $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_USER" "overrideEnvName" $userVariableName "defaultValue" "postgres" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" "postgres" "defaultKubernetesSecretKey" "postgres-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_USER" "overrideEnvName" $userVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "POSTGRES_PASSWORD" "overrideEnvName" $passwordVariableName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalMongoESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator) (dict "secretCtxIdentifier" $localMongoESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "invalid input") }}
    {{- end }}
{{- end }}


{{- define "harnesscommon.dbconnectionv3.postgresHost" }}
  {{- $ := .context }}
  {{- $connectionString := "" }}
  {{- $type := "postgres" }}
  {{- $localDBCtx := $.Values.postgres }}
  {{- if .localDBCtx }}
      {{- $localDBCtx = .localDBCtx }}
  {{- end }}
  {{- $installed := and ( (pluck $type $.Values.global.database | first).installed ) (not $localDBCtx.enabled) }}
  {{- if $installed }}
      {{- print "postgres" }}
  {{- else }}
      {{- $hosts := list }}
      {{- if gt (len $localDBCtx.hosts) 0 }}
          {{- $hosts = $localDBCtx.hosts }}
      {{- else }}
          {{- $hosts = $.Values.global.database.postgres.hosts }}
      {{- end }}
  {{- printf "%s" (split ":" (index $hosts 0))._0 }}
  {{- end }}
{{- end }}

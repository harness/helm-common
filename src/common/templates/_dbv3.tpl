{{/*
Generate InstanceName from database

USAGE:
{{- include "harnesscommon.dbv3.generateInstanceName" (dict "database" "") }}

PARAMETERS:
REQUIRED:
- database: database name

*/}}

{{- define "harnesscommon.dbv3.generateInstanceName" }}
    {{- $database := .database }}
    {{- $instanceName := $database | lower | replace "-" "" }}
    {{- print $instanceName }}
{{- end }}

{{/*
Generate DB Env prefix from instanceName

USAGE:
{{- include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "" "dbType" "" "instanceName" "") }}

PARAMETERS:
REQUIRED:
- instanceName: instance name
- dbType: DB Type

*/}}

{{- define "harnesscommon.dbv3.generateDBEnvName" }}
    {{- $name := .name }}
    {{- if empty $name }}
        {{- fail "ERROR: missing input argument - name" }}
    {{- end }}
    {{- $dbType := .dbType }}
    {{- if empty $dbType }}
        {{- fail "ERROR: missing input argument - dbType" }}
    {{- end }}
    {{- $instanceName := .instanceName }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: missing input argument - instanceName" }}
    {{- end }}
    {{- printf "%s_%s_%s" (upper $instanceName) (upper $dbType) (upper $name) }}
{{- end }}

{{/*
Generate DB ESO Context Identifier 

USAGE:
{{- include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" "mongo" "scope" "" "instanceName" "") }}

PARAMETERS:
- ctx: Context
- dbType: DB Type. Allowed values: mongo, timescaledb
- scope: Scope of ESO Secret Context Identifier. Allowed Values: "local", "global"
- instanceName: Name of the DB Instance. Required only when "scope" if "local"

*/}}
{{- define "harnesscommon.dbv3.esoSecretCtxIdentifier" }}
    {{- $ := .ctx }}
    {{- $dbTypeAllowedValues := dict "mongo" "" "timescaledb" "" "redis" "" }}
    {{- $dbType := .dbType }}
    {{- if not (hasKey $dbTypeAllowedValues $dbType) }}
        {{- $errMsg := printf "ERROR: invalid value %s for input argument dbType" $dbType }}
        {{- fail $errMsg }}
    {{- end }}
    {{- $scope := .scope -}}
    {{- $esoSecretCtxIdentifier := "" }}
    {{- if eq $scope "local" }}
        {{- $instanceName := .instanceName }}
        {{- if empty $instanceName }}
            {{- fail "ERROR: missing input argument - instanceName" }}
        {{- end }}
        {{- $instanceName =  lower $instanceName }}
        {{- $esoSecretCtxIdentifier = (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ "additionalCtxIdentifier" (printf "%s-%s" $instanceName $dbType) )) }}
    {{- else if eq $scope "global" }}
        {{- $esoSecretCtxIdentifier = (include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $ "ctxIdentifier" $dbType )) }}
    {{- else }}
        {{- $errMsg := printf "ERROR: invalid value %s for input argument scope" $scope }}
        {{- fail $errMsg }}
    {{- end }}
    {{- printf "%s" $esoSecretCtxIdentifier }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.mongoEnv" (dict "ctx" $ "database" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName

*/}}
{{- define "harnesscommon.dbv3.mongoEnv" }}
    {{- $ := .ctx }}
    {{- $dbType := "mongo" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USER" "dbType" $dbType "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" $dbType "instanceName" $instanceName)) .passwordVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalDBESOSecretIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "global") }}
        {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
        {{- if $userNameEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" "harness-secrets" "defaultKubernetesSecretKey" "mongodbUsername" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_USER"  "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
        {{- if $passwordEnvName }}
            {{- if $localEnabled }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else if $installed }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" "mongodb-replicaset-chart" "defaultKubernetesSecretKey" "mongodb-root-password" "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- else }}
                {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "MONGO_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- end }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for MongoDB Connection Environment Variables

USAGE:
{{ include "harnesscommon.dbv3.mongoConnectionEnv" (dict "ctx" $ "database" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName
3. connectionURIVariableName

*/}}
{{- define "harnesscommon.dbv3.mongoConnectionEnv" }}
    {{- $ := .ctx }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := include "harnesscommon.dbv3.generateInstanceName" (dict "database" $database) }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.mongo $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.mongo }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USER" "dbType" "mongo" "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" "mongo" "instanceName" $instanceName)) .passwordVariableName }}
        {{- $connectionURIEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "URI" "dbType" "mongo" "instanceName" $instanceName)) .connectionURIVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $connectionURI := "" }}
        {{- if $connectionURIEnvName }}
            {{- if $localEnabled }}
                {{- $hosts := $localDBCtx.hosts }}
                {{- $protocol := $localDBCtx.protocol }}
                {{- $extraArgs := $localDBCtx.extraArgs }}
                {{- $database = default $database $localDBCtx.database }}
                {{- $args := (printf "/%s?%s" $database $extraArgs ) -}}
                {{- $connectionURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userNameEnvName "passwordVariableName" $passwordEnvName)}}
            {{- else if $installed }}
                {{- $namespace := $.Release.Namespace }}
                {{- if $.Values.global.ha }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-1.mongodb-replicaset-chart.%s.svc,mongodb-replicaset-chart-2.mongodb-replicaset-chart.%s.svc:27017/%s?replicaSet=rs0&authSource=admin'" $userNameEnvName $passwordEnvName $namespace $namespace $namespace $database }}
                {{- else }}
                    {{- $connectionURI = printf "'mongodb://$(%s):$(%s)@mongodb-replicaset-chart-0.mongodb-replicaset-chart.%s.svc/%s?authSource=admin'" $userNameEnvName $passwordEnvName $namespace $database }}
                {{- end }}
            {{- else }}
                {{- $hosts := $globalDBCtx.hosts }}
                {{- $protocol := $globalDBCtx.protocol }}
                {{- $extraArgs := $globalDBCtx.extraArgs }}
                {{- $args := (printf "/%s?%s" $database $extraArgs ) -}}
                {{- $connectionURI = include "harnesscommon.dbconnection.connection" (dict "type" "mongo" "hosts" $hosts "protocol" $protocol "extraArgs" $args "userVariableName" $userNameEnvName "passwordVariableName" $passwordEnvName)}}
            {{- end }}
- name: {{ printf "%s" $connectionURIEnvName }}
  value: {{ printf "%s" $connectionURI }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}


{{/*
Generate External Secret CRDs for Mongo DBs

USAGE:
{{- include "harnesscommon.dbv3.generateLocalMongoExternalSecret" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.generateLocalMongoExternalSecret" }}
    {{- $ := .ctx }}
    {{- $dbType := "mongo" }}
    {{- range $instanceName, $instance := $.Values.database.mongo }}
        {{- $localDBCtx := get $.Values.database.mongo $instanceName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- if and $localEnabled (eq (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" $localDBCtx.secrets)) "true") }}
            {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
            {{- include "harnesscommon.secrets.generateExternalSecret" (dict "secretsCtx" $localDBCtx.secrets "secretNamePrefix" $localDBESOSecretCtxIdentifier) }}
            {{- print "\n---" }}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
Generate K8S Env Spec for Redis Environment Variables

USAGE:
{{- include "harnesscommon.dbv3.redisEnv" (dict "ctx" $ "database" "eventsFramework") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName

*/}}
{{- define "harnesscommon.dbv3.redisEnv" }}
    {{- $ := .ctx }}
    {{- $dbType := "redis" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := $database }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.redis $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $userNameEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "USER" "dbType" $dbType "instanceName" $instanceName)) .userVariableName }}
        {{- $passwordEnvName := default (include "harnesscommon.dbv3.generateDBEnvName" (dict "name" "PASSWORD" "dbType" $dbType "instanceName" $instanceName)) .passwordVariableName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalDBESOSecretIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "global") }}
        {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
        {{- if $localEnabled }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_USERNAME" "overrideEnvName" $userNameEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "overrideEnvName" $passwordEnvName "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else if not $installed }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_USERNAME" "overrideEnvName" $userNameEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.userKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
            {{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "overrideEnvName" $passwordEnvName "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate Redis Connection string

USAGE:
{{ include "harnesscommon.dbv3.redisConnection" (dict "ctx" $ "database" "harness") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
- unsetProtocol
- excludePort
- userVariableName
- passwordVariableName

*/}}
{{- define "harnesscommon.dbv3.redisConnection" }}
    {{- $ := .ctx }}
    {{- $dbType := "redis" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := $database }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.redis $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $hosts := list }}
        {{- $protocol := "" }}
        {{- $extraArgs := "" }}
        {{- $unsetProtocol := default false .unsetProtocol }}
        {{- $excludePort := default false .excludePort }}
        {{- if $localEnabled }}
            {{- if not $unsetProtocol }}
                {{- $protocol = $localDBCtx.protocol }}
            {{- end }}
            {{- $hosts = $localDBCtx.hosts }}
            {{- $extraArgs = $localDBCtx.extraArgs }}
        {{- else if not $installed }}
            {{- if not $unsetProtocol }}
                {{- $protocol = $globalDBCtx.protocol }}
            {{- end }}
            {{- $hosts = $globalDBCtx.hosts }}
            {{- $extraArgs = $globalDBCtx.extraArgs }}
        {{- else }}
            {{- if not $unsetProtocol }}
                {{- $protocol = $globalDBCtx.protocol }}
            {{- end }}
            {{- $hosts = list "redis-sentinel-harness-announce-0:26379" "redis-sentinel-harness-announce-1:26379" "redis-sentinel-harness-announce-2:26379" }}
            {{- $extraArgs = $globalDBCtx.extraArgs }}
        {{- end }}
        {{- if $excludePort }}
            {{- $updatedHosts := list }}
            {{- range $hostIdx, $host := $hosts}}
                {{- $hostParts := split ":" $host }}
                {{- $updatedHosts = append $updatedHosts $hostParts._0 }}
            {{- end }}
            {{- $host = $updatedHosts }}
        {{- end }}
        {{- include "harnesscommon.dbconnection.connection" (dict "type" $dbType "hosts" $hosts "protocol" $protocol "extraArgs" $extraArgs "userVariableName" .userVariableName "passwordVariableName" .passwordVariableName "connectionType" "list") }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Outputs whether redis password is set or not

USAGE:
{{- include "harnesscommon.dbv3.isRedisPasswordSet" (dict "ctx" $ "database" "eventsFramework") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:

*/}}
{{- define "harnesscommon.dbv3.isRedisPasswordSet" }}
    {{- $ := .ctx }}
    {{- $dbType := "redis" }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := $database }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.redis $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $isRedisPasswordSet := "false" }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- $globalDBESOSecretIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "global") }}
        {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
        {{- $secretRefContent := "" }}
        {{- if $localEnabled }}
            {{- $secretRefContent = include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "extKubernetesSecretCtxs" (list $localDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localDBESOSecretCtxIdentifier "secretCtx" $localDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- else if not $installed }}
            {{- $secretRefContent = include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" "REDIS_PASSWORD" "defaultKubernetesSecretName" $globalDBCtx.secretName "defaultKubernetesSecretKey" $globalDBCtx.passwordKey "extKubernetesSecretCtxs" (list $globalDBCtx.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $globalDBESOSecretIdentifier "secretCtx" $globalDBCtx.secrets.secretManagement.externalSecretsOperator))) }}
        {{- end }}
        {{- if $secretRefContent }}
            {{- $isRedisPasswordSet = "true" }}
        {{- end }}
        {{- print $isRedisPasswordSet | quote }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Outputs if redis sentinels are being used

USAGE:
{{- include "harnesscommon.dbv3.redisEnv" (dict "ctx" $ "database" "eventsFramework") | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx
2. database

OPTIONAL:
1. userVariableName
2. passwordVariableName

*/}}
{{- define "harnesscommon.dbv3.useRedisSentinels" }}
    {{- $ := .ctx }}
    {{- $database := .database }}
    {{- if empty $database }}
        {{- fail "ERROR: missing input argument - database" }}
    {{- end }}
    {{- $instanceName := $database }}
    {{- if empty $instanceName }}
        {{- fail "ERROR: invalid instanceName value" }}
    {{- end }}
    {{- $localDBCtx := get $.Values.database.redis $instanceName }}
    {{- $globalDBCtx := $.Values.global.database.redis }}
    {{- if and $ $localDBCtx $globalDBCtx }}
        {{- $useSentinels := "false" }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- $installed := dig "installed" true $globalDBCtx }}
        {{- if $localEnabled }}
            {{- $useSentinels = "false" }}
        {{- else if not $installed }}
            {{- $useSentinels = "false" }}
        {{- else }}
            {{- $useSentinels = "true" }}
        {{- end }}
        {{- printf $useSentinels | quote }}
    {{- else }}
        {{- fail (printf "ERROR: invalid contexts") }}
    {{- end }}
{{- end }}

{{/*
Generate External Secret CRDs for Redis DBs

USAGE:
{{- include "harnesscommon.dbv3.generateLocalRedisExternalSecret" (dict "ctx" $) | indent 12 }}

PARAMETERS:
REQUIRED:
1. ctx

*/}}
{{- define "harnesscommon.dbv3.generateLocalRedisExternalSecret" }}
    {{- $ := .ctx }}
    {{- $dbType := "redis" }}
    {{- range $instanceName, $instance := $.Values.database.redis }}
        {{- $localDBCtx := get $.Values.database.redis $instanceName }}
        {{- $localEnabled := dig "enabled" false $localDBCtx }}
        {{- if and $localEnabled (eq (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" $localDBCtx.secrets)) "true") }}
            {{- $localDBESOSecretCtxIdentifier := include "harnesscommon.dbv3.esoSecretCtxIdentifier" (dict "ctx" $ "dbType" $dbType "scope" "local" "instanceName" $instanceName) }}
            {{- include "harnesscommon.secrets.generateExternalSecret" (dict "secretsCtx" $localDBCtx.secrets "secretNamePrefix" $localDBESOSecretCtxIdentifier) }}
            {{- print "\n---" }}
        {{- end }}
    {{- end }}
{{- end }}

{{/*
Outputs the filepath prefix based on db type and db name

USAGE:
{{ include "harnesscommon.dbv3.filepathprefix" (dict "context" $ "dbType" "redis" "dbName" "") }}
*/}}
{{- define "harnesscommon.dbv3.filepathprefix" }}
  {{- $dbType := lower .dbType }}
  {{- $database := (default "default" .dbName) }}
  {{- if eq $database "" }}
    {{- printf "%s" $dbType }}
  {{- else }}
    {{- printf "%s-%s" $dbType $database }}
  {{- end }}
{{- end }}

{{/*
Outputs env variables for SSL

USAGE:
{{ include "harnesscommon.dbv3.sslEnv" (dict "context" $ "dbType" "redis" "dbName" "" "variableNames" ( dict "sslEnabled" "REDIS_SSL_ENABLED" "sslCATrustStorePath" "REDIS_SSL_CA_TRUST_STORE_PATH" "sslCATrustStorePassword" "REDIS_SSL_CA_TRUST_STORE_PASSWORD" "sslCACertPath" "REDIS_SSL_CA_CERT_PATH")) | indent 12 }}
*/}}
{{- define "harnesscommon.dbv3.sslEnv" }}
  {{- $ := .context }}
  {{- $dbType := lower .dbType }}
  {{- $database := (default "default" .dbName) }}
  {{- $globalCtx := (index $.Values.global.database $dbType) }}
  {{- $localCtx := default $globalCtx (index $.Values $dbType) }}
  {{- $localDbCtx := default $localCtx (index $localCtx $database) }}
  {{- $globalDbCtx := default $globalCtx (index $globalCtx $database) }}
  {{- $globalDbCtxCopy := deepCopy $globalDbCtx }}
  {{- $mergedCtx := deepCopy $localDbCtx | mergeOverwrite $globalDbCtxCopy }}
  {{- $installed := $mergedCtx.installed }}
  {{- if not $installed }}
    {{- $sslEnabled := $mergedCtx.ssl.enabled }}
    {{- if $sslEnabled }}
    {{- $filepathprefix := (include "harnesscommon.dbv3.filepathprefix" (dict "dbType" $dbType "dbName" $database)) }}
    {{- if .variableNames.sslEnabled }}
- name: {{ .variableNames.sslEnabled }}
  value: {{ printf "%v" $mergedCtx.ssl.enabled | quote }}
    {{- end }}
    {{- if and .variableNames.sslCATrustStorePath $mergedCtx.ssl.trustStoreKey }}
- name: {{ .variableNames.sslCATrustStorePath }}
  value: {{ printf "/opt/harness/svc/ssl/%s/%s/%s-ca-truststore" $dbType $database $filepathprefix | quote }}
    {{- end }}
    {{- if and .variableNames.sslCACertPath $mergedCtx.ssl.caFileKey }}
- name: {{ .variableNames.sslCACertPath }}
  value: {{ printf "/opt/harness/svc/ssl/%s/%s/%s-ca" $dbType $database $filepathprefix | quote }}
    {{- end }}
    {{- if and .variableNames.sslCATrustStorePassword $mergedCtx.ssl.trustStorePasswordKey }}
- name: {{ .variableNames.sslCATrustStorePassword }}
  valueFrom:
    secretKeyRef:
      name: {{ $mergedCtx.ssl.secret }}
      key: {{ $mergedCtx.ssl.trustStorePasswordKey }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{/*
Outputs volumes which load trustStore and CA file from a secret

USAGE:
{{ include "harnesscommon.dbv3.sslVolume" (dict "context" $ "dbType" "redis" "dbName" "") | indent 12 }}
*/}}
{{- define "harnesscommon.dbv3.sslVolume" }}
  {{- $ := .context }}
  {{- $dbType := lower .dbType }}
  {{- $database := (default "default" .dbName) }}
  {{- $globalCtx := (index $.Values.global.database $dbType) }}
  {{- $localCtx := default $globalCtx (index $.Values $dbType) }}
  {{- $localDbCtx := default $localCtx (index $localCtx $database) }}
  {{- $globalDbCtx := default $globalCtx (index $globalCtx $database) }}
  {{- $globalDbCtxCopy := deepCopy $globalDbCtx }}
  {{- $mergedCtx := deepCopy $localDbCtx | mergeOverwrite $globalDbCtxCopy }}
  {{- $installed := $mergedCtx.installed }}
  {{- if not $installed }}
    {{- $sslEnabled := $mergedCtx.ssl.enabled }}
    {{- if and $sslEnabled (or $mergedCtx.ssl.trustStoreKey $mergedCtx.ssl.caFileKey) $mergedCtx.ssl.secret}}
    {{- $filepathprefix := (include "harnesscommon.dbv3.filepathprefix" (dict "dbType" $dbType "dbName" $database)) }}
- name: {{ printf "%s-ssl" $filepathprefix }}
  secret:
    secretName: {{ $mergedCtx.ssl.secret }}
    items:
    {{- if $mergedCtx.ssl.trustStoreKey }}
      - key: {{ $mergedCtx.ssl.trustStoreKey }}
        path: {{ printf "%s-ca-truststore" $filepathprefix }}
    {{- end }}
    {{- if $mergedCtx.ssl.caFileKey }}
      - key: {{ $mergedCtx.ssl.caFileKey }}
        path: {{ printf "%s-ca" $filepathprefix -}}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}


{{/*
Outputs volumeMounts which use above volumes

USAGE:
{{ include "harnesscommon.dbv3.sslVolumeMount" (dict "context" $ "dbType" "redis" "dbName" "") | indent 12 }}
*/}}
{{- define "harnesscommon.dbv3.sslVolumeMount" }}
  {{- $ := .context }}
  {{- $dbType := lower .dbType }}
  {{- $database := (default "default" .dbName) }}
  {{- $globalCtx := (index $.Values.global.database $dbType) }}
  {{- $localCtx := default $globalCtx (index $.Values $dbType) }}
  {{- $localDbCtx := default $localCtx (index $localCtx $database) }}
  {{- $globalDbCtx := default $globalCtx (index $globalCtx $database) }}
  {{- $globalDbCtxCopy := deepCopy $globalDbCtx }}
  {{- $mergedCtx := deepCopy $localDbCtx | mergeOverwrite $globalDbCtxCopy }}
  {{- $installed := $mergedCtx.installed }}
  {{- if not $installed }}
    {{- $sslEnabled := $mergedCtx.ssl.enabled }}
    {{- if and $sslEnabled (or $mergedCtx.ssl.trustStoreKey $mergedCtx.ssl.caFileKey) $mergedCtx.ssl.secret }}
    {{- $filepathprefix := (include "harnesscommon.dbv3.filepathprefix" (dict "dbType" $dbType "dbName" $database)) }}
- name: {{ printf "%s-ssl" $filepathprefix }}
  mountPath: {{ printf "/opt/harness/svc/ssl/%s/%s" $dbType $database | quote }}
  readOnly: true
    {{- end }}
  {{- end }}
{{- end }}



{{- define "harnesscommon.dbconnectionv3.timescaleHost" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "timescaledb" }}
    {{- $installed := (pluck $type $.Values.global.database | first).installed }}
    {{- $hosts := list ("timescaledb-single-chart:5432") }}
    {{- $localTimescaleDBCtx := $.Values.timescaledb }}
        {{- if .localTimescaleDBCtx }}
            {{- $localTimescaleDBCtx = .localTimescaleDBCtx }}
        {{- end }}
    {{- if $installed }}
        {{- if gt (len $localTimescaleDBCtx.hosts) 0 }}
            {{- $hosts = $localTimescaleDBCtx.hosts }}
        {{- end }}
    {{- else }}
        {{- if gt (len $localTimescaleDBCtx.hosts) 0 }}
            {{- $hosts = $localTimescaleDBCtx.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.timescaledb.hosts }}
        {{- end }}
    {{- end }}
    {{- printf "%s" (split ":" (index $hosts 0))._0 }}
{{- end }}

{{- define "harnesscommon.dbconnectionv3.timescalePort" }}
    {{- $ := .context }}
    {{- $connectionString := "" }}
    {{- $type := "timescaledb" }}
    {{- $installed := (pluck $type $.Values.global.database | first).installed }}
    {{- $hosts := list ("timescaledb-single-chart:5432") }}
    {{- $localTimescaleDBCtx := $.Values.timescaledb }}
        {{- if .localTimescaleDBCtx }}
            {{- $localTimescaleDBCtx = .localTimescaleDBCtx }}
        {{- end }}
    {{- if $installed }}
        {{- if gt (len $localTimescaleDBCtx.hosts) 0 }}
            {{- $hosts = $localTimescaleDBCtx.hosts }}
        {{- end }}
    {{- else }}
        {{- if gt (len $localTimescaleDBCtx.hosts) 0 }}
            {{- $hosts = $localTimescaleDBCtx.hosts }}
        {{- else }}
            {{- $hosts = $.Values.global.database.timescaledb.hosts }}
        {{- end }}
    {{- end }}
    {{- printf "%s" (split ":" (index $hosts 0))._1 }}
{{- end }}
{{- define "harnesscommon.dbconnectionv3.timescaleConnection" }}
    {{- $addSSLModeArg := default false .addSSLModeArg }}
    {{- $sslEnabled := false }}
    {{- $sslEnabledVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "bool" "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled"))) }}
    {{- if eq $sslEnabledVar "true" }}
        {{- $sslEnabled = true }}
    {{- end }}
    {{- $localTimescaleDBCtx := .context.Values.timescaledb }}
    {{- if .localTimescaleDBCtx }}
        {{- $localTimescaleDBCtx = .localTimescaleDBCtx }}
    {{- end }}
    {{- $host := include "harnesscommon.dbconnectionv3.timescaleHost" (dict "context" .context "localTimescaleDBCtx" $localTimescaleDBCtx ) }}
    {{- $port := include "harnesscommon.dbconnectionv3.timescalePort" (dict "context" .context "localTimescaleDBCtx" $localTimescaleDBCtx ) }}
    {{- $connectionString := "" }}
    {{- $protocol := "" }}
    {{- if not (empty .protocol) }}
        {{- $protocol = (printf "%s://" .protocol) }}
    {{- end }}
    {{- $protocolVar := (include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.timescaledb.protocol" ".Values.timescaledb.protocol"))) }}
    {{- if not (empty $protocolVar) }}
        {{- $protocol = (printf "%s://" $protocolVar) }}
    {{- end }}
    {{- $userAndPassField := "" }}
    {{- if and (.userVariableName) (.passwordVariableName) }}
        {{- $userAndPassField = (printf "$(%s):$(%s)@" .userVariableName .passwordVariableName) }}
    {{- end }}
    {{- $connectionString = (printf "%s%s%s:%s/%s" $protocol $userAndPassField  $host $port .database) }}
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

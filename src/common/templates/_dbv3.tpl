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
    {{- $dbTypeAllowedValues := dict "mongo" "" "timescaledb" "" }}
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

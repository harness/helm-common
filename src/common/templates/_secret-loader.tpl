{{/* 
Checks if secretsLoader is enabled
Usage: {{ include "harnesscommon.secretsLoader.enabled" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.enabled" -}}
{{- $ctx := .ctx | default . -}}
{{- $global := index $ctx.Values "global" | default dict -}}
{{- $globalSecrets := index $global "externalSecretsLoader" | default dict -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" | default dict -}}
{{- $globalEnabled := index $globalSecrets "enabled" | default false -}}
{{- $enabled := $globalEnabled -}}
{{- $localEnabled := index $localSecrets "enabled" | default nil -}}
{{- if ne $localEnabled nil -}}
  {{- $enabled = $localEnabled -}}
{{- end -}}
{{- $enabled -}}
{{- end -}}

{{/* 
Create initContainer for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.initContainer" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.initContainer" -}}
{{- $ctx := .ctx | default . -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
- name: secrets-loader
  image: {{ printf "%s:%s" $mergedSecrets.image.repository $mergedSecrets.image.tag }}
  imagePullPolicy: {{ $mergedSecrets.image.pullPolicy }}
  volumeMounts:
    - name: secrets-loader-config
      mountPath: /etc/secrets-loader
      readOnly: true
    - name: shared-secrets-env
      mountPath: /shared/env
    - name: shared-secrets-files
      mountPath: /shared/files
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
{{- end -}}
{{- end -}}

{{/* 
Create volumeMounts for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.volumeMounts" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.volumeMounts" -}}
{{- $ctx := .ctx | default . -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
- name: shared-secrets-env
  mountPath: /shared/env
- name: shared-secrets-files
  mountPath: {{ dig "secrets" "fileSecrets" "outputPath" "/shared/files" $mergedSecrets }}
  readOnly: true
{{- $fileSecrets := $ctx.Values.secrets.fileSecret | default (list) -}}
{{- if gt (len $fileSecrets) 0 }}
{{- range $ind, $indexvalue := $fileSecrets }}
- name: shared-secrets-files
  mountPath: {{ $indexvalue.volumeMountPath | quote }}
  readOnly: true
{{- end}}
{{- end}}
{{- end -}}
{{- end -}}

{{/* 
Create volumes for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.volumes" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.volumes" -}}
{{- $ctx := .ctx | default . -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
{{- $serviceName := default $ctx.Chart.Name $mergedSecrets.serviceName -}}
{{- $configMapName := printf "%s-config" $serviceName -}}
- name: secrets-loader-config
  configMap:
    name: {{ $configMapName }}
    items:
      - key: secrets-loader-config.yaml
        path: config.yaml
    defaultMode: 420
- name: shared-secrets-env
  emptyDir: {}
- name: shared-secrets-files
  emptyDir: {}
{{- end -}}
{{- end -}}

{{/* 
Create mergeScript for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.mergeScript" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.mergeScript" -}}
set -a && . /shared/env/.env && set +a && for var in $(env | grep '\\${' | cut -d= -f1); do eval "export $var='$(eval echo \\\"\\$$var\\\")'"; done && env && exec /opt/harness/run.sh
{{- end -}}

{{/* 
Create command for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.command" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.command" -}}
{{- $ctx := .ctx | default . -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
["/bin/sh"]
{{- end -}}
{{- end -}}

{{/* 
Create args for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.args" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.args" -}}
{{- $ctx := .ctx | default . -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
["-c", {{ include "harnesscommon.secretsLoader.mergeScript" $ctx | quote }}]
{{- end -}}
{{- end -}}

{{/* 
Create configContent for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.configContent" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.configContent" -}}
{{- $ctx := .ctx -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" $ctx)) "true" }}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
{{- $serviceName := default $ctx.Chart.Name $mergedSecrets.serviceName -}}
  secrets-loader-config.yaml: |
    provider: {{ dig "provider" "vault" $mergedSecrets | quote }}
    vault:
      address: {{ dig "vault" "address" "" $mergedSecrets | quote }}
      engine: {{ dig "vault" "engine" "" $mergedSecrets | quote }}
      basePath: {{ dig "vault" "basePath" "" $mergedSecrets | quote }}
      auth:
        method: {{ dig "vault" "auth" "method" "token" $mergedSecrets | quote }}
        {{- if eq (dig "vault" "auth" "method" "" $mergedSecrets) "token" }}
        token: {{ dig "vault" "auth" "token" "" $mergedSecrets | quote }}
        {{- end }}
        {{- if eq (dig "vault" "auth" "method" "" $mergedSecrets) "approle" }}
        roleId: {{ dig "vault" "auth" "roleId" "" $mergedSecrets | quote }}
        secretId: {{ dig "vault" "auth" "secretId" "" $mergedSecrets | quote }}
        {{- end }}
        {{- if eq (dig "vault" "auth" "method" "" $mergedSecrets) "kubernetes" }}
        role: {{ dig "vault" "auth" "role" "" $mergedSecrets | quote }}
        {{- end }}
    serviceName: {{ $serviceName | quote }}
    secrets:
      envSecrets:
        enabled: {{ dig "secrets" "envSecrets" "enabled" true $mergedSecrets | quote }}
        outputFile: {{ dig "secrets" "envSecrets" "outputFile" "/shared/env/.env" $mergedSecrets | quote }}
        categories: {{ dig "secrets" "envSecrets" "categories" (list "database" "api") $mergedSecrets | toYaml | nindent 10 }}
      fileSecrets:
        enabled: {{ dig "secrets" "fileSecrets" "enabled" true $mergedSecrets | quote }}
        outputPath: {{ dig "secrets" "fileSecrets" "outputPath" "/shared/files" $mergedSecrets | quote }}
        categories: {{ dig "secrets" "fileSecrets" "categories" (list "config") $mergedSecrets | toYaml | nindent 10 }}
    databases:
      {{- $databases := dig "databases" dict $mergedSecrets -}}
      {{- range $dbType, $dbConfig := $databases }}
      {{- if eq $dbConfig.useDatabaseSecretsEngine true }}
      - type: {{ $dbType | quote }}
        useDatabaseSecretsEngine: {{ $dbConfig.useDatabaseSecretsEngine | default false | quote }}
        engine: {{ $dbConfig.engine | quote }}
        overridePath: {{ $dbConfig.overridePath | quote }}
        databaseRole: {{ $dbConfig.databaseRole | quote }}
        {{- if $dbConfig.instances }}
        instances:
        {{- range $dbConfig.instances }}
          - name: {{ .name | quote }}
        {{- end }}
        {{- end }}
      {{- end }}
      {{- end }}      
{{- end -}}
{{- end -}}

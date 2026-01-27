{{/* 
Checks if secretsLoader is enabled
Usage: {{ include "harnesscommon.secretsLoader.enabled" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.enabled" -}}
{{- $enabled := false -}}
{{- if ne .ctx nil -}}
{{- $ctx := default . .ctx -}}
{{- if and $ctx $ctx.Values -}}
{{- $global := index $ctx.Values "global" | default dict -}}
{{- $globalSecrets := index $global "externalSecretsLoader" | default dict -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" | default dict -}}
{{- $globalEnabled := index $globalSecrets "enabled" | default false -}}
{{- $enabled = $globalEnabled -}}
{{- $localEnabled := index $localSecrets "enabled" | default nil -}}
{{- if ne $localEnabled nil -}}
  {{- $enabled = $localEnabled -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- $enabled -}}
{{- end -}}

{{/* 
Create initContainer for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.initContainer" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.initContainer" -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
{{- $ctx := default . .ctx -}}
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
    {{- if and $ctx.Values.securityContext $ctx.Values.securityContext.runAsUser }}
    runAsUser: {{ $ctx.Values.securityContext.runAsUser }}
    {{- else }}
    runAsUser: 65534
    {{- end }}
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
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
{{- $ctx := default . .ctx -}}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
- name: shared-secrets-env
  mountPath: {{ dig "secrets" "envSecrets" "outputPath" "/shared/env" $mergedSecrets | quote }}
- name: shared-secrets-files
  mountPath: {{ dig "secrets" "fileSecrets" "outputPath" "/shared/files" $mergedSecrets | quote }}
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
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
{{- $ctx := default . .ctx -}}
{{- $globalSecrets := index $ctx.Values.global "externalSecretsLoader" -}}
{{- $mergedSecrets := deepCopy $globalSecrets -}}
{{- $localSecrets := index $ctx.Values "externalSecretsLoader" -}}
{{- if $localSecrets }}
{{- $mergedSecrets = mergeOverwrite $mergedSecrets $localSecrets -}}
{{- end -}}
{{- $serviceName := default $ctx.Chart.Name $mergedSecrets.serviceName -}}
{{- $configMapName := default $serviceName $mergedSecrets.configName -}}
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
{{- $entry := default "/opt/harness/run.sh" .entry_point -}}
set -a && . /shared/env/.env && set +a && for var in $(env | grep '\${' | cut -d= -f1); do eval "export $var=\"$(eval echo \"\$$var\")\""; done && exec {{ $entry }}
{{- end -}}

{{/* 
Create command for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.command" (dict "ctx" .) }}
*/}}

{{- define "harnesscommon.secretsLoader.command" -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
["/bin/sh"]
{{- end -}}
{{- end -}}

{{/* 
Create args for secretsLoader
Usage: {{ include "harnesscommon.secretsLoader.args" (dict "ctx" . "entry_point" "/opt/harness/run.sh") }}
*/}}

{{- define "harnesscommon.secretsLoader.args" -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
{{- $secretLoaderCmd := default "false" .secrets_loader_cmd -}}
{{- if eq $secretLoaderCmd "true" }}
["-c", {{ include "harnesscommon.secretsLoader.mergeScript" (dict "entry_point" .entry_point) | quote }}]
{{- else }}
["/bin/sh", "-c", {{ include "harnesscommon.secretsLoader.mergeScript" (dict "entry_point" .entry_point) | quote }}]
{{- end -}}
{{- end -}}
{{- end -}}

{{/* 
Create configContent for secretsLoader
Usage:   {{- include "harnesscommon.secretsloader.configContent" (dict "ctx" $ "databaseSecrets" (list 
    (dict "dbtype" "mongo" "usernamesecrets" list("MONGODB_USER" "RESOURCE_GROUP_MONGO_USER") "passwordsecrets" list("MONGODB_PASSWORD" "RESOURCE_GROUP_MONGO_PASSWORD"))
    (dict "dbtype" "redis" "usernamesecrets" list("REDIS_USERNAME" "RESOURCE_GROUP_REDIS_USERNAME") "passwordsecrets" list("REDIS_PASSWORD" "RESOURCE_GROUP_REDIS_PASSWORD"))
  ))}}
*/}}

{{- define "harnesscommon.secretsLoader.configContent" -}}
{{- if eq (include "harnesscommon.secretsLoader.enabled" (dict "ctx" .ctx)) "true" }}
{{- $ctx := default . .ctx -}}
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
        outputFile: {{ printf "%s/.env" (dig "secrets" "envSecrets" "outputPath" "/shared/env" $mergedSecrets) | quote }}
        categories: {{ dig "secrets" "envSecrets" "categories" (list "database" "api") $mergedSecrets | toYaml | nindent 10 }}
      fileSecrets:
        enabled: {{ dig "secrets" "fileSecrets" "enabled" true $mergedSecrets | quote }}
        outputPath: {{ dig "secrets" "fileSecrets" "outputPath" "/shared/files" $mergedSecrets | quote }}
        categories: {{ dig "secrets" "fileSecrets" "categories" (list "config") $mergedSecrets | toYaml | nindent 10 }}
    databases:
    {{- $list := default (list) .databaseSecrets }}
    {{- if $list }}
      {{- range $i, $db := $list }}
      {{- $dbtype := index $db "dbtype" }}
      {{- $databaseEngineEnabled := dig "databases" $dbtype "useDatabaseSecretsEngine" "false" $mergedSecrets }}
      - type: {{ $dbtype | quote }}
        useDatabaseSecretsEngine: {{ $databaseEngineEnabled | quote }}
        engine: {{ dig "databases" $dbtype "engine" "" $mergedSecrets | quote }}
        databaseRole: {{ dig "databases" $dbtype "databaseRole" "" $mergedSecrets | quote }}
        overridePath: {{ dig "databases" $dbtype "overridePath" "" $mergedSecrets | quote }}
        basePath: {{ dig "databases" $dbtype "basePath" "" $mergedSecrets | quote }}
        {{- with (index $db "usernamesecrets") }}
        userEnvSecrets:
          {{- range $j, $u := . }}
          - {{ $u | quote }}
          {{- end }}
        {{- end }}
        {{- with (index $db "passwordsecrets") }}
        passwordEnvSecrets:
          {{- range $j, $p := . }}
          - {{ $p | quote }}
          {{- end }}
        {{- end }}
      {{- end }}
    {{- end }}
{{- end -}}
{{- end -}}

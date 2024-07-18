{{/*
Check if valid ESO Secrets are provided in the secrets context

Returns:
  "true" if ESO Secrets are provided
  "false" if ESO Secrets are not provided 

Example:
{{ include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" .Values.secrets) }}
*/}}
{{- define "harnesscommon.secrets.hasESOSecrets" }}
{{- $hasESOSecrets := "false" }}
{{- if and .secretsCtx .secretsCtx.secretManagement .secretsCtx.secretManagement.externalSecretsOperator }}
  {{- with .secretsCtx.secretManagement.externalSecretsOperator }}
    {{- range $externalSecretIdx, $externalSecret := . }}
      {{- $hasESOSecrets = include "harnesscommon.secrets.hasValidESOSecret" (dict "esoSecretCtx" .) }}
    {{- end }}
  {{- end }}
{{- end }}
{{- print $hasESOSecrets }}
{{- end }}

{{/*
Check if only one valid ESO Secret is provided in the secrets context

Returns: bool

Example:
{{ include "harnesscommon.secrets.hasSingleValidESOSecret" (dict "secretsCtx" .Values.secrets) }}
*/}}
{{- define "harnesscommon.secrets.hasSingleValidESOSecret" }}
  {{- $secretsCtx := .secretsCtx }}
  {{- $hasSingleValidESOSecret := "false" }}
  {{- if and $secretsCtx .secretsCtx.secretManagement $secretsCtx.secretManagement.externalSecretsOperator (eq (len $secretsCtx.secretManagement.externalSecretsOperator) 1) }}
    {{- $externalSecret := first $secretsCtx.secretManagement.externalSecretsOperator }}
        {{- $hasSingleValidESOSecret = include "harnesscommon.secrets.hasValidESOSecret" (dict "esoSecretCtx" $externalSecret) }}
  {{- end }}
  {{- print $hasSingleValidESOSecret }}
{{- end }}

{{/*
Generate ESO Local Secret Context Identifier

Generates Identifier following the format: <chart-name>-<additional-ctx-identifier>-ext-secret

Example:
{{ include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $  "additionalCtxIdentifier" "timescaledb") }}
*/}}
{{- define "harnesscommon.secrets.localESOSecretCtxIdentifier" }}
  {{- $ := .ctx }}
  {{- $additionalCtxIdentifier := .additionalCtxIdentifier }}
  {{- $localESOSecretIdentifier := "" }}
  {{- if $additionalCtxIdentifier }}
    {{- $localESOSecretIdentifier = (printf "%s-%s-ext-secret" $.Chart.Name $additionalCtxIdentifier) }}
  {{- else }}
    {{- $localESOSecretIdentifier = (printf "%s-ext-secret" $.Chart.Name) }}
  {{- end }}
  {{- printf "%s" $localESOSecretIdentifier }}
{{- end }}

{{/*
Generate ESO global Secret Context Identifier

Generates Identifier following the format: <ctx-identifier>-ext-secret

Example:
{{ include "harnesscommon.secrets.globalESOSecretCtxIdentifier" (dict "ctx" $  "ctxIdentifier" "timescaledb") }}
*/}}
{{- define "harnesscommon.secrets.globalESOSecretCtxIdentifier" }}
  {{- $ := .ctx }}
  {{- $ctxIdentifier := .ctxIdentifier }}
  {{- $globalESOSecretIdentifier := "" }}
  {{- if $ctxIdentifier }}
    {{- $globalESOSecretIdentifier = (printf "%s-ext-secret" $ctxIdentifier) }}
  {{- else }}
    {{- fail "Failed: invalid inputs"}}
  {{- end }}
  {{- printf "%s" $globalESOSecretIdentifier }}
{{- end }}

{{/*
Check validity of ESO Secret in the externalSecretsOperator secret context

Returns:
  "true" if ESO Secret is Valid
  "false" if ESO Secret is not Valid 

Example:
{{ include "harnesscommon.secrets.hasValidESOSecret" (dict "esoSecretCtx" .externalSecretsOperator[idx]) }}
*/}}
{{- define "harnesscommon.secrets.hasValidESOSecret" }}
{{- $hasValidESOSecret := "false" }}
  {{- if and .esoSecretCtx .esoSecretCtx.secretStore .esoSecretCtx.secretStore.name .esoSecretCtx.secretStore.kind }}
    {{- range $remoteKeyIndex, $remoteKey := .esoSecretCtx.remoteKeys }}
      {{- if $remoteKey.name }}
        {{- $hasValidESOSecret = "true" }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- print $hasValidESOSecret }}
{{- end }}

{{/*
Check if input variableName is provided as an ESO Secret

Returns:
  "true" if provided as an ESO Secret
  "false" if not provided as an ESO Secret

{{ include "harnesscommon.secrets.hasESOSecret" (dict "variableName" "MY_VARIABLE" "esoSecretCtxs" (list (dict "secretCtxIdentifier" "local" "secretCtx" .Values.secrets.secretManagement.externalSecretsOperator))) }}
*/}}
{{- define "harnesscommon.secrets.hasESOSecret" }}
{{- $hasESOSecret := "false" }}
{{- if .variableName }}
  {{- range .esoSecretCtxs }}
    {{- $secretCtxIdentifier := .secretCtxIdentifier }}
    {{- $secretCtx := .secretCtx }}
    {{- range $secretCtx }}
      {{- if and . .secretStore .secretStore.name .secretStore.kind }}
        {{- $remoteKeyName := (dig "remoteKeys" $.variableName "name" "" .) }}
        {{- if $remoteKeyName }}
          {{- $hasESOSecret = "true" -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- print $hasESOSecret -}}
{{- end -}}

{{/*
Generates ESO SecretName based on the following:
1. secretContextIdentifier
2. secretIdentifier

Example:
{{ include "harnesscommon.secrets.esoSecretName" (dict "ctx" . "secretContextIdentifier" "local" "secretIdentifier" "1") }}
*/}}
{{- define "harnesscommon.secrets.esoSecretName" -}}
{{- $ := .ctx -}}
{{- $secretContextIdentifier := .secretContextIdentifier | toString -}}
{{- $secretIdentifier := .secretIdentifier | toString -}}
{{- if and .ctx $secretContextIdentifier $secretIdentifier -}}
  {{- printf "%s-%s" $secretContextIdentifier $secretIdentifier  -}}
{{- else -}}
  {{- fail "Failed: invalid input" -}}
{{- end -}}
{{- end -}}

{{/*
Generates env object with variableName for ESO Secrets

USAGE:
{{- include "harnesscommon.secrets.manageESOSecretEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "esoSecretCtxs" {{- include "harnesscommon.secrets.manageESOSecretEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "esoSecretCtxs" "esoSecretCtxs" (list (dict "secretCtxIdentifier" "app-ext-secret" "secretCtx" .Values.secrets.secretManagement.externalSecretsOperator))) }}
) }}
*/}}
{{- define "harnesscommon.secrets.manageESOSecretEnv" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $secretName := "" }}
{{- $secretKey := "" }}
{{- if .variableName }}
  {{- range .esoSecretCtxs }}
    {{- $secretCtxIdentifier := .secretCtxIdentifier }}
    {{- $secretCtx := .secretCtx }}
    {{- range $esoSecretIdx, $esoSecret := $secretCtx }}
      {{- if and $esoSecret $esoSecret.secretStore $esoSecret.secretStore.name $esoSecret.secretStore.kind }}
        {{- $remoteKeyName := (dig "remoteKeys" $variableName "name" "" .) }}
        {{- if $remoteKeyName }}
          {{- $secretName = include "harnesscommon.secrets.esoSecretName" (dict "ctx" $ "secretContextIdentifier" $secretCtxIdentifier "secretIdentifier" $esoSecretIdx) }}
          {{- $secretKey = $variableName }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
  {{- if and $secretName $secretKey }}
- name: {{ print $envVariableName }}
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s" $secretName }}
      key: {{ printf "%s" $secretKey }}
  {{- end }}
{{- end }}

{{/*
Generates ESO External Secret CRD

USAGE:
{{ include "harnesscommon.secrets.generateExternalSecret" (dict "ctx" . "secretsCtx" .Values.secrets "secretIdentifier" "local") }}
*/}}
{{- define "harnesscommon.secrets.generateExternalSecret" }}
{{- $ := .ctx }}
{{- $secretNamePrefix := .secretNamePrefix }}
{{- if and .secretsCtx .secretsCtx.secretManagement .secretsCtx.secretManagement.externalSecretsOperator }}
    {{- with .secretsCtx.secretManagement.externalSecretsOperator }}
        {{- range $esoSecretIdx, $esoSecret := . }}
          {{- if eq (include "harnesscommon.secrets.hasValidESOSecret" (dict "esoSecretCtx" .)) "true" }}
            {{- $esoSecretName := (printf "%s-%d" $secretNamePrefix $esoSecretIdx) }}
            {{- if gt $esoSecretIdx 0 }}
{{ printf "\n---"  }}
            {{- end }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ $esoSecretName }}
spec:
  secretStoreRef:
    name: {{ $esoSecret.secretStore.name }}
    kind: {{ $esoSecret.secretStore.kind }}
  target:
    name: {{ $esoSecretName }}
    template:
      engineVersion: v2
      mergePolicy: Replace
      data:
        {{- range $remoteKeyName, $remoteKey := $esoSecret.remoteKeys }}
          {{- if not (empty $remoteKey.name) }}
        {{ $remoteKeyName }}: "{{ printf "{{ .%s }}" (lower $remoteKeyName | replace "-" "_") }}"
          {{- end }}
        {{- end }}
  data:
  {{- range $remoteKeyName, $remoteKey := $esoSecret.remoteKeys }}
    {{- if not (empty $remoteKey.name) }}
  - secretKey: {{ lower $remoteKeyName | replace "-" "_" }}
    remoteRef:
      key: {{ $remoteKey.name }}
      {{- if not (empty $remoteKey.property) }}
      property: {{ $remoteKey.property }}
      {{- end }}
    {{- end }}
  {{- end }}
          {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Generates Random secrets for the provided secret keys in helpers.tpl or direct usage in secret file
USAGE:
{{- include "harnesscommon.generateSecretsInHelpers" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.generateSecretsInHelpers" }}
{{- $ := .ctx }}
{{- $hasAtleastOneSecret := false }}
{{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- range $key, $value := .ctx.Values.secrets.default }}
    {{- $hasAtleastOneSecret = true }}
    {{- $pathTosSecret := printf "secrets.default.%s" $key }}
{{- $defaultSecretName := dig "defaultSecretName" $.Chart.Name $.Values.secrets }}
{{ $key }}: {{ include "harnesscommon.secrets.passwords.manage" (dict "secret" $defaultSecretName "key" $key "providedValues" (list $pathTosSecret ) "length" 10 "context" $) }}
{{- end }}
{{- end }}

{{/*
Renders secrets as environment variables for the provided secret keys in deployment.yaml/sts.yaml
USAGE:
{{- include "harnesscommon.renderSecretsAsEnvironmentVariables" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.renderSecretsAsEnvironmentVariables" }}
{{- $ := .ctx }}
{{- $hasAtleastOneSecret := false }}
{{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- $defaultSecretList := .ctx.Values.secrets.default }}
{{- $kubernetesSecretsList := dict }}
{{- range $ind := .ctx.Values.secrets.kubernetesSecrets }}
    {{- $kubernetesSecretsList = merge $kubernetesSecretsList $ind.keys }}
{{- end}}
{{- $ESOSecretsList := dict }}
{{- range $ind := .ctx.Values.secrets.secretManagement.externalSecretsOperator }}
    {{- $ESOSecretsList = merge $ESOSecretsList $ind.remoteKeys }}
{{- end}}
{{- $fileSecretMap := list }}
{{- range $ind := .ctx.Values.secrets.fileSecret }}
    {{- range $ind.keys }}
        {{- $fileSecretMap = append $fileSecretMap .key }}
    {{- end}}
{{- end}}
{{- $defaultSecretName := dig "defaultSecretName" $.Chart.Name $.Values.secrets }}
{{- $conditionsList := .ctx.Values.secrets }}
{{- $mergedSecretKeys := keys $defaultSecretList $kubernetesSecretsList $ESOSecretsList | uniq }}
{{- range $key := $mergedSecretKeys }}
    {{- if not (has $key $fileSecretMap) }}
    {{- $diggedCondition := dig "conditions" $key "NOTFOUND" $conditionsList }}
    {{- $condition := "true" }}
        {{- if ne $diggedCondition "NOTFOUND" }}
            {{- $condition = include "harnesscommon.utils.getValueFromKey" (dict "key" $diggedCondition "context" $ ) }}
        {{- end }}
        {{- if $condition }}
{{- include "harnesscommon.secrets.manageAppEnv" (dict "ctx" $ "variableName" $key "defaultKubernetesSecretName" $defaultSecretName "defaultKubernetesSecretKey" $key)}}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Renders secrets as volumes depending on inputs in .Values.secret
USAGE:
{{- include "harnesscommon.renderSecretsAsVolumes" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.renderSecretsAsVolumes" }}
{{- $ := .ctx }}
{{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- range $ind, $indexvalue := .ctx.Values.secrets.fileSecret }}
{{- $keys := $indexvalue.keys }}
{{- $defaultSecretList := list }}
{{- $extKubernetesSecretsList := list }}
{{- $extKubernetesSecretCtxs := list ($.Values.secrets.kubernetesSecrets) }}
{{- $extKubernetesSecretsMap := list }}
{{- $esoSecretsList := list }}
{{- $esoSecretCtxs := list (dict "secretCtx" $.Values.secrets.secretManagement.externalSecretsOperator) }}
{{- $esoSecretsMap := list }}
{{- range $index := $keys }}
    {{- if eq (include "harnesscommon.secrets.hasESOSecret" (dict "variableName" $index.key "esoSecretCtxs" $esoSecretCtxs)) "true" }}
        {{- $esoSecretsList = append $esoSecretsList $index.key }}
    {{- else if eq (include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" $index.key "extKubernetesSecretCtxs" $extKubernetesSecretCtxs)) "true" }}
        {{- $extKubernetesSecretsList = append $extKubernetesSecretsList $index.key }}
    {{- else if hasKey $.Values.secrets.default $index.key }}
        {{- $defaultSecretList = append $defaultSecretList $index.key }}
    {{- end }}
{{- end }}
{{- range $value := $extKubernetesSecretCtxs }}
    {{- range $v := $value }}
        {{- $secretListMap := list }}
        {{- $secretFound := false }}
        {{- range $variableName := $extKubernetesSecretsList }}
            {{- if and $v $v.secretName $v.keys }}
                    {{- if and (hasKey $v.keys $variableName) (get $v.keys $variableName) }}
                        {{- $secretListMap = append $secretListMap (dict "keyName" $variableName "secretKeyName" (get $v.keys $variableName)) }}
                        {{- $secretFound = true }}
                    {{- end }}
            {{- end }}
        {{- end }}
        {{- if $secretFound }}
            {{- $secretName:= .secretName }}
            {{- $extKubernetesSecretsMap = append $extKubernetesSecretsMap (dict $secretName $secretListMap) }}
        {{- end }}
    {{- end }}
{{- end }}
{{- range $esoSecretCtxs }}
    {{- $secretCtx := .secretCtx }}
        {{- range $idx, $idxvalue := $secretCtx }}
        {{- $secretName := printf "%s-%s" $localESOSecretCtxIdentifier ($idx |toString) }}
        {{- $secretListMap := list }}
        {{- $secretFound := false}}
        {{- range $variableName := $esoSecretsList }}
            {{- if and $idxvalue $idxvalue.secretStore $idxvalue.secretStore.name $idxvalue.secretStore.kind }}
                    {{- $remoteKeyName := (dig "remoteKeys" $variableName "name" "" $idxvalue) }}
                    {{- if $remoteKeyName }}
                        {{- $secretListMap = append $secretListMap (dict "keyName" $variableName "secretKeyName" $remoteKeyName) }}
                        {{- $secretFound = true }}
                    {{- end -}}
            {{- end -}}
        {{- end -}}
        {{- if $secretFound }}
            {{- $esoSecretsMap = append $esoSecretsMap (dict $secretName $secretListMap) }}
        {{- end -}}
    {{- end }}
{{- end }}
{{- $defaultSecretName := dig "defaultSecretName" $.Chart.Name $.Values.secrets }}
- name: all-secrets-mount-{{ $ind }}
  projected:
    sources:
    {{- if gt (len $defaultSecretList) 0 }}
    - secret:
        name: {{ $defaultSecretName }}
        items:
        {{- range $key := $defaultSecretList }}
        {{- $path := $key }}
        {{- range $k := $keys }}
            {{- if eq $k.key $key }}
                {{- $path = default $path $k.path }}
            {{- end }}
        {{- end }}
        - key: {{ $key }}
          path: {{ $path }}
        {{- end }}
    {{- end }}
    {{- range $value := $extKubernetesSecretsMap }}
    {{- range $k,$v := $value }}
    - secret:
        name: {{ $k }}
        items:
        {{- range $contents := $v }}
        {{- $path := $contents.keyName }}
        {{- range $k := $keys }}
            {{- if eq $k.key $contents.keyName }}
                {{- $path = default $path $k.path }}
            {{- end }}
        {{- end }}
        - key: {{ $contents.secretKeyName }}
          path: {{ $path }}
        {{- end }}
    {{- end }}
    {{- end }}
    {{- range $value := $esoSecretsMap }}
    {{- range $k,$v := $value }}
    - secret:
        name: {{ $k }}
        items:
        {{- range $contents := $v }}
        {{- $path := $contents.keyName }}
        {{- range $k := $keys }}
            {{- if eq $k.key $contents.keyName }}
                {{- $path = default $path $k.path }}
            {{- end }}
        {{- end }}
        - key: {{ $contents.keyName }}
          path: {{ $path }}
        {{- end }}
    {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Renders secrets as volumeMounts depending on inputs in .Values.secret
USAGE:
{{- include "harnesscommon.mountRenderedSecretsAsVolumeMounts" (dict "ctx" $) }}
*/}}
{{- define "harnesscommon.mountRenderedSecretsAsVolumeMounts" }}
{{- $ := .ctx }}
{{- range $ind, $indexvalue := .ctx.Values.secrets.fileSecret }}
- name: all-secrets-mount-{{ $ind }}
  mountPath: {{ $indexvalue.volumeMountPath | quote }}
{{- end}}
{{- end }}

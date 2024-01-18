{{/*
Checks if provided variableName relies on default secret

Example:
{{ include "harnesscommon.secrets.isDefault" (dict "ctx" . "variableName" "MY_VARIABLE" "providedSecretValues" (list "values.secret1" "")  "extKubernetesSecretCtxs" (list .Values.secrets) "esoSecretCtxs" (list (dict "" .Values.secrets.secretManagement.externalSecretsOperator))) }}
*/}}
{{- define "harnesscommon.secrets.isDefault" }}
  {{- $ := .ctx }}
  {{- $variableName := .variableName }}
  {{- $defaultValue := .defaultValue }}
  {{- $isDefault := true }}
  {{- if eq (include "harnesscommon.secrets.hasESOSecret" (dict "variableName" .variableName "esoSecretCtxs" .esoSecretCtxs)) "true" }}
    {{- $isDefault = false }}
  {{- else if eq (include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" .variableName "extKubernetesSecretCtxs" .extKubernetesSecretCtxs)) "true" }}
    {{- $isDefault = false }}
  {{- else if eq (include "harnesscommon.secrets.hasprovidedSecretValues" (dict "ctx" $ "providedSecretValues" .providedSecretValues)) "true" }}
    {{- $isDefault = false }}
  {{- end }}
  {{- printf "%v" $isDefault }}
{{- end }}

{{/*
Checks if provided variableName relies on default App secret
USAGE:
{{ include "harnesscommon.secrets.isDefaultAppSecret" (dict "ctx" $ "variableName" "MY_VARIABLE" "providedSecretValues" (list "values.secret1" "")  "extKubernetesSecretCtxs" (list .Values.secrets) "esoSecretCtxs" (list (dict "" .Values.secrets.secretManagement.externalSecretsOperator))) }}

INPUT ARGUMENTS:
REQUIRED:
1. ctx

OPTIONAL:
1. providedSecretValues
2. extKubernetesSecretCtxs
3. esoSecretCtxs

*/}}
{{- define "harnesscommon.secrets.isDefaultAppSecret" }}
  {{- $ := .ctx }}
  {{- $variableName := .variableName }}
  {{- $defaultValue := .defaultValue }}
  {{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
  {{- $extKubernetesSecretCtxs := default (list $.Values.secrets.kubernetesSecrets) .extKubernetesSecretCtxs }}
  {{- $esoSecretCtxs := default (list (dict "secretCtxIdentifier" $localESOSecretCtxIdentifier "secretCtx" $.Values.secrets.secretManagement.externalSecretsOperator)) .esoSecretCtxs }}
  {{- $isDefault := true }}
  {{- if eq (include "harnesscommon.secrets.hasESOSecret" (dict "variableName" $variableName "esoSecretCtxs" $esoSecretCtxs)) "true" }}
    {{- $isDefault = false }}
  {{- else if eq (include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" $variableName "extKubernetesSecretCtxs" $extKubernetesSecretCtxs)) "true" }}
    {{- $isDefault = false }}
  {{- else if eq (include "harnesscommon.secrets.hasprovidedSecretValues" (dict "ctx" $ "providedSecretValues" .providedSecretValues)) "true" }}
    {{- $isDefault = false }}
  {{- end }}
  {{- printf "%v" $isDefault }}
{{- end }}

{{/*
Generates env object with variableName for Secret in the following precedence order
1. ESO Secret
2. External Kubernetes Secret
3. Provided Secret Values
4. Default Value
5. Default/Generated Kubernetes Secret

USAGE:
{{ include "harnesscommon.secrets.manageEnv" (dict "ctx" . "variableName" "MY_VARIABLE" "overrideEnvName" "MY_ENV_NAME" "defaultValue" "my-secret-value" "defaultKubernetesSecretName" "defaultSecretName" "defaultKubernetesSecretKey" "defaultSecretKey" "providedSecretValues" (list "values.secret1" "")  "extKubernetesSecretCtxs" (list .Values.secrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" "app-ext-secret" "secretCtx" .Values.secrets.secretManagement.externalSecretsOperator))) }}
*/}}
{{- define "harnesscommon.secrets.manageEnv" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $defaultValue := .defaultValue }}
{{- if eq (include "harnesscommon.secrets.hasESOSecret" (dict "variableName" .variableName "esoSecretCtxs" .esoSecretCtxs)) "true" }}
  {{- include "harnesscommon.secrets.manageESOSecretEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "esoSecretCtxs" .esoSecretCtxs) }}
{{- else if eq (include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" .variableName "extKubernetesSecretCtxs" .extKubernetesSecretCtxs)) "true" }}
  {{- include "harnesscommon.secrets.manageExtKubernetesSecretEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "extKubernetesSecretCtxs" .extKubernetesSecretCtxs) }}
{{- else if eq (include "harnesscommon.secrets.hasprovidedSecretValues" (dict "ctx" $ "providedSecretValues" .providedSecretValues)) "true" }}
  {{- include "harnesscommon.secrets.manageProvidedSecretValuesEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "providedSecretValues" .providedSecretValues) }}
{{- else }}
  {{- if not (empty $defaultValue) }}
- name: {{ print $envVariableName }}
  value: {{ print $defaultValue }}
  {{- else if and (not (empty .defaultKubernetesSecretName)) (not (empty .defaultKubernetesSecretKey)) }}
    {{- include "harnesscommon.secrets.manageDefaultKubernetesSecretEnv" (dict "variableName" .variableName "overrideEnvName" .overrideEnvName "defaultKubernetesSecretName" .defaultKubernetesSecretName "defaultKubernetesSecretKey" .defaultKubernetesSecretKey) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Generates env object with variableName for App Secret in the following precedence order
1. ESO Secret
2. External Kubernetes Secret
3. Provided Secret Values
4. Default Value
5. Default/Generated Kubernetes Secret

USAGE:
{{ include "harnesscommon.secrets.manageAppEnv" (dict "ctx" $ "variableName" "MY_VARIABLE" "overrideEnvName" "MY_ENV_NAME" "defaultValue" "my-secret-value" "defaultKubernetesSecretName" "defaultSecretName" "defaultKubernetesSecretKey" "defaultSecretKey" "providedSecretValues" (list "values.secret1" "")) }}
*/}}
{{- define "harnesscommon.secrets.manageAppEnv" }}
{{- $ := .ctx }}
{{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- include "harnesscommon.secrets.manageEnv" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "defaultKubernetesSecretName" .defaultKubernetesSecretName "providedSecretValues" .providedSecretValues "defaultKubernetesSecretKey" .defaultKubernetesSecretKey "extKubernetesSecretCtxs" (list $.Values.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localESOSecretCtxIdentifier "secretCtx" $.Values.secrets.secretManagement.externalSecretsOperator))) }}
{{- end }}




{{- define "harnesscommon.secrets.generateExternalSecretRefInternal"}}
{{- $ := .ctx }}
{{- $secretNamePrefix := .secretNamePrefix }}
{{- if and .secretsCtx .secretsCtx.secretManagement .secretsCtx.secretManagement.externalSecretsOperator }}
    {{- with .secretsCtx.secretManagement.externalSecretsOperator }}
        {{- range $esoSecretIdx, $esoSecret := . }}
          {{- if eq (include "harnesscommon.secrets.hasValidESOSecret" (dict "esoSecretCtx" .)) "true" }}
            {{- $esoSecretName := (printf "%s-%d" $secretNamePrefix $esoSecretIdx) }}
- secretRef:
    name: {{ $esoSecretName }}
          {{- end }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}


{{/*
Function and its warpper to add the K8S Secret created by external secret controller to serve as Env Var Ref

USAGE:
{{- include "harnesscommon.secrets.generateExternalSecretRef" . }}
*/}}
{{- define "harnesscommon.secrets.generateExternalSecretRef"}}
{{- if eq (include "harnesscommon.secrets.hasESOSecrets" (dict "secretsCtx" .Values.secrets)) "true" }}
{{- $localESOSecretIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- include "harnesscommon.secrets.generateExternalSecretRefInternal" (dict "secretsCtx" .Values.secrets "secretNamePrefix" $localESOSecretIdentifier) }}
{{- end }}
{{- end }}

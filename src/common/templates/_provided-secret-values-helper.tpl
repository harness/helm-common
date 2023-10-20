{{/*
Checks if Provided Secret Values are valid

USAGE:
{{ include "harnesscommon.secrets.hasprovidedSecretValues" (dict "ctx" $ "providedSecretValues" (list "values.secret1" "values.secret2")) }}
*/}}
{{- define "harnesscommon.secrets.hasprovidedSecretValues" }}
    {{- $ := .ctx }}
    {{- $providedSecretValues := .providedSecretValues }}
    {{- $hasprovidedSecretValues := "false" }}
    {{- range .providedSecretValues }}
        {{- if . }}
            {{- $secretValueKey := include "harnesscommon.utils.getKeyFromList" (dict "keys" $providedSecretValues "context" $) }}
            {{- $secretValue := include "harnesscommon.utils.getValueFromKey" (dict "key" $secretValueKey "context" $) }}
            {{- if and (not (empty $secretValueKey)) (not (empty $secretValue)) }}
                {{- $hasprovidedSecretValues = "true" }}
            {{- end }}
        {{- end }}
    {{- end }}
    {{- print $hasprovidedSecretValues }}
{{- end }}

{{/*
Generates env object with variableName from Provided Secret Values

USAGE:
{{ include "harnesscommon.secrets.manageProvidedSecretValuesEnv" (dict "ctx" $ "variableName" "MY_VARIABLE" "overrideEnvName" "MY_ENV" "providedSecretValues" (list "values.secret1" "values.secret2")) }}
*/}}
{{- define "harnesscommon.secrets.manageProvidedSecretValuesEnv" }}
    {{- $ := .ctx }}
    {{- $variableName := .variableName }}
    {{- $envVariableName := $variableName }}
    {{- if .overrideEnvName }}
        {{- $envVariableName = .overrideEnvName }}
    {{- end }}
    {{- $providedSecretValues := .providedSecretValues }}
    {{- $secretValue := "" }}
    {{- if not (empty $variableName) }}
        {{- range .providedSecretValues }}
            {{- if . }}
                {{- $secretValueKey := include "harnesscommon.utils.getKeyFromList" (dict "keys" $providedSecretValues "context" $) }}
                {{- $currSecretValue := include "harnesscommon.utils.getValueFromKey" (dict "key" $secretValueKey "context" $) }}
                {{- if and (not (empty $secretValueKey)) (not (empty $currSecretValue)) }}
                    {{- $secretValue = $currSecretValue }}
                {{- end }}
            {{- end }}
        {{- end }}
        {{- if not (empty $secretValue) }}
- name: {{ print $envVariableName }}
  value: '{{ print $secretValue }}'
        {{- end }}
    {{- end }}
{{- end }}
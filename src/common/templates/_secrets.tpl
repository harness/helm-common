{{- define "harnesscommon.secrets.passwords.manage" -}}

{{- $password := "" }}
{{- $subchart := "" }}
{{- $chartName := default "" .chartName }}
{{- $passwordLength := default 10 .length }}
{{- $providedPasswordKey := include "harnesscommon.utils.getKeyFromList" (dict "keys" .providedValues "context" $.context) }}
{{- $providedPasswordValue := include "harnesscommon.utils.getValueFromKey" (dict "key" $providedPasswordKey "context" $.context) }}
{{- $secretData := (lookup "v1" "Secret" (include "harnesscommon.names.namespace" .context) .secret).data }}
{{- if $secretData }}
  {{- if hasKey $secretData .key }}
    {{- $password = index $secretData .key | quote }}
  {{- else }}
    {{- printf "\nPASSWORDS ERROR: The secret \"%s\" does not contain the key \"%s\"\n" .secret .key | fail -}}
  {{- end -}}
{{- else if $providedPasswordValue }}
  {{- $password = $providedPasswordValue | toString | b64enc | quote }}
{{- else }}

  {{- if .context.Values.enabled }}
    {{- $subchart = $chartName }}
  {{- end -}}

  {{- if .strong }}
    {{- $subStr := list (lower (randAlpha 1)) (randNumeric 1) (upper (randAlpha 1)) | join "_" }}
    {{- $password = randAscii $passwordLength }}
    {{- $password = regexReplaceAllLiteral "\\W" $password "@" | substr 5 $passwordLength }}
    {{- $password = printf "%s%s" $subStr $password | toString | shuffle | b64enc | quote }}
  {{- else }}
    {{- $password = randAlphaNum $passwordLength | b64enc | quote }}
  {{- end }}
{{- end -}}
{{- printf "%s" $password -}}
{{- end -}}
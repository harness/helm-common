{{- define "harnesscommon.secrets.manageESOSecretVolumes" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- $path := .path }}
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
  secret:
    secretName: {{ printf "%s" $secretName }}
    items: 
    - key: {{ printf "%s" $secretKey }}
      path: {{ printf "%s" $path }}
  {{- end }}
{{- end }}

{{- define "harnesscommon.secrets.manageExtKubernetesSecretVolumes" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- $path := .path }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $secretName := "" }}
{{- $secretKey := "" }}
{{- if $variableName }}
  {{- range .extKubernetesSecretCtxs }}
    {{- range . }}
      {{- if and . .secretName .keys }}
        {{- $currSecretKey := (get .keys $variableName) }}
        {{- if and (hasKey .keys $variableName) $currSecretKey }}
          {{- $secretName = .secretName }}
          {{- $secretKey = $currSecretKey }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if and $secretName $secretKey }}
- name: {{ print $envVariableName }}
  secret:
    secretName: {{ printf "%s" $secretName }}
    items: 
    - key: {{ printf "%s" $secretKey }}
      path: {{ printf "%s" $path }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "harnesscommon.secrets.manageKubernetesSecretVolumes" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- $path := .path }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $secretName := .defaultKubernetesSecretName }}
{{- $secretKey := .defaultKubernetesSecretKey }}
{{- if $variableName }}
  {{- if and $secretName $secretKey }}
- name: {{ print $envVariableName }}
  secret:
    secretName: {{ printf "%s" $secretName }}
    items: 
    - key: {{ printf "%s" $secretKey }}
      path: {{ printf "%s" $path }}
  {{- end }}
{{- end }}
{{- end }}




{{- define "harnesscommon.secrets.manageVolumes" }}
{{- $ := .ctx }}
{{- $variableName := .variableName }}
{{- $envVariableName := $variableName }}
{{- if .overrideEnvName }}
  {{- $envVariableName = .overrideEnvName }}
{{- end }}
{{- $defaultValue := .defaultValue }}
{{- if eq (include "harnesscommon.secrets.hasESOSecret" (dict "variableName" .variableName "esoSecretCtxs" .esoSecretCtxs)) "true" }}
{{- include "harnesscommon.secrets.manageESOSecretVolumes" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "path" .path "esoSecretCtxs"  .esoSecretCtxs) }}
{{- else if eq (include "harnesscommon.secrets.hasExtKubernetesSecret" (dict "variableName" .variableName "extKubernetesSecretCtxs" .extKubernetesSecretCtxs)) "true" }}
{{- include "harnesscommon.secrets.manageExtKubernetesSecretVolumes" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "path" .path "extKubernetesSecretCtxs" .extKubernetesSecretCtxs) }}
{{- else }}
{{- include "harnesscommon.secrets.manageKubernetesSecretVolumes" (dict "ctx" $ "variableName" .variableName "overrideEnvName" .overrideEnvName "path" .path "defaultKubernetesSecretName" .defaultKubernetesSecretName "defaultKubernetesSecretKey" .defaultKubernetesSecretKey "extKubernetesSecretCtxs" .extKubernetesSecretCtxs) }}
{{- end }}
{{- end }}

{{- define "harnesscommon.secrets.manageAppVolumes" }}
{{- $ := .ctx }}
{{- $localESOSecretCtxIdentifier := (include "harnesscommon.secrets.localESOSecretCtxIdentifier" (dict "ctx" $ )) }}
{{- include "harnesscommon.secrets.manageVolumes" (dict "ctx" $ "variableName" .variableName "path" .path "overrideEnvName" .overrideEnvName "defaultKubernetesSecretName" .defaultKubernetesSecretName "providedSecretValues" .providedSecretValues "defaultKubernetesSecretKey" .defaultKubernetesSecretKey "extKubernetesSecretCtxs" (list $.Values.secrets.kubernetesSecrets) "esoSecretCtxs" (list (dict "secretCtxIdentifier" $localESOSecretCtxIdentifier "secretCtx" $.Values.secrets.secretManagement.externalSecretsOperator))) }}
{{- end }}
{{/* 
Manages precedence of values

USAGE:
{{ include "harnesscommon.precedence.manage" (list .Values.global.database.timescaledb.sslEnabled .Values.timescaledb.sslEnabled ) }}
*/}}
{{- define "harnesscommon.precedence.manage" }}
{{- $value := "" -}}
{{- end }}

{{/* 
Checks if the provided value keys have valid value

USAGE:
{{ include "harnesscommon.precedence.hasValidKey" (dict "ctx" $ "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled")) }}
*/}}
{{- define "harnesscommon.precedence.hasValidKey" }}
    {{- $ := .ctx }}
    {{- $keys := .keys }}
    {{- $hasValidValue := false }}
    {{- range $keyIdx, $key := $keys }}
        {{- $currValue := "" }}
        {{- $key = trimPrefix "." $key }}
        {{- $key = trimPrefix "Values." $key }}
        {{- $splitedKey := splitList "." $key }}
        {{- $latestObj := $.Values }}
        {{- $currHasValidValue := true }}
        {{- range $splitedKey }}
            {{- if and $latestObj $currHasValidValue }}
                {{- $currValue = ( index $latestObj . ) }}
                {{- $latestObj = $currValue }}
            {{- else }}
                {{- $currHasValidValue = false }}
            {{- end }}
        {{- end }}
        {{- if and $currHasValidValue (not (eq $currValue nil)) }}
            {{- $hasValidValue = true }}
        {{- end }}
    {{- end }}
    {{- printf "%v" $hasValidValue }}
{{- end }}

{{/*
Checks if the provided value keys have valid value

USAGE:
{{ include "harnesscommon.precedence.getValueFromKey" (dict "ctx" $ "valueType" "string" "keys" (list ".Values.global.database.timescaledb.sslEnabled" ".Values.timescaledb.sslEnabled")) }}
*/}}
{{- define "harnesscommon.precedence.getValueFromKey" }}
    {{- $ := .ctx }}
    {{- $keys := .keys }}
    {{- $valueType := .valueType }}
    {{- $hasValidValue := false }}
    {{- $value := "" -}}
    {{- range $keyIdx, $key := $keys }}
        {{- $currValue := "" }}
        {{- $key = trimPrefix "." $key }}
        {{- $key = trimPrefix "Values." $key }}
        {{- $splitedKey := splitList "." $key }}
        {{- $latestObj := $.Values }}
        {{- $currHasValidValue := true }}
        {{- range $splitedKey }}
            {{- if and $latestObj $currHasValidValue }}
                {{- $currValue = ( index $latestObj . ) }}
                {{- $latestObj = $currValue }}
            {{- else }}
                {{- $currHasValidValue = false }}
            {{- end }}
        {{- end }}
        {{- if and $currHasValidValue (not (eq $currValue nil)) }}
            {{- if and (eq $valueType "string") (not (empty $currValue)) }}
                {{- $hasValidValue = true }}
                {{- $value = printf "%v" $currValue }}
            {{- else if (eq $valueType "bool") }}
                {{- $hasValidValue = true }}
                {{- $value = printf "%v" $currValue }}
            {{- end }}
        {{- end }}
    {{- end }}
    {{- printf "%v" $value }}
{{- end }}
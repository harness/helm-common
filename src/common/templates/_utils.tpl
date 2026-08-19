{{- define "harnesscommon.utils.getValueFromKey" -}}
{{- $splitKey := splitList "." .key -}}
{{- $value := "" -}}
{{- $latestObj := $.context.Values -}}
{{- range $splitKey -}}
  {{- if not $latestObj -}}
    {{- printf "please review the entire path of '%s' exists in values" $.key | fail -}}
  {{- end -}}
  {{- $value = ( index $latestObj . ) -}}
  {{- $latestObj = $value -}}
{{- end -}}
{{- printf "%v" (default "" $value) -}}
{{- end -}}
{{- define "harnesscommon.utils.getKeyFromList" -}}
{{- $key := first .keys -}}
{{- $reverseKeys := reverse .keys }}
{{- range $reverseKeys }}
  {{- $value := include "harnesscommon.utils.getValueFromKey" (dict "key" . "context" $.context ) }}
  {{- if $value -}}
    {{- $key = . }}
  {{- end -}}
{{- end -}}
{{- printf "%s" $key -}}
{{- end -}}

{{/*
Look up a dotted values path without failing.

Missing keys, nil intermediates, and non-map intermediates print "false".
Boolean false prints "false" (unlike harnesscommon.utils.getValueFromKey, whose
`default` treats false as empty).

USAGE:
{{ include "harnesscommon.utils.getValueFromKeyOrFalse" (dict "key" "global.ng.enabled" "ctx" $) }}
*/}}
{{- define "harnesscommon.utils.getValueFromKeyOrFalse" -}}
{{- $value := .ctx.Values -}}
{{- $missing := false -}}
{{- range splitList "." .key -}}
  {{- if or $missing (not (kindIs "map" $value)) (not (hasKey $value .)) -}}
    {{- $missing = true -}}
  {{- else -}}
    {{- $value = index $value . -}}
  {{- end -}}
{{- end -}}
{{- if $missing -}}
false
{{- else -}}
{{- printf "%v" $value -}}
{{- end -}}
{{- end -}}

{{/*
Evaluate a recursive `when` condition for Ingress / HTTPRoute objects.

Supported nodes:
  key/equals - compare a values path; equals defaults to "true"
  allOf      - all child nodes must match
  anyOf      - at least one child node must match
  not        - negate a child node

Missing `when` evaluates to true (always render).
A missing or non-map values path evaluates to false (not a render failure).

USAGE:
{{ include "harnesscommon.utils.evalWhen" (dict "ctx" $ "when" $object.when) }}
*/}}
{{- define "harnesscommon.utils.evalWhen" -}}
{{- $ctx := .ctx -}}
{{- $when := .when | default dict -}}
{{- if not $when -}}
true
{{- else if hasKey $when "key" -}}
  {{- $actual := include "harnesscommon.utils.getValueFromKeyOrFalse" (dict "key" $when.key "ctx" $ctx) | trim -}}
  {{- $expected := dig "equals" "true" $when | toString -}}
  {{- if eq $actual $expected -}}true{{- else -}}false{{- end -}}
{{- else if hasKey $when "not" -}}
  {{- $result := include "harnesscommon.utils.evalWhen" (dict "ctx" $ctx "when" $when.not) | trim -}}
  {{- if eq $result "true" -}}false{{- else -}}true{{- end -}}
{{- else if hasKey $when "allOf" -}}
  {{- $matches := true -}}
  {{- range $when.allOf -}}
    {{- if ne (include "harnesscommon.utils.evalWhen" (dict "ctx" $ctx "when" .) | trim) "true" -}}
      {{- $matches = false -}}
    {{- end -}}
  {{- end -}}
  {{- if $matches -}}true{{- else -}}false{{- end -}}
{{- else if hasKey $when "anyOf" -}}
  {{- $matches := false -}}
  {{- range $when.anyOf -}}
    {{- if eq (include "harnesscommon.utils.evalWhen" (dict "ctx" $ctx "when" .) | trim) "true" -}}
      {{- $matches = true -}}
    {{- end -}}
  {{- end -}}
  {{- if $matches -}}true{{- else -}}false{{- end -}}
{{- else -}}
true
{{- end -}}
{{- end -}}

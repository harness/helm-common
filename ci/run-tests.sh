#!/usr/bin/env bash
# Smoke-test the harness-common library: template scenarios + helm-unittest.
# Exits 0 only if all pass. Requires helm and (for unittest) helm-unittest plugin.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="${REPO_ROOT}/ci/test-chart"
VALUES_DIR="${CHART_DIR}/ci-values"
RELEASE_NAME="harness-common-test"

cd "$REPO_ROOT"
echo "Updating test chart dependencies (harness-common from file)..."
helm dependency update "$CHART_DIR"

run_scenario() {
  local name="$1"
  local values_file="$2"
  echo "  Scenario: $name (${values_file})"
  helm template "$RELEASE_NAME" "$CHART_DIR" -f "$values_file" >/dev/null
}

echo "Rendering scenarios..."
run_scenario "HPA"    "${VALUES_DIR}/hpa.yaml"
run_scenario "PDB"    "${VALUES_DIR}/pdb.yaml"
run_scenario "KEDA"   "${VALUES_DIR}/keda.yaml"
echo "All template scenarios passed."

echo ""
echo "Running helm-unittest..."
if helm unittest --help &>/dev/null; then
  helm unittest "$CHART_DIR"
else
  echo "  (helm-unittest plugin not installed; skipping. Install with: helm plugin install https://github.com/helm-unittest/helm-unittest --verify=false)"
fi

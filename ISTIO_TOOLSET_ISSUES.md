# Istio Toolset Implementation — GitHub Issues

Below are 8 issues that break the Istio toolset implementation into trackable work items. They're organized by phase and dependency order.

---

## Issue 1: `[Istio Toolset] Phase 1: Create istio/core YAML toolset`

**Labels:** `enhancement`

### Summary
Create the foundational `istio/core` YAML toolset at `holmes/plugins/toolsets/istio.yaml` following the pattern established by `cilium.yaml` and `argocd.yaml`.

### Tools
| Tool Name | Command | Description |
|-----------|---------|-------------|
| `istioctl_version` | `istioctl version` | Show Istio control plane and client versions |
| `istioctl_analyze_cluster` | `istioctl analyze --all-namespaces` | Analyze entire cluster for config issues |
| `istioctl_analyze_namespace` | `istioctl analyze -n {{ namespace }}` | Analyze a specific namespace |
| `istioctl_proxy_status` | `istioctl proxy-status` | Show sync status of all Envoy proxies |

### Key details
- Prerequisites: `istioctl version --short`, `kubectl version --client`
- Tags: `cli`
- LLM instructions must encode troubleshooting order (analyze → proxy-status → branch to sidecar/ambient)
- Encode common footguns: injection labeling, revision drift, PeerAuthentication scope, DestinationRule TLS mismatch, VirtualService host/gateway mismatch, port naming
- Add `llm_summarize` transformers on high-volume outputs

---

## Issue 2: `[Istio Toolset] Phase 1: Create istio/sidecar YAML toolset`

**Labels:** `enhancement`  
**Depends on:** Issue 1

### Summary
Create the `istio/sidecar` toolset section for Envoy sidecar proxy inspection.

### Tools
| Tool Name | Command |
|-----------|---------|
| `istioctl_pc_clusters` | `istioctl proxy-config clusters {{ pod_name }}.{{ namespace }}` |
| `istioctl_pc_listeners` | `istioctl proxy-config listeners {{ pod_name }}.{{ namespace }}` |
| `istioctl_pc_routes` | `istioctl proxy-config routes {{ pod_name }}.{{ namespace }}` |
| `istioctl_pc_endpoints` | `istioctl proxy-config endpoints {{ pod_name }}.{{ namespace }}` |
| `istioctl_pc_bootstrap` | `istioctl proxy-config bootstrap {{ pod_name }}.{{ namespace }}` |
| `istioctl_pc_log` | `istioctl proxy-config log {{ pod_name }}.{{ namespace }}` |

### Key details
- `llm_summarize` on all proxy-config commands
- Bootstrap needs aggressive summarization (large output)
- LLM instructions guide: clusters/endpoints → listeners → routes → bootstrap (last resort)

---

## Issue 3: `[Istio Toolset] Phase 2: Create istio/ambient YAML toolset`

**Labels:** `enhancement`  
**Depends on:** Issue 1

### Summary
Create the `istio/ambient` toolset section for ztunnel and waypoint inspection.

### Tools
| Tool Name | Command |
|-----------|---------|
| `istioctl_ztunnel_config_workloads` | `istioctl ztunnel-config workloads` |
| `istioctl_ztunnel_config_services` | `istioctl ztunnel-config services` |
| `istioctl_ztunnel_config_policies` | `istioctl ztunnel-config policies` |
| `istioctl_waypoint_list` | `istioctl waypoint list -n {{ namespace }}` |
| `istioctl_waypoint_status` | `istioctl waypoint status {{ waypoint_name }} -n {{ namespace }}` |

### Key details
- Version-aware: ambient commands require Istio 1.22+
- Use `|| echo "Command not available in this Istio version"` fallback pattern
- LLM instructions cover: enrollment verification → ztunnel state → waypoint requirements for L7
- Mixed mode guidance: check both Envoy and ztunnel state

---

## Issue 4: `[Istio Toolset] Add documentation page and update index`

**Labels:** `documentation`

### Summary
Add `docs/data-sources/builtin-toolsets/istio.md` and update all integration index pages.

### Files to create/update
- **New:** `docs/data-sources/builtin-toolsets/istio.md`
- **Update:** `docs/data-sources/builtin-toolsets/index.md` (add Istio card)
- **Update:** `README.md` (Data Sources table)
- **Update:** `docs/walkthrough/why-holmesgpt.md` (integration list)
- **Update:** `.nav.yml` (navigation)
- **New:** `images/integration_logos/istio.svg` (if available)

### Example prompts for docs page
```
holmes ask "Why is traffic between the frontend and backend services failing?"
```
```
holmes ask "Are there any Istio configuration issues in the payments namespace?"
```
```
holmes ask "Why are some pods not getting sidecar injection?"
```
```
holmes ask "Check if mTLS is properly configured between service A and service B"
```

---

## Issue 5: `[Istio Toolset] Add unit tests for YAML loading and command rendering`

**Labels:** `enhancement`

### Summary
Add `tests/plugins/toolsets/test_istio.py` with tests for:
1. YAML loading (all sub-toolsets present, prerequisites defined)
2. Command rendering (namespace, pod_name, waypoint_name parameters)
3. Error output includes stderr for LLM self-correction
4. LLM instructions are non-empty and mention key steps

---

## Issue 6: `[Istio Toolset] Verify Helm chart CRD permissions`

**Labels:** `enhancement`

### Summary
Verify the existing `crdPermissions.istio: true` covers all Istio CRDs the toolset needs. Review `helm/holmes/templates/holmesgpt-service-account.yaml` and document gaps.

### CRDs to verify
- `networking.istio.io`: VirtualService, DestinationRule, Gateway, ServiceEntry, Sidecar, EnvoyFilter
- `security.istio.io`: PeerAuthentication, AuthorizationPolicy, RequestAuthentication
- `telemetry.istio.io`: Telemetry
- `gateway.networking.k8s.io`: Gateway, HTTPRoute (Gateway API mode)

---

## Issue 7: `[Istio Toolset] Phase 3: Create LLM eval test fixtures`

**Labels:** `enhancement`  
**Depends on:** Issues 1, 2, 3

### Summary
Create LLM eval test fixtures for:
1. **mTLS mismatch** (sidecar) — DestinationRule conflicts with PeerAuthentication
2. **Missing waypoint for L7 policy** (ambient) — HTTP AuthorizationPolicy without waypoint
3. **Sidecar injection failure** — wrong injection label/revision mismatch
4. **Proxy sync failure** — proxies showing STALE in proxy-status

Each scenario under `tests/llm/fixtures/test_ask_holmes/` with anti-hallucination expected outputs.

---

## Issue 8: `[Istio Toolset] Phase 3: Advanced diagnostics and optional debug tools`

**Labels:** `enhancement`  
**Depends on:** Issues 1, 2, 3

### Summary
Extend with lower-priority advanced tools:

| Tool | Notes |
|------|-------|
| `istioctl bug-report` | Needs strict timeout + summarization |
| `istioctl proxy-config secret` | Cert expiry debugging |
| `istioctl x describe pod` | Human-readable mesh description |
| `istioctl x precheck` | Pre-upgrade compatibility |
| `istioctl remote-clusters` | Multi-cluster only |
| `istioctl proxy-config ecds` | WasmPlugin/EnvoyFilter debugging |

All must be read-only with appropriate timeouts and version fallbacks.

---

## Dependency graph

```
Issue 1 (istio/core)
├── Issue 2 (istio/sidecar)      ← Phase 1
├── Issue 3 (istio/ambient)      ← Phase 2
├── Issue 5 (unit tests)         ← Phase 1
├── Issue 6 (Helm CRD perms)     ← Phase 1
├── Issue 7 (LLM eval tests)     ← Phase 3 (after 1,2,3)
└── Issue 8 (advanced tools)     ← Phase 3 (after 1,2,3)

Issue 4 (documentation)          ← Can start after Phase 1
```

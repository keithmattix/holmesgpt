"""
Unit tests for the Istio YAML toolset.
"""

import os

from holmes.plugins.toolsets import load_toolsets_from_file

from .transformer_test_utils import ensure_transformers_registered


class TestIstioToolset:
    """Test that the Istio toolset loads correctly and has the expected structure."""

    def _load_istio_toolset(self):
        """Helper to load the istio.yaml file and return the istio/core toolset."""
        ensure_transformers_registered()

        current_dir = os.path.dirname(os.path.abspath(__file__))
        istio_yaml_path = os.path.join(
            current_dir,
            "..",
            "..",
            "..",
            "holmes",
            "plugins",
            "toolsets",
            "istio.yaml",
        )

        toolsets = load_toolsets_from_file(istio_yaml_path)

        istio_core = None
        for toolset in toolsets:
            if toolset.name == "istio/core":
                istio_core = toolset
                break

        assert istio_core is not None, "istio/core toolset not found"
        return istio_core

    def test_load_istio_yaml(self):
        """Test that istio.yaml loads correctly via load_toolsets_from_file."""
        istio_core = self._load_istio_toolset()
        assert istio_core.description is not None
        assert "Istio" in istio_core.description

    def test_istio_prerequisites(self):
        """Test that prerequisites include istioctl and kubectl checks."""
        istio_core = self._load_istio_toolset()
        prereq_commands = [p.command for p in istio_core.prerequisites]
        assert "istioctl version --short" in prereq_commands
        assert "kubectl version --client" in prereq_commands

    def test_istio_tools_present(self):
        """Test that all required tools are defined."""
        istio_core = self._load_istio_toolset()
        tool_names = [t.name for t in istio_core.tools]
        assert "istioctl_version" in tool_names
        assert "istioctl_analyze_cluster" in tool_names
        assert "istioctl_analyze_namespace" in tool_names
        assert "istioctl_proxy_status" in tool_names

    def test_istioctl_analyze_namespace_has_namespace_param(self):
        """Test that istioctl_analyze_namespace accepts a namespace parameter."""
        istio_core = self._load_istio_toolset()
        analyze_ns = None
        for tool in istio_core.tools:
            if tool.name == "istioctl_analyze_namespace":
                analyze_ns = tool
                break

        assert analyze_ns is not None
        assert "namespace" in analyze_ns.parameters

    def test_istioctl_analyze_cluster_has_llm_summarize_transformer(self):
        """Test that istioctl_analyze_cluster has an llm_summarize transformer."""
        istio_core = self._load_istio_toolset()
        analyze_cluster = None
        for tool in istio_core.tools:
            if tool.name == "istioctl_analyze_cluster":
                analyze_cluster = tool
                break

        assert analyze_cluster is not None
        assert analyze_cluster.transformers is not None
        assert len(analyze_cluster.transformers) >= 1
        assert analyze_cluster.transformers[0].name == "llm_summarize"
        assert analyze_cluster.transformers[0].config["input_threshold"] == 1000

    def test_istioctl_proxy_status_has_llm_summarize_transformer(self):
        """Test that istioctl_proxy_status has an llm_summarize transformer."""
        istio_core = self._load_istio_toolset()
        proxy_status = None
        for tool in istio_core.tools:
            if tool.name == "istioctl_proxy_status":
                proxy_status = tool
                break

        assert proxy_status is not None
        assert proxy_status.transformers is not None
        assert len(proxy_status.transformers) >= 1
        assert proxy_status.transformers[0].name == "llm_summarize"
        assert proxy_status.transformers[0].config["input_threshold"] == 1000

    def test_istio_tags(self):
        """Test that the toolset has the cli tag."""
        istio_core = self._load_istio_toolset()
        tag_values = [t.value for t in istio_core.tags]
        assert "cli" in tag_values

    def test_istio_llm_instructions(self):
        """Test that LLM instructions contain key troubleshooting guidance."""
        istio_core = self._load_istio_toolset()
        instructions = istio_core.llm_instructions
        assert instructions is not None
        assert "istioctl_analyze_cluster" in instructions
        assert "istioctl_proxy_status" in instructions
        assert "PeerAuthentication" in instructions
        assert "DestinationRule" in instructions
        assert "VirtualService" in instructions

    def test_istio_commands_render(self):
        """Test that tool commands contain expected CLI commands."""
        istio_core = self._load_istio_toolset()
        tool_commands = {t.name: t.command for t in istio_core.tools}
        assert "istioctl version" in tool_commands["istioctl_version"]
        assert "istioctl analyze --all-namespaces" in tool_commands["istioctl_analyze_cluster"]
        assert "istioctl analyze -n" in tool_commands["istioctl_analyze_namespace"]
        assert "istioctl proxy-status" in tool_commands["istioctl_proxy_status"]

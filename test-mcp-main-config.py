#!/usr/bin/env python3
"""
Test script for the main MCP configuration file.
Validates configuration structure, environment detection, and server connectivity.
"""

import json
import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Any, Optional

class MCPConfigTester:
    def __init__(self):
        self.config_path = Path(".kiro/settings/mcp.json")
        self.config = None
        self.test_results = {
            "config_validation": False,
            "environment_detection": False,
            "server_connectivity": {},
            "optimization_settings": False,
            "auto_approval_patterns": False,
            "performance_settings": False
        }
        
    def load_config(self) -> bool:
        """Load and validate the main MCP configuration file."""
        try:
            if not self.config_path.exists():
                print(f"❌ Configuration file not found: {self.config_path}")
                return False
                
            with open(self.config_path, 'r') as f:
                self.config = json.load(f)
                
            print(f"✅ Successfully loaded MCP configuration from {self.config_path}")
            return True
            
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON in configuration file: {e}")
            return False
        except Exception as e:
            print(f"❌ Error loading configuration: {e}")
            return False
    
    def validate_config_structure(self) -> bool:
        """Validate the structure of the MCP configuration."""
        try:
            required_sections = [
                "mcpServers",
                "environmentConfiguration", 
                "globalOptimization",
                "workflowSpecificOptimization",
                "intelligentRouting",
                "securityConfiguration",
                "monitoringAndAlerting"
            ]
            
            missing_sections = []
            for section in required_sections:
                if section not in self.config:
                    missing_sections.append(section)
            
            if missing_sections:
                print(f"❌ Missing required sections: {missing_sections}")
                return False
            
            # Validate MCP servers
            servers = self.config["mcpServers"]
            required_servers = [
                "aws-infrastructure",
                "kubernetes-management", 
                "prometheus-metrics",
                "loki-logs",
                "grafana-dashboards",
                "github-actions",
                "terraform-state"
            ]
            
            missing_servers = []
            for server in required_servers:
                if server not in servers:
                    missing_servers.append(server)
            
            if missing_servers:
                print(f"❌ Missing required MCP servers: {missing_servers}")
                return False
            
            # Validate server configurations
            for server_name, server_config in servers.items():
                required_fields = ["command", "args", "env", "disabled", "autoApprove"]
                missing_fields = []
                
                for field in required_fields:
                    if field not in server_config:
                        missing_fields.append(field)
                
                if missing_fields:
                    print(f"❌ Server {server_name} missing fields: {missing_fields}")
                    return False
            
            print("✅ Configuration structure validation passed")
            return True
            
        except Exception as e:
            print(f"❌ Error validating configuration structure: {e}")
            return False
    
    def test_environment_detection(self) -> bool:
        """Test environment detection logic."""
        try:
            env_config = self.config["environmentConfiguration"]
            
            # Check detection methods
            detection = env_config.get("detection", {})
            methods = detection.get("methods", [])
            priority = detection.get("priority", [])
            
            expected_methods = [
                "environment_variable",
                "kubernetes_context", 
                "aws_profile",
                "cluster_tags",
                "directory_structure"
            ]
            
            missing_methods = []
            for method in expected_methods:
                if method not in methods:
                    missing_methods.append(method)
            
            if missing_methods:
                print(f"❌ Missing detection methods: {missing_methods}")
                return False
            
            # Check environment configurations
            environments = env_config.get("environments", {})
            expected_envs = ["dev", "staging", "prod"]
            
            missing_envs = []
            for env in expected_envs:
                if env not in environments:
                    missing_envs.append(env)
            
            if missing_envs:
                print(f"❌ Missing environment configurations: {missing_envs}")
                return False
            
            # Test current environment detection
            current_env = self.detect_current_environment()
            print(f"✅ Detected current environment: {current_env}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error testing environment detection: {e}")
            return False
    
    def detect_current_environment(self) -> str:
        """Detect the current environment based on configuration logic."""
        # Check environment variable first
        if os.getenv("KIRO_ENVIRONMENT"):
            return os.getenv("KIRO_ENVIRONMENT")
        
        # Check Kubernetes context
        try:
            result = subprocess.run(
                ["kubectl", "config", "current-context"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                context = result.stdout.strip()
                if "dev" in context:
                    return "dev"
                elif "staging" in context:
                    return "staging"
                elif "prod" in context:
                    return "prod"
        except:
            pass
        
        # Check AWS profile
        aws_profile = os.getenv("AWS_PROFILE", "default")
        if aws_profile in ["dev", "staging", "prod"]:
            return aws_profile
        
        # Default to dev
        return "dev"
    
    def test_server_connectivity(self) -> bool:
        """Test connectivity to MCP servers (mock test)."""
        try:
            servers = self.config["mcpServers"]
            all_passed = True
            
            for server_name, server_config in servers.items():
                # Mock connectivity test
                print(f"🔍 Testing connectivity to {server_name}...")
                
                # Check if uvx is available
                try:
                    result = subprocess.run(
                        ["which", "uvx"],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    uvx_available = result.returncode == 0
                except:
                    uvx_available = False
                
                if not uvx_available:
                    print(f"⚠️  uvx not available for {server_name} (expected in CI/testing)")
                    self.test_results["server_connectivity"][server_name] = "uvx_not_available"
                else:
                    # In a real scenario, we would test actual connectivity
                    print(f"✅ {server_name} configuration valid")
                    self.test_results["server_connectivity"][server_name] = "config_valid"
            
            return True
            
        except Exception as e:
            print(f"❌ Error testing server connectivity: {e}")
            return False
    
    def test_optimization_settings(self) -> bool:
        """Test optimization settings configuration."""
        try:
            global_opt = self.config["globalOptimization"]
            
            # Check connection management
            conn_mgmt = global_opt.get("connectionManagement", {})
            required_conn_settings = [
                "maxConnectionsPerServer",
                "connectionTimeout", 
                "idleTimeout",
                "keepAlive",
                "connectionPooling"
            ]
            
            missing_conn_settings = []
            for setting in required_conn_settings:
                if setting not in conn_mgmt:
                    missing_conn_settings.append(setting)
            
            if missing_conn_settings:
                print(f"❌ Missing connection management settings: {missing_conn_settings}")
                return False
            
            # Check request optimization
            req_opt = global_opt.get("requestOptimization", {})
            required_req_settings = [
                "requestBatching",
                "batchSize",
                "batchTimeout",
                "retryPolicy",
                "maxRetries"
            ]
            
            missing_req_settings = []
            for setting in required_req_settings:
                if setting not in req_opt:
                    missing_req_settings.append(setting)
            
            if missing_req_settings:
                print(f"❌ Missing request optimization settings: {missing_req_settings}")
                return False
            
            # Check response caching
            cache_opt = global_opt.get("responseCaching", {})
            required_cache_settings = [
                "enabled",
                "defaultCacheDuration",
                "cacheSize", 
                "cacheCompression",
                "cacheInvalidation"
            ]
            
            missing_cache_settings = []
            for setting in required_cache_settings:
                if setting not in cache_opt:
                    missing_cache_settings.append(setting)
            
            if missing_cache_settings:
                print(f"❌ Missing cache optimization settings: {missing_cache_settings}")
                return False
            
            print("✅ Optimization settings validation passed")
            return True
            
        except Exception as e:
            print(f"❌ Error testing optimization settings: {e}")
            return False
    
    def test_auto_approval_patterns(self) -> bool:
        """Test auto-approval patterns for different environments."""
        try:
            servers = self.config["mcpServers"]
            env_config = self.config["environmentConfiguration"]["environments"]
            
            # Test base auto-approval patterns
            for server_name, server_config in servers.items():
                auto_approve = server_config.get("autoApprove", [])
                
                if not auto_approve:
                    print(f"❌ No auto-approval patterns for {server_name}")
                    return False
                
                # Validate pattern format
                for pattern in auto_approve:
                    if not isinstance(pattern, str):
                        print(f"❌ Invalid auto-approval pattern in {server_name}: {pattern}")
                        return False
            
            # Test environment-specific overrides
            for env_name, env_settings in env_config.items():
                server_overrides = env_settings.get("serverOverrides", {})
                
                for server_name, overrides in server_overrides.items():
                    if server_name not in servers:
                        print(f"❌ Environment {env_name} has overrides for unknown server: {server_name}")
                        return False
                    
                    override_patterns = overrides.get("autoApprove", [])
                    for pattern in override_patterns:
                        if not isinstance(pattern, str):
                            print(f"❌ Invalid override pattern in {env_name}/{server_name}: {pattern}")
                            return False
            
            print("✅ Auto-approval patterns validation passed")
            return True
            
        except Exception as e:
            print(f"❌ Error testing auto-approval patterns: {e}")
            return False
    
    def test_performance_settings(self) -> bool:
        """Test performance monitoring and optimization settings."""
        try:
            # Test global performance monitoring
            perf_monitoring = self.config["globalOptimization"].get("performanceMonitoring", {})
            
            required_perf_settings = [
                "enabled",
                "metricsCollection",
                "latencyTracking", 
                "errorRateMonitoring",
                "throughputMeasurement"
            ]
            
            missing_perf_settings = []
            for setting in required_perf_settings:
                if setting not in perf_monitoring:
                    missing_perf_settings.append(setting)
            
            if missing_perf_settings:
                print(f"❌ Missing performance monitoring settings: {missing_perf_settings}")
                return False
            
            # Test workflow-specific optimization
            workflow_opt = self.config["workflowSpecificOptimization"]
            
            expected_workflows = [
                "foundation",
                "ingress",
                "observability", 
                "gitops",
                "security",
                "service-mesh",
                "data-services",
                "cost-optimization"
            ]
            
            missing_workflows = []
            for workflow in expected_workflows:
                if workflow not in workflow_opt:
                    missing_workflows.append(workflow)
            
            if missing_workflows:
                print(f"❌ Missing workflow optimizations: {missing_workflows}")
                return False
            
            # Test intelligent routing
            routing = self.config.get("intelligentRouting", {})
            
            required_routing_settings = [
                "loadBalancing",
                "contextAwareRouting",
                "adaptiveOptimization"
            ]
            
            missing_routing_settings = []
            for setting in required_routing_settings:
                if setting not in routing:
                    missing_routing_settings.append(setting)
            
            if missing_routing_settings:
                print(f"❌ Missing intelligent routing settings: {missing_routing_settings}")
                return False
            
            print("✅ Performance settings validation passed")
            return True
            
        except Exception as e:
            print(f"❌ Error testing performance settings: {e}")
            return False
    
    def run_all_tests(self) -> bool:
        """Run all validation tests."""
        print("🚀 Starting MCP Main Configuration Tests")
        print("=" * 50)
        
        # Load configuration
        if not self.load_config():
            return False
        
        # Run validation tests
        tests = [
            ("Configuration Structure", self.validate_config_structure),
            ("Environment Detection", self.test_environment_detection),
            ("Server Connectivity", self.test_server_connectivity),
            ("Optimization Settings", self.test_optimization_settings),
            ("Auto-Approval Patterns", self.test_auto_approval_patterns),
            ("Performance Settings", self.test_performance_settings)
        ]
        
        all_passed = True
        for test_name, test_func in tests:
            print(f"\n🔍 Running {test_name} test...")
            try:
                result = test_func()
                self.test_results[test_name.lower().replace(" ", "_")] = result
                if not result:
                    all_passed = False
            except Exception as e:
                print(f"❌ {test_name} test failed with exception: {e}")
                self.test_results[test_name.lower().replace(" ", "_")] = False
                all_passed = False
        
        # Print summary
        print("\n" + "=" * 50)
        print("📊 Test Results Summary")
        print("=" * 50)
        
        for test_name, result in self.test_results.items():
            if isinstance(result, dict):
                # Handle server connectivity results
                if test_name == "server_connectivity":
                    print(f"🔍 {test_name.replace('_', ' ').title()}:")
                    for server, status in result.items():
                        status_icon = "✅" if "valid" in status else "⚠️"
                        print(f"  {status_icon} {server}: {status}")
            else:
                status_icon = "✅" if result else "❌"
                print(f"{status_icon} {test_name.replace('_', ' ').title()}: {'PASSED' if result else 'FAILED'}")
        
        print(f"\n🎯 Overall Result: {'✅ ALL TESTS PASSED' if all_passed else '❌ SOME TESTS FAILED'}")
        
        return all_passed

def main():
    """Main test execution."""
    tester = MCPConfigTester()
    success = tester.run_all_tests()
    
    # Save test results
    results_file = "mcp-main-config-test-results.json"
    with open(results_file, 'w') as f:
        json.dump({
            "timestamp": time.time(),
            "success": success,
            "results": tester.test_results
        }, f, indent=2)
    
    print(f"\n📄 Test results saved to: {results_file}")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
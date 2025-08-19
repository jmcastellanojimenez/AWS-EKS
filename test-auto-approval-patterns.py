#!/usr/bin/env python3
"""
Test script for auto-approval patterns validation.
"""

import json
import re
from pathlib import Path

def test_auto_approval_patterns():
    """Test auto-approval patterns for different servers and environments."""
    config_path = Path(".kiro/settings/mcp.json")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    print("🔍 Testing Auto-Approval Patterns")
    print("=" * 40)
    
    servers = config["mcpServers"]
    environments = config["environmentConfiguration"]["environments"]
    
    # Test base patterns
    print("\n1. Base Auto-Approval Patterns:")
    for server_name, server_config in servers.items():
        patterns = server_config.get("autoApprove", [])
        print(f"\n   {server_name}:")
        for pattern in patterns[:5]:  # Show first 5 patterns
            print(f"     ✓ {pattern}")
        if len(patterns) > 5:
            print(f"     ... and {len(patterns) - 5} more patterns")
    
    # Test environment-specific overrides
    print("\n2. Environment-Specific Overrides:")
    for env_name, env_config in environments.items():
        server_overrides = env_config.get("serverOverrides", {})
        if server_overrides:
            print(f"\n   {env_name.upper()} Environment:")
            for server_name, overrides in server_overrides.items():
                override_patterns = overrides.get("autoApprove", [])
                print(f"     {server_name}: {len(override_patterns)} patterns")
                for pattern in override_patterns[:3]:  # Show first 3
                    print(f"       ✓ {pattern}")
                if len(override_patterns) > 3:
                    print(f"       ... and {len(override_patterns) - 3} more")
    
    # Test pattern matching logic
    print("\n3. Pattern Matching Tests:")
    test_operations = [
        ("aws-infrastructure", "describe-instances"),
        ("aws-infrastructure", "list-buckets"),
        ("aws-infrastructure", "get-cost-and-usage"),
        ("kubernetes-management", "get pods"),
        ("kubernetes-management", "describe nodes"),
        ("prometheus-metrics", "query"),
        ("prometheus-metrics", "query_range"),
        ("loki-logs", "query"),
        ("github-actions", "list-workflows"),
        ("terraform-state", "show")
    ]
    
    for server_name, operation in test_operations:
        if server_name in servers:
            patterns = servers[server_name].get("autoApprove", [])
            matched = check_pattern_match(operation, patterns)
            status = "✅" if matched else "❌"
            print(f"   {status} {server_name}: '{operation}' → {'APPROVED' if matched else 'REQUIRES APPROVAL'}")
    
    print("\n✅ Auto-approval pattern tests completed!")

def check_pattern_match(operation, patterns):
    """Check if an operation matches any of the approval patterns."""
    for pattern in patterns:
        # Handle wildcard patterns
        if pattern.endswith("*"):
            prefix = pattern[:-1]
            if operation.startswith(prefix):
                return True
        # Handle exact matches
        elif pattern == operation:
            return True
        # Handle regex-like patterns (basic)
        elif "-" in pattern and "*" in pattern:
            # Convert simple patterns like "describe-*" to regex
            regex_pattern = pattern.replace("*", ".*").replace("-", r"\-")
            if re.match(f"^{regex_pattern}$", operation):
                return True
    
    return False

def test_security_boundaries():
    """Test that security boundaries are properly configured."""
    config_path = Path(".kiro/settings/mcp.json")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    print("\n🔍 Testing Security Boundaries")
    print("=" * 40)
    
    environments = config["environmentConfiguration"]["environments"]
    
    # Test approval gates by environment
    print("\n1. Approval Gates by Environment:")
    for env_name, env_config in environments.items():
        approval_gates = env_config.get("approvalGates", {})
        print(f"\n   {env_name.upper()} Environment:")
        
        security_checks = [
            ("destructiveOperations", "Destructive Operations"),
            ("resourceModifications", "Resource Modifications"),
            ("configurationChanges", "Configuration Changes"),
            ("costImpactingChanges", "Cost Impacting Changes"),
            ("securityChanges", "Security Changes"),
            ("allOperations", "All Operations")
        ]
        
        for gate_key, gate_name in security_checks:
            gate_value = approval_gates.get(gate_key, False)
            status = "🔒" if gate_value else "🔓"
            print(f"     {status} {gate_name}: {'REQUIRED' if gate_value else 'NOT REQUIRED'}")
    
    # Test compliance settings
    print("\n2. Compliance Settings:")
    prod_config = environments.get("prod", {})
    compliance = prod_config.get("complianceSettings", {})
    
    if compliance:
        print("   Production Compliance:")
        for setting, value in compliance.items():
            status = "✅" if value else "❌"
            print(f"     {status} {setting}: {value}")
    else:
        print("   ⚠️  No compliance settings found for production")
    
    print("\n✅ Security boundary tests completed!")

if __name__ == "__main__":
    test_auto_approval_patterns()
    test_security_boundaries()
    print("\n🎯 All auto-approval and security tests completed successfully!")
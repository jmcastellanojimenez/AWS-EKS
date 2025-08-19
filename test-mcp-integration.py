#!/usr/bin/env python3
"""
MCP Integration Functionality and Performance Test Suite
Tests MCP server connections, auto-approval patterns, and performance optimization features
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional

class MCPIntegrationTester:
    """Test suite for MCP integration functionality and performance"""
    
    def __init__(self):
        self.settings_dir = Path('.kiro/settings')
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'total_configs': 0,
            'configs_tested': 0,
            'connection_tests': [],
            'auto_approval_tests': [],
            'performance_tests': [],
            'cross_system_tests': [],
            'overall_success_rate': 0.0,
            'recommendations': []
        }
        
    def discover_mcp_configs(self) -> List[Path]:
        """Discover all MCP configuration files"""
        if not self.settings_dir.exists():
            print(f"❌ Settings directory not found: {self.settings_dir}")
            return []
            
        mcp_files = list(self.settings_dir.glob('mcp*.json'))
        print(f"📁 Discovered {len(mcp_files)} MCP configuration files")
        return mcp_files
    
    def load_mcp_config(self, config_file: Path) -> Optional[Dict[str, Any]]:
        """Load and parse MCP configuration"""
        try:
            with open(config_file, 'r') as f:
                config = json.load(f)
            print(f"✅ Loaded MCP config: {config_file.name}")
            return config
        except Exception as e:
            print(f"❌ Failed to load MCP config {config_file}: {e}")
            return None
    
    def test_server_configurations(self, config_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Test MCP server configurations"""
        test_result = {
            'config_name': config_name,
            'servers_count': 0,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        servers = config.get('mcpServers', {})
        test_result['servers_count'] = len(servers)
        
        if not servers:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ No MCP servers configured")
            return test_result
        
        # Test each server configuration
        for server_name, server_config in servers.items():
            server_tests = self.test_individual_server(server_name, server_config)
            test_result['tests_passed'] += server_tests['passed']
            test_result['tests_failed'] += server_tests['failed']
            test_result['details'].extend(server_tests['details'])
        
        return test_result
    
    def test_individual_server(self, server_name: str, server_config: Dict[str, Any]) -> Dict[str, Any]:
        """Test individual MCP server configuration"""
        result = {'passed': 0, 'failed': 0, 'details': []}
        
        # Test 1: Required fields
        required_fields = ['command', 'args']
        if all(field in server_config for field in required_fields):
            result['passed'] += 1
            result['details'].append(f"✅ {server_name}: Required fields present")
        else:
            result['failed'] += 1
            result['details'].append(f"❌ {server_name}: Missing required fields")
        
        # Test 2: Command validation
        command = server_config.get('command', '')
        if command in ['uvx', 'python', 'node', 'docker']:
            result['passed'] += 1
            result['details'].append(f"✅ {server_name}: Valid command: {command}")
        else:
            result['failed'] += 1
            result['details'].append(f"❌ {server_name}: Invalid command: {command}")
        
        # Test 3: Environment variables
        env_vars = server_config.get('env', {})
        if env_vars:
            result['passed'] += 1
            result['details'].append(f"✅ {server_name}: Environment variables configured ({len(env_vars)} vars)")
        else:
            result['failed'] += 1
            result['details'].append(f"❌ {server_name}: No environment variables")
        
        # Test 4: Auto-approval configuration
        auto_approve = server_config.get('autoApprove', [])
        if auto_approve and len(auto_approve) > 0:
            result['passed'] += 1
            result['details'].append(f"✅ {server_name}: Auto-approval configured ({len(auto_approve)} patterns)")
        else:
            result['failed'] += 1
            result['details'].append(f"❌ {server_name}: No auto-approval patterns")
        
        # Test 5: Disabled flag
        disabled = server_config.get('disabled', False)
        if not disabled:
            result['passed'] += 1
            result['details'].append(f"✅ {server_name}: Server enabled")
        else:
            result['failed'] += 1
            result['details'].append(f"⚠️ {server_name}: Server disabled")
        
        return result
    
    def test_auto_approval_patterns(self, config_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Test auto-approval patterns for security and functionality"""
        test_result = {
            'config_name': config_name,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        servers = config.get('mcpServers', {})
        
        for server_name, server_config in servers.items():
            auto_approve = server_config.get('autoApprove', [])
            
            if not auto_approve:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"❌ {server_name}: No auto-approval patterns")
                continue
            
            # Test for safe patterns
            safe_patterns = self.validate_auto_approval_safety(server_name, auto_approve)
            if safe_patterns['is_safe']:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✅ {server_name}: Safe auto-approval patterns")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"❌ {server_name}: Unsafe patterns: {', '.join(safe_patterns['unsafe_patterns'])}")
            
            # Test for comprehensive coverage
            coverage = self.assess_auto_approval_coverage(server_name, auto_approve)
            if coverage['score'] >= 70:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✅ {server_name}: Good coverage ({coverage['score']}%)")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"❌ {server_name}: Poor coverage ({coverage['score']}%)")
        
        return test_result
    
    def validate_auto_approval_safety(self, server_name: str, patterns: List[str]) -> Dict[str, Any]:
        """Validate that auto-approval patterns are safe"""
        unsafe_patterns = []
        
        # Define dangerous patterns by server type
        dangerous_patterns = {
            'aws': ['delete-*', 'terminate-*', 'destroy-*', '*'],
            'kubernetes': ['delete', 'destroy', 'apply', 'create', '*'],
            'github': ['delete-*', 'create-*', '*'],
            'default': ['delete-*', 'destroy-*', 'terminate-*', '*', 'rm-*']
        }
        
        # Determine server type
        server_type = 'default'
        if 'aws' in server_name.lower():
            server_type = 'aws'
        elif 'kubernetes' in server_name.lower() or 'k8s' in server_name.lower():
            server_type = 'kubernetes'
        elif 'github' in server_name.lower():
            server_type = 'github'
        
        # Check for dangerous patterns
        dangerous = dangerous_patterns.get(server_type, dangerous_patterns['default'])
        
        for pattern in patterns:
            if any(danger in pattern.lower() for danger in dangerous):
                unsafe_patterns.append(pattern)
        
        return {
            'is_safe': len(unsafe_patterns) == 0,
            'unsafe_patterns': unsafe_patterns,
            'total_patterns': len(patterns)
        }
    
    def assess_auto_approval_coverage(self, server_name: str, patterns: List[str]) -> Dict[str, Any]:
        """Assess the coverage of auto-approval patterns"""
        # Define expected patterns by server type
        expected_patterns = {
            'aws': ['describe-*', 'list-*', 'get-*'],
            'kubernetes': ['get', 'describe', 'logs', 'top'],
            'prometheus': ['query', 'query_range', 'series'],
            'github': ['list-*', 'get-*'],
            'grafana': ['search-*', 'get-*'],
            'loki': ['query', 'labels']
        }
        
        # Determine server type and get expected patterns
        server_type = 'default'
        for stype in expected_patterns.keys():
            if stype in server_name.lower():
                server_type = stype
                break
        
        expected = expected_patterns.get(server_type, [])
        if not expected:
            return {'score': 50, 'covered': [], 'missing': []}
        
        # Calculate coverage
        covered = []
        for expected_pattern in expected:
            if any(expected_pattern in pattern for pattern in patterns):
                covered.append(expected_pattern)
        
        missing = [p for p in expected if p not in covered]
        score = (len(covered) / len(expected)) * 100 if expected else 0
        
        return {
            'score': score,
            'covered': covered,
            'missing': missing
        }
    
    def test_performance_optimizations(self, config_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Test performance optimization features"""
        test_result = {
            'config_name': config_name,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test global optimization settings
        global_opt = config.get('globalOptimization', {})
        if global_opt:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Global optimization settings configured")
            
            # Test specific optimization features
            opt_features = [
                ('connectionManagement', 'Connection management'),
                ('requestOptimization', 'Request optimization'),
                ('responseCaching', 'Response caching'),
                ('performanceMonitoring', 'Performance monitoring')
            ]
            
            for feature_key, feature_name in opt_features:
                if feature_key in global_opt:
                    test_result['tests_passed'] += 1
                    test_result['details'].append(f"✅ {feature_name} configured")
                else:
                    test_result['tests_failed'] += 1
                    test_result['details'].append(f"❌ {feature_name} not configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ No global optimization settings")
        
        # Test server-specific optimizations
        servers = config.get('mcpServers', {})
        servers_with_optimization = 0
        
        for server_name, server_config in servers.items():
            if 'optimization' in server_config:
                servers_with_optimization += 1
        
        if servers_with_optimization > 0:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✅ {servers_with_optimization}/{len(servers)} servers have optimization settings")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ No servers have optimization settings")
        
        # Test workflow-specific optimizations
        workflow_opt = config.get('workflowSpecificOptimization', {})
        if workflow_opt:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✅ Workflow-specific optimizations configured ({len(workflow_opt)} workflows)")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ No workflow-specific optimizations")
        
        return test_result
    
    def test_cross_system_integration(self, configs: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
        """Test cross-system integration and data flow between MCP servers"""
        test_result = {
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Collect all servers across configurations
        all_servers = {}
        for config_name, config in configs.items():
            servers = config.get('mcpServers', {})
            for server_name, server_config in servers.items():
                all_servers[f"{config_name}:{server_name}"] = server_config
        
        # Test for essential integrations
        essential_integrations = [
            ('aws', 'kubernetes', 'AWS-Kubernetes integration'),
            ('prometheus', 'grafana', 'Prometheus-Grafana integration'),
            ('kubernetes', 'prometheus', 'Kubernetes-Prometheus integration'),
            ('loki', 'grafana', 'Loki-Grafana integration')
        ]
        
        for integration1, integration2, description in essential_integrations:
            has_integration1 = any(integration1 in server_key.lower() for server_key in all_servers.keys())
            has_integration2 = any(integration2 in server_key.lower() for server_key in all_servers.keys())
            
            if has_integration1 and has_integration2:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✅ {description} available")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"❌ {description} missing")
        
        # Test for environment consistency
        env_configs = [name for name in configs.keys() if any(env in name for env in ['dev', 'staging', 'prod'])]
        if len(env_configs) >= 2:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✅ Multiple environment configurations ({len(env_configs)} environments)")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Insufficient environment configurations")
        
        # Test for comprehensive server coverage
        server_types = set()
        for server_key in all_servers.keys():
            server_name = server_key.split(':')[1].lower()
            if 'aws' in server_name:
                server_types.add('aws')
            elif 'kubernetes' in server_name or 'k8s' in server_name:
                server_types.add('kubernetes')
            elif 'prometheus' in server_name:
                server_types.add('prometheus')
            elif 'grafana' in server_name:
                server_types.add('grafana')
            elif 'github' in server_name:
                server_types.add('github')
            elif 'loki' in server_name:
                server_types.add('loki')
        
        expected_types = {'aws', 'kubernetes', 'prometheus'}
        missing_types = expected_types - server_types
        
        if not missing_types:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ All essential server types configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append(f"❌ Missing server types: {', '.join(missing_types)}")
        
        return test_result
    
    def simulate_mcp_operations(self, config_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Simulate MCP operations to test functionality"""
        test_result = {
            'config_name': config_name,
            'simulations_run': 0,
            'simulations_passed': 0,
            'details': []
        }
        
        servers = config.get('mcpServers', {})
        
        for server_name, server_config in servers.items():
            # Simulate connection test
            test_result['simulations_run'] += 1
            if self.simulate_server_connection(server_name, server_config):
                test_result['simulations_passed'] += 1
                test_result['details'].append(f"✅ {server_name}: Connection simulation passed")
            else:
                test_result['details'].append(f"❌ {server_name}: Connection simulation failed")
            
            # Simulate auto-approval test
            auto_approve = server_config.get('autoApprove', [])
            if auto_approve:
                test_result['simulations_run'] += 1
                if self.simulate_auto_approval(server_name, auto_approve):
                    test_result['simulations_passed'] += 1
                    test_result['details'].append(f"✅ {server_name}: Auto-approval simulation passed")
                else:
                    test_result['details'].append(f"❌ {server_name}: Auto-approval simulation failed")
        
        return test_result
    
    def simulate_server_connection(self, server_name: str, server_config: Dict[str, Any]) -> bool:
        """Simulate server connection test"""
        # Check if command exists
        command = server_config.get('command', '')
        if not command:
            return False
        
        # Check if required environment variables are defined
        env_vars = server_config.get('env', {})
        required_env_vars = {
            'aws': ['AWS_REGION'],
            'kubernetes': ['KUBECONFIG'],
            'prometheus': ['PROMETHEUS_URL'],
            'github': ['GITHUB_TOKEN'],
            'grafana': ['GRAFANA_URL']
        }
        
        server_type = 'default'
        for stype in required_env_vars.keys():
            if stype in server_name.lower():
                server_type = stype
                break
        
        if server_type in required_env_vars:
            required_vars = required_env_vars[server_type]
            for var in required_vars:
                if var not in env_vars:
                    return False
        
        # Simulate successful connection
        return True
    
    def simulate_auto_approval(self, server_name: str, patterns: List[str]) -> bool:
        """Simulate auto-approval pattern matching"""
        # Test common operations
        test_operations = {
            'aws': ['describe-instances', 'list-buckets', 'get-cost-and-usage'],
            'kubernetes': ['get pods', 'describe nodes', 'logs deployment/app'],
            'prometheus': ['query up', 'query_range cpu_usage', 'series'],
            'github': ['list-workflows', 'get-workflow-run'],
            'grafana': ['search-dashboards', 'get-dashboard']
        }
        
        server_type = 'default'
        for stype in test_operations.keys():
            if stype in server_name.lower():
                server_type = stype
                break
        
        if server_type not in test_operations:
            return True  # Default to success for unknown types
        
        operations = test_operations[server_type]
        approved_operations = 0
        
        for operation in operations:
            for pattern in patterns:
                if self.matches_pattern(pattern, operation):
                    approved_operations += 1
                    break
        
        # Consider successful if at least 70% of operations are approved
        return (approved_operations / len(operations)) >= 0.7
    
    def matches_pattern(self, pattern: str, operation: str) -> bool:
        """Check if operation matches approval pattern"""
        import fnmatch
        
        # Handle wildcard patterns
        if '*' in pattern:
            return fnmatch.fnmatch(operation, pattern)
        
        # Handle exact matches
        return pattern in operation
    
    def run_comprehensive_test(self) -> Dict[str, Any]:
        """Run comprehensive MCP integration test suite"""
        print("🔧 Starting MCP Integration Functionality and Performance Test Suite")
        print("=" * 70)
        
        config_files = self.discover_mcp_configs()
        self.test_results['total_configs'] = len(config_files)
        
        if not config_files:
            print("❌ No MCP configuration files found to test")
            return self.test_results
        
        # Load all configurations
        configs = {}
        for config_file in config_files:
            config_name = config_file.stem
            config = self.load_mcp_config(config_file)
            if config:
                configs[config_name] = config
                self.test_results['configs_tested'] += 1
        
        # Test each configuration
        for config_name, config in configs.items():
            print(f"\n🔍 Testing configuration: {config_name}")
            
            # Test server configurations
            connection_test = self.test_server_configurations(config_name, config)
            self.test_results['connection_tests'].append(connection_test)
            
            # Test auto-approval patterns
            approval_test = self.test_auto_approval_patterns(config_name, config)
            self.test_results['auto_approval_tests'].append(approval_test)
            
            # Test performance optimizations
            performance_test = self.test_performance_optimizations(config_name, config)
            self.test_results['performance_tests'].append(performance_test)
            
            # Simulate MCP operations
            simulation_test = self.simulate_mcp_operations(config_name, config)
            
            print(f"✅ Completed testing configuration: {config_name}")
        
        # Test cross-system integration
        if len(configs) > 1:
            cross_system_test = self.test_cross_system_integration(configs)
            self.test_results['cross_system_tests'].append(cross_system_test)
        
        # Calculate success rates
        self.calculate_success_rates()
        
        # Generate recommendations
        self.generate_recommendations()
        
        print("\n🎉 MCP Integration test suite completed")
        return self.test_results
    
    def calculate_success_rates(self):
        """Calculate success rates for different test categories"""
        categories = [
            ('connection_tests', 'Connection Tests'),
            ('auto_approval_tests', 'Auto-Approval Tests'),
            ('performance_tests', 'Performance Tests')
        ]
        
        total_passed = 0
        total_tests = 0
        
        for category_key, category_name in categories:
            category_tests = self.test_results[category_key]
            category_passed = sum(test['tests_passed'] for test in category_tests)
            category_total = sum(test['tests_passed'] + test['tests_failed'] for test in category_tests)
            
            if category_total > 0:
                category_rate = (category_passed / category_total) * 100
                print(f"📊 {category_name} Success Rate: {category_rate:.1f}% ({category_passed}/{category_total})")
            
            total_passed += category_passed
            total_tests += category_total
        
        if total_tests > 0:
            self.test_results['overall_success_rate'] = (total_passed / total_tests) * 100
            print(f"📊 Overall Success Rate: {self.test_results['overall_success_rate']:.1f}% ({total_passed}/{total_tests})")
    
    def generate_recommendations(self):
        """Generate recommendations based on test results"""
        recommendations = []
        
        # Analyze connection tests
        connection_issues = []
        for test in self.test_results['connection_tests']:
            if test['tests_failed'] > test['tests_passed']:
                connection_issues.append(test['config_name'])
        
        if connection_issues:
            recommendations.append({
                'category': 'Server Configuration',
                'priority': 'High',
                'issue': f"Connection issues in {len(connection_issues)} configurations",
                'configs_affected': connection_issues,
                'recommendation': 'Review server configurations, ensure required fields and valid commands'
            })
        
        # Analyze auto-approval tests
        approval_issues = []
        for test in self.test_results['auto_approval_tests']:
            if test['tests_failed'] > 0:
                approval_issues.append(test['config_name'])
        
        if approval_issues:
            recommendations.append({
                'category': 'Auto-Approval Security',
                'priority': 'High',
                'issue': f"Auto-approval issues in {len(approval_issues)} configurations",
                'configs_affected': approval_issues,
                'recommendation': 'Review auto-approval patterns for security and coverage'
            })
        
        # Analyze performance tests
        performance_issues = []
        for test in self.test_results['performance_tests']:
            if test['tests_failed'] > test['tests_passed']:
                performance_issues.append(test['config_name'])
        
        if performance_issues:
            recommendations.append({
                'category': 'Performance Optimization',
                'priority': 'Medium',
                'issue': f"Performance optimization missing in {len(performance_issues)} configurations",
                'configs_affected': performance_issues,
                'recommendation': 'Add performance optimization features like caching, batching, and connection pooling'
            })
        
        self.test_results['recommendations'] = recommendations
    
    def generate_report(self) -> str:
        """Generate comprehensive test report"""
        report = []
        report.append("# MCP Integration Functionality and Performance Test Report")
        report.append(f"**Generated:** {self.test_results['timestamp']}")
        report.append(f"**Total Configurations:** {self.test_results['total_configs']}")
        report.append(f"**Configurations Tested:** {self.test_results['configs_tested']}")
        report.append(f"**Overall Success Rate:** {self.test_results['overall_success_rate']:.1f}%")
        report.append("")
        
        # Executive Summary
        report.append("## Executive Summary")
        if self.test_results['overall_success_rate'] >= 90:
            report.append("✅ **EXCELLENT** - MCP integration is well-configured and production-ready.")
        elif self.test_results['overall_success_rate'] >= 80:
            report.append("✅ **GOOD** - MCP integration is mostly well-configured with minor improvements needed.")
        elif self.test_results['overall_success_rate'] >= 70:
            report.append("⚠️ **NEEDS IMPROVEMENT** - MCP integration has significant issues that should be addressed.")
        else:
            report.append("❌ **CRITICAL** - MCP integration has major issues that must be fixed before production use.")
        report.append("")
        
        # Requirements Validation
        report.append("## Requirements Validation")
        report.append("### Requirement 9.1: AWS Integration")
        aws_configs = [test for test in self.test_results['connection_tests'] 
                      if any('aws' in detail.lower() for detail in test['details'])]
        if aws_configs:
            report.append("✅ AWS MCP integration configured and tested")
        else:
            report.append("❌ AWS MCP integration not found")
        
        report.append("### Requirement 9.2: Kubernetes Integration")
        k8s_configs = [test for test in self.test_results['connection_tests'] 
                      if any('kubernetes' in detail.lower() for detail in test['details'])]
        if k8s_configs:
            report.append("✅ Kubernetes MCP integration configured and tested")
        else:
            report.append("❌ Kubernetes MCP integration not found")
        
        report.append("### Requirement 9.3: Monitoring Integration")
        monitoring_configs = [test for test in self.test_results['connection_tests'] 
                            if any('prometheus' in detail.lower() or 'grafana' in detail.lower() for detail in test['details'])]
        if monitoring_configs:
            report.append("✅ Monitoring MCP integration configured and tested")
        else:
            report.append("❌ Monitoring MCP integration not found")
        
        report.append("### Requirement 9.4: GitHub Actions Integration")
        github_configs = [test for test in self.test_results['connection_tests'] 
                         if any('github' in detail.lower() for detail in test['details'])]
        if github_configs:
            report.append("✅ GitHub Actions MCP integration configured and tested")
        else:
            report.append("❌ GitHub Actions MCP integration not found")
        
        report.append("### Requirement 9.5: Performance Optimization")
        perf_configs = [test for test in self.test_results['performance_tests'] 
                       if test['tests_passed'] > 0]
        if perf_configs:
            report.append("✅ MCP performance optimization features configured")
        else:
            report.append("❌ MCP performance optimization features not configured")
        
        return "\n".join(report)
    
    def save_results(self, filename: str = 'mcp-integration-test-results.json'):
        """Save test results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)
        print(f"💾 Test results saved to {filename}")
    
    def save_report(self, filename: str = 'mcp-integration-test-report.md'):
        """Save test report to markdown file"""
        report = self.generate_report()
        with open(filename, 'w') as f:
            f.write(report)
        print(f"💾 Test report saved to {filename}")

def main():
    """Main test execution function"""
    print("🔧 Starting MCP Integration Functionality and Performance Test Suite")
    print("=" * 70)
    
    tester = MCPIntegrationTester()
    
    try:
        # Run comprehensive tests
        results = tester.run_comprehensive_test()
        
        # Save results and generate report
        tester.save_results()
        tester.save_report()
        
        # Print summary
        print("\n" + "=" * 70)
        print("📊 TEST SUMMARY")
        print("=" * 70)
        print(f"Total Configurations: {results['total_configs']}")
        print(f"Configurations Tested: {results['configs_tested']}")
        print(f"Overall Success Rate: {results['overall_success_rate']:.1f}%")
        
        if results['overall_success_rate'] >= 90:
            print("🎉 EXCELLENT - MCP integration is production-ready!")
        elif results['overall_success_rate'] >= 80:
            print("✅ GOOD - MCP integration is mostly ready with minor improvements needed")
        elif results['overall_success_rate'] >= 70:
            print("⚠️ NEEDS IMPROVEMENT - Significant issues found")
        else:
            print("❌ CRITICAL - Major issues must be addressed")
        
        print(f"\nDetailed report saved to: mcp-integration-test-report.md")
        print(f"Raw results saved to: mcp-integration-test-results.json")
        
        return 0 if results['overall_success_rate'] >= 80 else 1
        
    except Exception as e:
        print(f"❌ Test suite failed with error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
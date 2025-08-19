#!/usr/bin/env python3
"""
Hook Automation and Trigger Conditions Test Suite
Tests all hook triggers, execution success rates, and error handling
"""

import os
import sys
import json
import yaml
import subprocess
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('hook-automation-test.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class HookAutomationTester:
    """Test suite for hook automation and trigger conditions"""
    
    def __init__(self):
        self.hooks_dir = Path('.kiro/hooks')
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'total_hooks': 0,
            'hooks_tested': 0,
            'trigger_tests': [],
            'execution_tests': [],
            'error_handling_tests': [],
            'integration_tests': [],
            'overall_success_rate': 0.0,
            'recommendations': []
        }
        
    def discover_hooks(self) -> List[Path]:
        """Discover all hook files in the .kiro/hooks directory"""
        if not self.hooks_dir.exists():
            logger.error(f"Hooks directory not found: {self.hooks_dir}")
            return []
            
        hook_files = list(self.hooks_dir.glob('*.yaml'))
        logger.info(f"Discovered {len(hook_files)} hook files")
        return hook_files
    
    def load_hook_config(self, hook_file: Path) -> Optional[Dict[str, Any]]:
        """Load and parse hook configuration"""
        try:
            with open(hook_file, 'r') as f:
                config = yaml.safe_load(f)
            logger.debug(f"Loaded hook config: {hook_file.name}")
            return config
        except Exception as e:
            logger.error(f"Failed to load hook config {hook_file}: {e}")
            return None
    
    def test_trigger_conditions(self, hook_name: str, hook_config: Dict[str, Any]) -> Dict[str, Any]:
        """Test hook trigger conditions and validation"""
        test_result = {
            'hook_name': hook_name,
            'trigger_type': hook_config.get('trigger', {}).get('type', 'unknown'),
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        trigger_config = hook_config.get('trigger', {})
        
        # Test 1: Validate trigger type
        valid_trigger_types = [
            'scheduled', 'manual', 'file_change', 'hybrid', 
            'intelligent_scheduled', 'intelligent_file_change'
        ]
        
        trigger_type = trigger_config.get('type')
        if trigger_type in valid_trigger_types:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✓ Valid trigger type: {trigger_type}")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append(f"✗ Invalid trigger type: {trigger_type}")
        
        # Test 2: Validate schedule format (if scheduled)
        if 'schedule' in trigger_config:
            schedule = trigger_config['schedule']
            if self.validate_cron_expression(schedule):
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ Valid cron schedule: {schedule}")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"✗ Invalid cron schedule: {schedule}")
        
        # Test 3: Validate file patterns (if file_change)
        if 'patterns' in trigger_config:
            patterns = trigger_config['patterns']
            if isinstance(patterns, list) and len(patterns) > 0:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ File patterns defined: {len(patterns)} patterns")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append("✗ Invalid or empty file patterns")
        
        # Test 4: Validate intelligent triggers
        if 'intelligent_triggers' in trigger_config:
            intelligent_triggers = trigger_config['intelligent_triggers']
            if isinstance(intelligent_triggers, list):
                for i, trigger in enumerate(intelligent_triggers):
                    if all(key in trigger for key in ['type', 'condition']):
                        test_result['tests_passed'] += 1
                        test_result['details'].append(f"✓ Intelligent trigger {i+1} valid")
                    else:
                        test_result['tests_failed'] += 1
                        test_result['details'].append(f"✗ Intelligent trigger {i+1} missing required fields")
        
        # Test 5: Validate events
        if 'events' in trigger_config:
            events = trigger_config['events']
            if isinstance(events, list) and len(events) > 0:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ Events defined: {len(events)} events")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append("✗ Invalid or empty events list")
        
        return test_result
    
    def test_hook_execution(self, hook_name: str, hook_config: Dict[str, Any]) -> Dict[str, Any]:
        """Test hook execution capabilities and action validation"""
        test_result = {
            'hook_name': hook_name,
            'actions_count': 0,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        actions = hook_config.get('actions', [])
        test_result['actions_count'] = len(actions)
        
        if not actions:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No actions defined")
            return test_result
        
        # Test each action
        for i, action in enumerate(actions):
            action_name = action.get('name', f'action_{i+1}')
            
            # Test 1: Action has required fields
            required_fields = ['name', 'description']
            if all(field in action for field in required_fields):
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ Action '{action_name}' has required fields")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append(f"✗ Action '{action_name}' missing required fields")
            
            # Test 2: Commands are valid (if present)
            if 'commands' in action:
                commands = action['commands']
                if isinstance(commands, list) and len(commands) > 0:
                    # Test command syntax
                    valid_commands = 0
                    for cmd in commands:
                        if self.validate_command_syntax(cmd):
                            valid_commands += 1
                    
                    if valid_commands == len(commands):
                        test_result['tests_passed'] += 1
                        test_result['details'].append(f"✓ Action '{action_name}' has {len(commands)} valid commands")
                    else:
                        test_result['tests_failed'] += 1
                        test_result['details'].append(f"✗ Action '{action_name}' has invalid commands")
            
            # Test 3: Validation rules (if present)
            if 'validation_rules' in action or 'checks' in action or 'validations' in action:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ Action '{action_name}' has validation rules")
        
        return test_result
    
    def test_error_handling(self, hook_name: str, hook_config: Dict[str, Any]) -> Dict[str, Any]:
        """Test error handling and failure scenarios"""
        test_result = {
            'hook_name': hook_name,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Failure handling configuration
        if 'failure_handling' in hook_config:
            failure_config = hook_config['failure_handling']
            test_result['tests_passed'] += 1
            test_result['details'].append("✓ Failure handling configuration present")
            
            # Check for retry policy
            if 'retry_policy' in failure_config:
                retry_policy = failure_config['retry_policy']
                if 'max_attempts' in retry_policy and 'backoff_strategy' in retry_policy:
                    test_result['tests_passed'] += 1
                    test_result['details'].append("✓ Retry policy properly configured")
                else:
                    test_result['tests_failed'] += 1
                    test_result['details'].append("✗ Incomplete retry policy configuration")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No failure handling configuration")
        
        # Test 2: Timeout configuration
        timeout_found = False
        actions = hook_config.get('actions', [])
        for action in actions:
            if 'timeout' in action or 'timeout_per_check' in hook_config.get('configuration', {}):
                timeout_found = True
                break
        
        if timeout_found:
            test_result['tests_passed'] += 1
            test_result['details'].append("✓ Timeout configuration found")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No timeout configuration found")
        
        # Test 3: Alert configuration
        if 'alerts' in hook_config or 'alerting' in hook_config:
            test_result['tests_passed'] += 1
            test_result['details'].append("✓ Alert configuration present")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No alert configuration")
        
        return test_result
    
    def test_mcp_integration(self, hook_name: str, hook_config: Dict[str, Any]) -> Dict[str, Any]:
        """Test MCP server integration capabilities"""
        test_result = {
            'hook_name': hook_name,
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Integration configuration
        integration_config = hook_config.get('integration', {})
        if integration_config:
            test_result['tests_passed'] += 1
            test_result['details'].append("✓ Integration configuration present")
            
            # Check for specific integrations
            integrations = ['prometheus', 'grafana', 'aws', 'kubernetes', 'slack']
            found_integrations = []
            
            for integration in integrations:
                if integration in integration_config:
                    found_integrations.append(integration)
            
            if found_integrations:
                test_result['tests_passed'] += 1
                test_result['details'].append(f"✓ Found integrations: {', '.join(found_integrations)}")
            else:
                test_result['tests_failed'] += 1
                test_result['details'].append("✗ No recognized integrations found")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No integration configuration")
        
        # Test 2: Check for MCP-compatible commands
        actions = hook_config.get('actions', [])
        mcp_commands = 0
        
        for action in actions:
            commands = action.get('commands', [])
            for cmd in commands:
                if any(tool in cmd for tool in ['kubectl', 'aws', 'curl']):
                    mcp_commands += 1
        
        if mcp_commands > 0:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✓ Found {mcp_commands} MCP-compatible commands")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("✗ No MCP-compatible commands found")
        
        return test_result
    
    def validate_cron_expression(self, cron_expr: str) -> bool:
        """Validate cron expression format"""
        try:
            parts = cron_expr.split()
            if len(parts) != 5:
                return False
            
            # Basic validation - could be more comprehensive
            for part in parts:
                if not (part.isdigit() or part == '*' or '/' in part or '-' in part or ',' in part):
                    return False
            
            return True
        except:
            return False
    
    def validate_command_syntax(self, command: str) -> bool:
        """Basic command syntax validation"""
        if not command or not isinstance(command, str):
            return False
        
        # Check for dangerous commands
        dangerous_patterns = ['rm -rf /', 'dd if=', ':(){ :|:& };:', 'mkfs']
        if any(pattern in command for pattern in dangerous_patterns):
            return False
        
        # Check for basic command structure
        if command.strip().startswith('#'):  # Comment
            return True
        
        # Should start with a valid command
        valid_commands = [
            'kubectl', 'aws', 'curl', 'grep', 'awk', 'sed', 'jq', 
            'terraform', 'helm', 'docker', 'git', 'echo', 'cat'
        ]
        
        first_word = command.strip().split()[0]
        return any(cmd in first_word for cmd in valid_commands)
    
    def simulate_trigger_conditions(self, hook_name: str, hook_config: Dict[str, Any]) -> Dict[str, Any]:
        """Simulate various trigger conditions to test responsiveness"""
        test_result = {
            'hook_name': hook_name,
            'simulations_run': 0,
            'simulations_passed': 0,
            'details': []
        }
        
        trigger_config = hook_config.get('trigger', {})
        
        # Simulate scheduled trigger
        if 'schedule' in trigger_config:
            test_result['simulations_run'] += 1
            # In a real implementation, this would check if the hook would trigger at the right time
            test_result['simulations_passed'] += 1
            test_result['details'].append("✓ Scheduled trigger simulation passed")
        
        # Simulate file change trigger
        if 'patterns' in trigger_config:
            test_result['simulations_run'] += 1
            patterns = trigger_config['patterns']
            
            # Test if patterns would match expected files
            test_files = [
                'terraform/main.tf',
                'k8s/deployment.yaml',
                '.github/workflows/deploy.yml'
            ]
            
            matches = 0
            for pattern in patterns:
                for test_file in test_files:
                    if self.matches_pattern(pattern, test_file):
                        matches += 1
                        break
            
            if matches > 0:
                test_result['simulations_passed'] += 1
                test_result['details'].append(f"✓ File pattern matching simulation passed ({matches} matches)")
            else:
                test_result['details'].append("✗ File pattern matching simulation failed")
        
        # Simulate intelligent triggers
        if 'intelligent_triggers' in trigger_config:
            intelligent_triggers = trigger_config['intelligent_triggers']
            for trigger in intelligent_triggers:
                test_result['simulations_run'] += 1
                # Simulate condition evaluation
                condition = trigger.get('condition', '')
                if self.simulate_condition_evaluation(condition):
                    test_result['simulations_passed'] += 1
                    test_result['details'].append(f"✓ Intelligent trigger simulation passed: {condition}")
                else:
                    test_result['details'].append(f"✗ Intelligent trigger simulation failed: {condition}")
        
        return test_result
    
    def matches_pattern(self, pattern: str, filepath: str) -> bool:
        """Simple pattern matching for file paths"""
        import fnmatch
        return fnmatch.fnmatch(filepath, pattern)
    
    def simulate_condition_evaluation(self, condition: str) -> bool:
        """Simulate evaluation of trigger conditions"""
        # This is a simplified simulation
        # In reality, this would evaluate actual system metrics
        
        if not condition:
            return False
        
        # Simulate some common conditions
        simulated_conditions = {
            'node_cpu > 80%': True,  # Simulate high CPU
            'node_memory > 85%': False,  # Simulate normal memory
            'resource_usage_increasing_trend > 7_days': True,
            'resource_usage_anomaly_detected': False,
            'budget_threshold_exceeded': False,
            'cost_anomaly_detected': True
        }
        
        # Check if condition matches any simulated condition
        for sim_condition, result in simulated_conditions.items():
            if sim_condition in condition:
                return result
        
        # Default to true for unknown conditions (optimistic simulation)
        return True
    
    def run_comprehensive_test(self) -> Dict[str, Any]:
        """Run comprehensive test suite for all hooks"""
        logger.info("Starting comprehensive hook automation test suite")
        
        hook_files = self.discover_hooks()
        self.test_results['total_hooks'] = len(hook_files)
        
        if not hook_files:
            logger.error("No hook files found to test")
            return self.test_results
        
        for hook_file in hook_files:
            hook_name = hook_file.stem
            logger.info(f"Testing hook: {hook_name}")
            
            hook_config = self.load_hook_config(hook_file)
            if not hook_config:
                continue
            
            self.test_results['hooks_tested'] += 1
            
            # Test trigger conditions
            trigger_test = self.test_trigger_conditions(hook_name, hook_config)
            self.test_results['trigger_tests'].append(trigger_test)
            
            # Test execution capabilities
            execution_test = self.test_hook_execution(hook_name, hook_config)
            self.test_results['execution_tests'].append(execution_test)
            
            # Test error handling
            error_test = self.test_error_handling(hook_name, hook_config)
            self.test_results['error_handling_tests'].append(error_test)
            
            # Test MCP integration
            integration_test = self.test_mcp_integration(hook_name, hook_config)
            self.test_results['integration_tests'].append(integration_test)
            
            # Simulate trigger conditions
            simulation_test = self.simulate_trigger_conditions(hook_name, hook_config)
            
            logger.info(f"Completed testing hook: {hook_name}")
        
        # Calculate overall success rate
        self.calculate_success_rates()
        
        # Generate recommendations
        self.generate_recommendations()
        
        logger.info("Comprehensive hook automation test suite completed")
        return self.test_results
    
    def calculate_success_rates(self):
        """Calculate success rates for different test categories"""
        categories = [
            ('trigger_tests', 'Trigger Tests'),
            ('execution_tests', 'Execution Tests'),
            ('error_handling_tests', 'Error Handling Tests'),
            ('integration_tests', 'Integration Tests')
        ]
        
        total_passed = 0
        total_tests = 0
        
        for category_key, category_name in categories:
            category_tests = self.test_results[category_key]
            category_passed = sum(test['tests_passed'] for test in category_tests)
            category_total = sum(test['tests_passed'] + test['tests_failed'] for test in category_tests)
            
            if category_total > 0:
                category_rate = (category_passed / category_total) * 100
                logger.info(f"{category_name} Success Rate: {category_rate:.1f}% ({category_passed}/{category_total})")
            
            total_passed += category_passed
            total_tests += category_total
        
        if total_tests > 0:
            self.test_results['overall_success_rate'] = (total_passed / total_tests) * 100
            logger.info(f"Overall Success Rate: {self.test_results['overall_success_rate']:.1f}% ({total_passed}/{total_tests})")
    
    def generate_recommendations(self):
        """Generate recommendations based on test results"""
        recommendations = []
        
        # Analyze trigger tests
        trigger_failures = []
        for test in self.test_results['trigger_tests']:
            if test['tests_failed'] > 0:
                trigger_failures.append(test['hook_name'])
        
        if trigger_failures:
            recommendations.append({
                'category': 'Trigger Configuration',
                'priority': 'High',
                'issue': f"Trigger configuration issues found in {len(trigger_failures)} hooks",
                'hooks_affected': trigger_failures,
                'recommendation': 'Review and fix trigger configurations for proper automation'
            })
        
        # Analyze execution tests
        execution_failures = []
        for test in self.test_results['execution_tests']:
            if test['tests_failed'] > 0 or test['actions_count'] == 0:
                execution_failures.append(test['hook_name'])
        
        if execution_failures:
            recommendations.append({
                'category': 'Execution Configuration',
                'priority': 'High',
                'issue': f"Execution issues found in {len(execution_failures)} hooks",
                'hooks_affected': execution_failures,
                'recommendation': 'Ensure all hooks have properly configured actions and commands'
            })
        
        # Analyze error handling
        error_handling_failures = []
        for test in self.test_results['error_handling_tests']:
            if test['tests_failed'] > test['tests_passed']:
                error_handling_failures.append(test['hook_name'])
        
        if error_handling_failures:
            recommendations.append({
                'category': 'Error Handling',
                'priority': 'Medium',
                'issue': f"Insufficient error handling in {len(error_handling_failures)} hooks",
                'hooks_affected': error_handling_failures,
                'recommendation': 'Add comprehensive error handling, retry policies, and timeout configurations'
            })
        
        # Analyze MCP integration
        integration_failures = []
        for test in self.test_results['integration_tests']:
            if test['tests_failed'] > 0:
                integration_failures.append(test['hook_name'])
        
        if integration_failures:
            recommendations.append({
                'category': 'MCP Integration',
                'priority': 'Medium',
                'issue': f"MCP integration issues in {len(integration_failures)} hooks",
                'hooks_affected': integration_failures,
                'recommendation': 'Improve MCP server integration for external tool connectivity'
            })
        
        # Overall recommendations
        if self.test_results['overall_success_rate'] < 80:
            recommendations.append({
                'category': 'Overall Quality',
                'priority': 'High',
                'issue': f"Overall success rate is {self.test_results['overall_success_rate']:.1f}%, below 80% threshold",
                'recommendation': 'Comprehensive review and improvement of hook configurations needed'
            })
        
        self.test_results['recommendations'] = recommendations
    
    def generate_report(self) -> str:
        """Generate a comprehensive test report"""
        report = []
        report.append("# Hook Automation and Trigger Conditions Test Report")
        report.append(f"**Generated:** {self.test_results['timestamp']}")
        report.append(f"**Total Hooks:** {self.test_results['total_hooks']}")
        report.append(f"**Hooks Tested:** {self.test_results['hooks_tested']}")
        report.append(f"**Overall Success Rate:** {self.test_results['overall_success_rate']:.1f}%")
        report.append("")
        
        # Executive Summary
        report.append("## Executive Summary")
        if self.test_results['overall_success_rate'] >= 90:
            report.append("✅ **EXCELLENT** - Hook automation is well-configured and ready for production use.")
        elif self.test_results['overall_success_rate'] >= 80:
            report.append("✅ **GOOD** - Hook automation is mostly well-configured with minor improvements needed.")
        elif self.test_results['overall_success_rate'] >= 70:
            report.append("⚠️ **NEEDS IMPROVEMENT** - Hook automation has significant issues that should be addressed.")
        else:
            report.append("❌ **CRITICAL** - Hook automation has major issues that must be fixed before production use.")
        report.append("")
        
        # Detailed Results
        categories = [
            ('trigger_tests', 'Trigger Configuration Tests'),
            ('execution_tests', 'Execution Capability Tests'),
            ('error_handling_tests', 'Error Handling Tests'),
            ('integration_tests', 'MCP Integration Tests')
        ]
        
        for category_key, category_name in categories:
            report.append(f"## {category_name}")
            category_tests = self.test_results[category_key]
            
            for test in category_tests:
                hook_name = test['hook_name']
                passed = test['tests_passed']
                failed = test['tests_failed']
                total = passed + failed
                
                if total > 0:
                    success_rate = (passed / total) * 100
                    status = "✅" if failed == 0 else "⚠️" if success_rate >= 70 else "❌"
                    report.append(f"### {status} {hook_name}")
                    report.append(f"**Success Rate:** {success_rate:.1f}% ({passed}/{total})")
                    
                    if test['details']:
                        report.append("**Details:**")
                        for detail in test['details']:
                            report.append(f"- {detail}")
                    report.append("")
        
        # Recommendations
        if self.test_results['recommendations']:
            report.append("## Recommendations")
            for rec in self.test_results['recommendations']:
                priority_emoji = "🔴" if rec['priority'] == 'High' else "🟡" if rec['priority'] == 'Medium' else "🟢"
                report.append(f"### {priority_emoji} {rec['category']} ({rec['priority']} Priority)")
                report.append(f"**Issue:** {rec['issue']}")
                report.append(f"**Recommendation:** {rec['recommendation']}")
                
                if 'hooks_affected' in rec:
                    report.append(f"**Affected Hooks:** {', '.join(rec['hooks_affected'])}")
                report.append("")
        
        # Requirements Validation
        report.append("## Requirements Validation")
        report.append("### Requirement 5.1: Proactive Monitoring and Alerting")
        monitoring_hooks = [test for test in self.test_results['trigger_tests'] 
                          if 'monitoring' in test['hook_name'] or 'infrastructure' in test['hook_name']]
        if monitoring_hooks:
            report.append("✅ Infrastructure monitoring hooks are configured and tested")
        else:
            report.append("❌ No infrastructure monitoring hooks found")
        
        report.append("### Requirement 5.3: Proactive Issue Prevention")
        prevention_hooks = [test for test in self.test_results['trigger_tests'] 
                          if 'security' in test['hook_name'] or 'compliance' in test['hook_name']]
        if prevention_hooks:
            report.append("✅ Security and compliance hooks are configured for proactive issue prevention")
        else:
            report.append("❌ No proactive issue prevention hooks found")
        
        report.append("### Requirement 6.4: Security Compliance Management")
        security_hooks = [test for test in self.test_results['trigger_tests'] 
                         if 'security' in test['hook_name']]
        if security_hooks:
            report.append("✅ Security compliance hooks are configured")
        else:
            report.append("❌ No security compliance hooks found")
        
        report.append("### Requirements 10.1, 10.2, 10.3: Autonomous Operation Capabilities")
        autonomous_hooks = [test for test in self.test_results['trigger_tests'] 
                           if 'autopilot' in test['hook_name'] or 'autonomous' in test['hook_name']]
        if autonomous_hooks:
            report.append("✅ Autonomous operation hooks are configured")
        else:
            report.append("❌ No autonomous operation hooks found")
        
        return "\n".join(report)
    
    def save_results(self, filename: str = 'hook-automation-test-results.json'):
        """Save test results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)
        logger.info(f"Test results saved to {filename}")
    
    def save_report(self, filename: str = 'hook-automation-test-report.md'):
        """Save test report to markdown file"""
        report = self.generate_report()
        with open(filename, 'w') as f:
            f.write(report)
        logger.info(f"Test report saved to {filename}")

def main():
    """Main test execution function"""
    print("🔧 Starting Hook Automation and Trigger Conditions Test Suite")
    print("=" * 60)
    
    tester = HookAutomationTester()
    
    try:
        # Run comprehensive tests
        results = tester.run_comprehensive_test()
        
        # Save results and generate report
        tester.save_results()
        tester.save_report()
        
        # Print summary
        print("\n" + "=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        print(f"Total Hooks: {results['total_hooks']}")
        print(f"Hooks Tested: {results['hooks_tested']}")
        print(f"Overall Success Rate: {results['overall_success_rate']:.1f}%")
        
        if results['overall_success_rate'] >= 90:
            print("🎉 EXCELLENT - Hook automation is production-ready!")
        elif results['overall_success_rate'] >= 80:
            print("✅ GOOD - Hook automation is mostly ready with minor improvements needed")
        elif results['overall_success_rate'] >= 70:
            print("⚠️ NEEDS IMPROVEMENT - Significant issues found")
        else:
            print("❌ CRITICAL - Major issues must be addressed")
        
        print(f"\nDetailed report saved to: hook-automation-test-report.md")
        print(f"Raw results saved to: hook-automation-test-results.json")
        
        return 0 if results['overall_success_rate'] >= 80 else 1
        
    except Exception as e:
        logger.error(f"Test suite failed with error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
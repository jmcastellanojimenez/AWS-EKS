#!/usr/bin/env python3
"""
Autonomous Operation Boundaries and Safety Controls Test Suite
Tests autonomous operation limits, escalation procedures, safety controls, and mode transitions
"""

import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional

class AutonomousOperationTester:
    """Test suite for autonomous operation boundaries and safety controls"""
    
    def __init__(self):
        self.hooks_dir = Path('.kiro/hooks')
        self.settings_dir = Path('.kiro/settings')
        self.steering_dir = Path('.kiro/steering')
        self.test_results = {
            'timestamp': datetime.now().isoformat(),
            'boundary_tests': [],
            'safety_control_tests': [],
            'escalation_tests': [],
            'mode_transition_tests': [],
            'overall_success_rate': 0.0,
            'recommendations': []
        }
        
    def test_operation_boundaries(self) -> Dict[str, Any]:
        """Test autonomous operation boundaries and limits"""
        test_result = {
            'category': 'Operation Boundaries',
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Resource allocation limits
        resource_limits = self.check_resource_limits()
        if resource_limits['compliant']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Resource allocation limits properly defined")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Resource allocation limits missing or inadequate")
        
        # Test 2: Operational frequency limits
        frequency_limits = self.check_frequency_limits()
        if frequency_limits['compliant']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Operational frequency limits configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Operational frequency limits not configured")
        
        # Test 3: Geographic and environmental boundaries
        geo_boundaries = self.check_geographic_boundaries()
        if geo_boundaries['compliant']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Geographic and environmental boundaries defined")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Geographic and environmental boundaries missing")
        
        # Test 4: Cost control limits
        cost_limits = self.check_cost_limits()
        if cost_limits['compliant']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Cost control limits configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Cost control limits not configured")
        
        return test_result
    
    def test_safety_controls(self) -> Dict[str, Any]:
        """Test safety controls and protective measures"""
        test_result = {
            'category': 'Safety Controls',
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Circuit breaker mechanisms
        circuit_breakers = self.check_circuit_breakers()
        if circuit_breakers['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Circuit breaker mechanisms configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Circuit breaker mechanisms not configured")
        
        # Test 2: Resource protection safeguards
        resource_protection = self.check_resource_protection()
        if resource_protection['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Resource protection safeguards in place")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Resource protection safeguards missing")
        
        # Test 3: Data integrity protection
        data_protection = self.check_data_protection()
        if data_protection['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Data integrity protection configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Data integrity protection missing")
        
        # Test 4: Human oversight mechanisms
        human_oversight = self.check_human_oversight()
        if human_oversight['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Human oversight mechanisms configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Human oversight mechanisms missing")
        
        return test_result
    
    def test_escalation_procedures(self) -> Dict[str, Any]:
        """Test escalation procedures and triggers"""
        test_result = {
            'category': 'Escalation Procedures',
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Escalation triggers
        escalation_triggers = self.check_escalation_triggers()
        if escalation_triggers['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append(f"✅ Escalation triggers configured ({escalation_triggers['count']} triggers)")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Escalation triggers not configured")
        
        # Test 2: Escalation response procedures
        response_procedures = self.check_response_procedures()
        if response_procedures['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Escalation response procedures defined")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Escalation response procedures missing")
        
        # Test 3: Emergency override procedures
        override_procedures = self.check_override_procedures()
        if override_procedures['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Emergency override procedures configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Emergency override procedures missing")
        
        return test_result
    
    def test_mode_transitions(self) -> Dict[str, Any]:
        """Test supervised vs autopilot mode transitions"""
        test_result = {
            'category': 'Mode Transitions',
            'tests_passed': 0,
            'tests_failed': 0,
            'details': []
        }
        
        # Test 1: Autopilot to supervised transition criteria
        autopilot_to_supervised = self.check_autopilot_to_supervised_criteria()
        if autopilot_to_supervised['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Autopilot to supervised transition criteria defined")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Autopilot to supervised transition criteria missing")
        
        # Test 2: Supervised to autopilot transition criteria
        supervised_to_autopilot = self.check_supervised_to_autopilot_criteria()
        if supervised_to_autopilot['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Supervised to autopilot transition criteria defined")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Supervised to autopilot transition criteria missing")
        
        # Test 3: Hybrid mode operations
        hybrid_mode = self.check_hybrid_mode_operations()
        if hybrid_mode['configured']:
            test_result['tests_passed'] += 1
            test_result['details'].append("✅ Hybrid mode operations configured")
        else:
            test_result['tests_failed'] += 1
            test_result['details'].append("❌ Hybrid mode operations not configured")
        
        return test_result
    
    def check_resource_limits(self) -> Dict[str, Any]:
        """Check if resource allocation limits are properly defined"""
        # Look for resource limits in hook configurations
        resource_limits_found = False
        limit_types = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for various resource limit patterns
                    if re.search(r'max.*replicas|maximum.*pods|cpu.*limit|memory.*limit', content, re.IGNORECASE):
                        resource_limits_found = True
                        limit_types.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'compliant': resource_limits_found,
            'limit_types': limit_types,
            'count': len(limit_types)
        }
    
    def check_frequency_limits(self) -> Dict[str, Any]:
        """Check if operational frequency limits are configured"""
        frequency_limits_found = False
        frequency_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for frequency limit patterns
                    if re.search(r'max.*per.*hour|frequency|rate.*limit|operations.*per', content, re.IGNORECASE):
                        frequency_limits_found = True
                        frequency_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'compliant': frequency_limits_found,
            'configs': frequency_configs,
            'count': len(frequency_configs)
        }
    
    def check_geographic_boundaries(self) -> Dict[str, Any]:
        """Check if geographic and environmental boundaries are defined"""
        geo_boundaries_found = False
        boundary_configs = []
        
        # Check steering documents for environment-specific configurations
        if self.steering_dir.exists():
            for steering_file in self.steering_dir.glob('*.md'):
                try:
                    with open(steering_file, 'r') as f:
                        content = f.read()
                    
                    # Check for environment and region patterns
                    if re.search(r'environment|region|dev|staging|prod|us-east|us-west', content, re.IGNORECASE):
                        geo_boundaries_found = True
                        boundary_configs.append(steering_file.stem)
                        
                except Exception:
                    continue
        
        # Check MCP configurations for environment-specific settings
        if self.settings_dir.exists():
            for config_file in self.settings_dir.glob('mcp*.json'):
                try:
                    with open(config_file, 'r') as f:
                        content = f.read()
                    
                    if 'environment' in content.lower() or any(env in config_file.name for env in ['dev', 'staging', 'prod']):
                        geo_boundaries_found = True
                        boundary_configs.append(config_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'compliant': geo_boundaries_found,
            'configs': boundary_configs,
            'count': len(boundary_configs)
        }
    
    def check_cost_limits(self) -> Dict[str, Any]:
        """Check if cost control limits are configured"""
        cost_limits_found = False
        cost_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for cost-related patterns
                    if re.search(r'cost.*limit|budget|max.*cost|spending|price', content, re.IGNORECASE):
                        cost_limits_found = True
                        cost_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'compliant': cost_limits_found,
            'configs': cost_configs,
            'count': len(cost_configs)
        }
    
    def check_circuit_breakers(self) -> Dict[str, Any]:
        """Check if circuit breaker mechanisms are configured"""
        circuit_breakers_found = False
        breaker_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for circuit breaker patterns
                    if re.search(r'circuit.*breaker|fallback|retry|timeout|failure.*handling', content, re.IGNORECASE):
                        circuit_breakers_found = True
                        breaker_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': circuit_breakers_found,
            'configs': breaker_configs,
            'count': len(breaker_configs)
        }
    
    def check_resource_protection(self) -> Dict[str, Any]:
        """Check if resource protection safeguards are in place"""
        protection_found = False
        protection_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for resource protection patterns
                    if re.search(r'resource.*protection|safeguard|threshold|utilization.*limit', content, re.IGNORECASE):
                        protection_found = True
                        protection_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': protection_found,
            'configs': protection_configs,
            'count': len(protection_configs)
        }
    
    def check_data_protection(self) -> Dict[str, Any]:
        """Check if data integrity protection is configured"""
        data_protection_found = False
        protection_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for data protection patterns
                    if re.search(r'data.*integrity|backup|snapshot|corruption|validation', content, re.IGNORECASE):
                        data_protection_found = True
                        protection_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': data_protection_found,
            'configs': protection_configs,
            'count': len(protection_configs)
        }
    
    def check_human_oversight(self) -> Dict[str, Any]:
        """Check if human oversight mechanisms are configured"""
        oversight_found = False
        oversight_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for human oversight patterns
                    if re.search(r'human.*oversight|approval.*required|manual.*intervention|escalat', content, re.IGNORECASE):
                        oversight_found = True
                        oversight_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': oversight_found,
            'configs': oversight_configs,
            'count': len(oversight_configs)
        }
    
    def check_escalation_triggers(self) -> Dict[str, Any]:
        """Check if escalation triggers are configured"""
        triggers_found = False
        trigger_configs = []
        trigger_count = 0
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for escalation trigger patterns
                    escalation_matches = re.findall(r'escalat.*trigger|critical.*alert|emergency|severity.*high', content, re.IGNORECASE)
                    if escalation_matches:
                        triggers_found = True
                        trigger_configs.append(hook_file.stem)
                        trigger_count += len(escalation_matches)
                        
                except Exception:
                    continue
        
        return {
            'configured': triggers_found,
            'configs': trigger_configs,
            'count': trigger_count
        }
    
    def check_response_procedures(self) -> Dict[str, Any]:
        """Check if escalation response procedures are defined"""
        procedures_found = False
        procedure_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for response procedure patterns
                    if re.search(r'response.*procedure|incident.*response|escalation.*action|notification', content, re.IGNORECASE):
                        procedures_found = True
                        procedure_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': procedures_found,
            'configs': procedure_configs,
            'count': len(procedure_configs)
        }
    
    def check_override_procedures(self) -> Dict[str, Any]:
        """Check if emergency override procedures are configured"""
        override_found = False
        override_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for override procedure patterns
                    if re.search(r'override|emergency.*stop|manual.*control|pause.*automation', content, re.IGNORECASE):
                        override_found = True
                        override_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': override_found,
            'configs': override_configs,
            'count': len(override_configs)
        }
    
    def check_autopilot_to_supervised_criteria(self) -> Dict[str, Any]:
        """Check autopilot to supervised transition criteria"""
        criteria_found = False
        criteria_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for transition criteria patterns
                    if re.search(r'autopilot.*supervised|mode.*transition|complexity.*threshold|risk.*threshold', content, re.IGNORECASE):
                        criteria_found = True
                        criteria_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': criteria_found,
            'configs': criteria_configs,
            'count': len(criteria_configs)
        }
    
    def check_supervised_to_autopilot_criteria(self) -> Dict[str, Any]:
        """Check supervised to autopilot transition criteria"""
        criteria_found = False
        criteria_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for transition criteria patterns
                    if re.search(r'supervised.*autopilot|stability.*requirement|success.*rate|performance.*requirement', content, re.IGNORECASE):
                        criteria_found = True
                        criteria_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': criteria_found,
            'configs': criteria_configs,
            'count': len(criteria_configs)
        }
    
    def check_hybrid_mode_operations(self) -> Dict[str, Any]:
        """Check if hybrid mode operations are configured"""
        hybrid_found = False
        hybrid_configs = []
        
        if self.hooks_dir.exists():
            for hook_file in self.hooks_dir.glob('*.yaml'):
                try:
                    with open(hook_file, 'r') as f:
                        content = f.read()
                    
                    # Check for hybrid mode patterns
                    if re.search(r'hybrid.*mode|collaborative.*scenario|human.*oversight|approval.*gate', content, re.IGNORECASE):
                        hybrid_found = True
                        hybrid_configs.append(hook_file.stem)
                        
                except Exception:
                    continue
        
        return {
            'configured': hybrid_found,
            'configs': hybrid_configs,
            'count': len(hybrid_configs)
        }
    
    def run_comprehensive_test(self) -> Dict[str, Any]:
        """Run comprehensive autonomous operation test suite"""
        print("🤖 Starting Autonomous Operation Boundaries and Safety Controls Test Suite")
        print("=" * 75)
        
        # Test operation boundaries
        print("\n🔒 Testing Operation Boundaries...")
        boundary_test = self.test_operation_boundaries()
        self.test_results['boundary_tests'].append(boundary_test)
        
        # Test safety controls
        print("🛡️ Testing Safety Controls...")
        safety_test = self.test_safety_controls()
        self.test_results['safety_control_tests'].append(safety_test)
        
        # Test escalation procedures
        print("🚨 Testing Escalation Procedures...")
        escalation_test = self.test_escalation_procedures()
        self.test_results['escalation_tests'].append(escalation_test)
        
        # Test mode transitions
        print("🔄 Testing Mode Transitions...")
        transition_test = self.test_mode_transitions()
        self.test_results['mode_transition_tests'].append(transition_test)
        
        # Calculate success rates
        self.calculate_success_rates()
        
        # Generate recommendations
        self.generate_recommendations()
        
        print("\n🎉 Autonomous Operation test suite completed")
        return self.test_results
    
    def calculate_success_rates(self):
        """Calculate success rates for different test categories"""
        all_tests = (
            self.test_results['boundary_tests'] +
            self.test_results['safety_control_tests'] +
            self.test_results['escalation_tests'] +
            self.test_results['mode_transition_tests']
        )
        
        total_passed = sum(test['tests_passed'] for test in all_tests)
        total_tests = sum(test['tests_passed'] + test['tests_failed'] for test in all_tests)
        
        if total_tests > 0:
            self.test_results['overall_success_rate'] = (total_passed / total_tests) * 100
            print(f"\n📊 Overall Success Rate: {self.test_results['overall_success_rate']:.1f}% ({total_passed}/{total_tests})")
        
        # Print category-specific rates
        categories = [
            (self.test_results['boundary_tests'], 'Operation Boundaries'),
            (self.test_results['safety_control_tests'], 'Safety Controls'),
            (self.test_results['escalation_tests'], 'Escalation Procedures'),
            (self.test_results['mode_transition_tests'], 'Mode Transitions')
        ]
        
        for tests, category_name in categories:
            if tests:
                test = tests[0]  # Each category has one test
                passed = test['tests_passed']
                failed = test['tests_failed']
                total = passed + failed
                if total > 0:
                    rate = (passed / total) * 100
                    print(f"📊 {category_name}: {rate:.1f}% ({passed}/{total})")
    
    def generate_recommendations(self):
        """Generate recommendations based on test results"""
        recommendations = []
        
        # Analyze all test results
        all_tests = (
            self.test_results['boundary_tests'] +
            self.test_results['safety_control_tests'] +
            self.test_results['escalation_tests'] +
            self.test_results['mode_transition_tests']
        )
        
        for test in all_tests:
            if test['tests_failed'] > 0:
                failed_details = [detail for detail in test['details'] if detail.startswith('❌')]
                if failed_details:
                    recommendations.append({
                        'category': test['category'],
                        'priority': 'High' if test['tests_failed'] > test['tests_passed'] else 'Medium',
                        'issues': failed_details,
                        'recommendation': f"Address missing configurations in {test['category'].lower()}"
                    })
        
        # Overall recommendation
        if self.test_results['overall_success_rate'] < 80:
            recommendations.append({
                'category': 'Overall System',
                'priority': 'Critical',
                'issues': [f"Overall success rate is {self.test_results['overall_success_rate']:.1f}%"],
                'recommendation': 'Comprehensive review and improvement of autonomous operation configurations needed'
            })
        
        self.test_results['recommendations'] = recommendations
    
    def generate_report(self) -> str:
        """Generate comprehensive test report"""
        report = []
        report.append("# Autonomous Operation Boundaries and Safety Controls Test Report")
        report.append(f"**Generated:** {self.test_results['timestamp']}")
        report.append(f"**Overall Success Rate:** {self.test_results['overall_success_rate']:.1f}%")
        report.append("")
        
        # Executive Summary
        report.append("## Executive Summary")
        if self.test_results['overall_success_rate'] >= 90:
            report.append("✅ **EXCELLENT** - Autonomous operations are well-configured with comprehensive safety controls.")
        elif self.test_results['overall_success_rate'] >= 80:
            report.append("✅ **GOOD** - Autonomous operations are mostly well-configured with minor improvements needed.")
        elif self.test_results['overall_success_rate'] >= 70:
            report.append("⚠️ **NEEDS IMPROVEMENT** - Autonomous operations have significant gaps in safety controls.")
        else:
            report.append("❌ **CRITICAL** - Autonomous operations lack essential safety controls and boundaries.")
        report.append("")
        
        # Requirements Validation
        report.append("## Requirements Validation")
        report.append("### Requirement 10.1: Autonomous Operation Capabilities")
        boundary_tests = self.test_results['boundary_tests']
        if boundary_tests and boundary_tests[0]['tests_passed'] > 0:
            report.append("✅ Autonomous operation boundaries are configured")
        else:
            report.append("❌ Autonomous operation boundaries are not properly configured")
        
        report.append("### Requirement 10.2: Safety Controls and Human Oversight")
        safety_tests = self.test_results['safety_control_tests']
        if safety_tests and safety_tests[0]['tests_passed'] > 0:
            report.append("✅ Safety controls and human oversight mechanisms are configured")
        else:
            report.append("❌ Safety controls and human oversight mechanisms are missing")
        
        report.append("### Requirement 10.3: Escalation Procedures")
        escalation_tests = self.test_results['escalation_tests']
        if escalation_tests and escalation_tests[0]['tests_passed'] > 0:
            report.append("✅ Escalation procedures are configured")
        else:
            report.append("❌ Escalation procedures are not properly configured")
        
        report.append("### Requirement 10.4: Mode Transitions")
        transition_tests = self.test_results['mode_transition_tests']
        if transition_tests and transition_tests[0]['tests_passed'] > 0:
            report.append("✅ Mode transition criteria are configured")
        else:
            report.append("❌ Mode transition criteria are missing")
        
        report.append("### Requirement 10.5: Emergency Override Capabilities")
        override_configured = any('override' in str(test['details']).lower() for test in escalation_tests) if escalation_tests else False
        if override_configured:
            report.append("✅ Emergency override capabilities are configured")
        else:
            report.append("❌ Emergency override capabilities are not configured")
        
        return "\n".join(report)
    
    def save_results(self, filename: str = 'autonomous-operations-test-results.json'):
        """Save test results to JSON file"""
        with open(filename, 'w') as f:
            json.dump(self.test_results, f, indent=2, default=str)
        print(f"💾 Test results saved to {filename}")
    
    def save_report(self, filename: str = 'autonomous-operations-test-report.md'):
        """Save test report to markdown file"""
        report = self.generate_report()
        with open(filename, 'w') as f:
            f.write(report)
        print(f"💾 Test report saved to {filename}")

def main():
    """Main test execution function"""
    print("🤖 Starting Autonomous Operation Boundaries and Safety Controls Test Suite")
    print("=" * 75)
    
    tester = AutonomousOperationTester()
    
    try:
        # Run comprehensive tests
        results = tester.run_comprehensive_test()
        
        # Save results and generate report
        tester.save_results()
        tester.save_report()
        
        # Print summary
        print("\n" + "=" * 75)
        print("📊 TEST SUMMARY")
        print("=" * 75)
        print(f"Overall Success Rate: {results['overall_success_rate']:.1f}%")
        
        if results['overall_success_rate'] >= 90:
            print("🎉 EXCELLENT - Autonomous operations are production-ready!")
        elif results['overall_success_rate'] >= 80:
            print("✅ GOOD - Autonomous operations are mostly ready with minor improvements needed")
        elif results['overall_success_rate'] >= 70:
            print("⚠️ NEEDS IMPROVEMENT - Significant safety control gaps found")
        else:
            print("❌ CRITICAL - Major safety control issues must be addressed")
        
        print(f"\nDetailed report saved to: autonomous-operations-test-report.md")
        print(f"Raw results saved to: autonomous-operations-test-results.json")
        
        return 0 if results['overall_success_rate'] >= 70 else 1
        
    except Exception as e:
        print(f"❌ Test suite failed with error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
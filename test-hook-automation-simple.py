#!/usr/bin/env python3
"""
Simplified Hook Automation and Trigger Conditions Test Suite
Tests hook configurations without external dependencies
"""

import os
import sys
import json
import re
from pathlib import Path
from datetime import datetime

def load_yaml_simple(file_path):
    """Simple YAML parser for basic hook files"""
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Extract key information using regex
        data = {}
        
        # Extract name
        name_match = re.search(r'^name:\s*["\']?([^"\'\n]+)["\']?', content, re.MULTILINE)
        if name_match:
            data['name'] = name_match.group(1).strip()
        
        # Extract trigger type
        trigger_match = re.search(r'trigger:\s*\n\s*type:\s*["\']?([^"\'\n]+)["\']?', content, re.MULTILINE)
        if trigger_match:
            data['trigger'] = {'type': trigger_match.group(1).strip()}
        
        # Check for schedule
        schedule_match = re.search(r'schedule:\s*["\']?([^"\'\n]+)["\']?', content, re.MULTILINE)
        if schedule_match:
            if 'trigger' not in data:
                data['trigger'] = {}
            data['trigger']['schedule'] = schedule_match.group(1).strip()
        
        # Check for patterns
        if 'patterns:' in content:
            data['trigger'] = data.get('trigger', {})
            data['trigger']['patterns'] = True
        
        # Check for actions
        actions_count = len(re.findall(r'- name:\s*["\']?([^"\'\n]+)["\']?', content))
        if actions_count > 0:
            data['actions'] = [{'name': f'action_{i}'} for i in range(actions_count)]
        
        # Check for integration
        if 'integration:' in content:
            data['integration'] = {}
            for integration in ['prometheus', 'grafana', 'aws', 'kubernetes', 'slack']:
                if f'{integration}:' in content:
                    data['integration'][integration] = True
        
        return data
    except Exception as e:
        print(f"Error loading {file_path}: {e}")
        return None

def test_hook_automation():
    """Test hook automation and trigger conditions"""
    print("🔧 Hook Automation and Trigger Conditions Test")
    print("=" * 50)
    
    hooks_dir = Path('.kiro/hooks')
    if not hooks_dir.exists():
        print("❌ Hooks directory not found!")
        return False
    
    hook_files = list(hooks_dir.glob('*.yaml'))
    print(f"📁 Found {len(hook_files)} hook files")
    
    results = {
        'total_hooks': len(hook_files),
        'hooks_tested': 0,
        'trigger_tests_passed': 0,
        'execution_tests_passed': 0,
        'integration_tests_passed': 0,
        'details': []
    }
    
    for hook_file in hook_files:
        hook_name = hook_file.stem
        print(f"\n🔍 Testing: {hook_name}")
        
        hook_data = load_yaml_simple(hook_file)
        if not hook_data:
            continue
        
        results['hooks_tested'] += 1
        hook_result = {'name': hook_name, 'tests': []}
        
        # Test 1: Trigger Configuration
        trigger_score = 0
        if 'trigger' in hook_data:
            trigger = hook_data['trigger']
            
            # Check trigger type
            if 'type' in trigger:
                valid_types = ['scheduled', 'manual', 'file_change', 'hybrid', 'intelligent_scheduled']
                if trigger['type'] in valid_types:
                    trigger_score += 1
                    hook_result['tests'].append(f"✅ Valid trigger type: {trigger['type']}")
                else:
                    hook_result['tests'].append(f"❌ Invalid trigger type: {trigger['type']}")
            
            # Check schedule format
            if 'schedule' in trigger:
                schedule = trigger['schedule']
                if re.match(r'^(\d+|\*)\s+(\d+|\*)\s+(\d+|\*)\s+(\d+|\*)\s+(\d+|\*)$', schedule):
                    trigger_score += 1
                    hook_result['tests'].append(f"✅ Valid cron schedule: {schedule}")
                else:
                    hook_result['tests'].append(f"❌ Invalid cron schedule: {schedule}")
            
            # Check for patterns (file change triggers)
            if 'patterns' in trigger:
                trigger_score += 1
                hook_result['tests'].append("✅ File patterns configured")
        
        if trigger_score > 0:
            results['trigger_tests_passed'] += 1
        
        # Test 2: Actions Configuration
        execution_score = 0
        if 'actions' in hook_data and len(hook_data['actions']) > 0:
            execution_score += 1
            hook_result['tests'].append(f"✅ {len(hook_data['actions'])} actions configured")
        else:
            hook_result['tests'].append("❌ No actions configured")
        
        if execution_score > 0:
            results['execution_tests_passed'] += 1
        
        # Test 3: Integration Configuration
        integration_score = 0
        if 'integration' in hook_data:
            integrations = list(hook_data['integration'].keys())
            if integrations:
                integration_score += 1
                hook_result['tests'].append(f"✅ Integrations: {', '.join(integrations)}")
            else:
                hook_result['tests'].append("❌ No integrations configured")
        else:
            hook_result['tests'].append("❌ No integration section found")
        
        if integration_score > 0:
            results['integration_tests_passed'] += 1
        
        results['details'].append(hook_result)
    
    # Calculate success rates
    if results['hooks_tested'] > 0:
        trigger_rate = (results['trigger_tests_passed'] / results['hooks_tested']) * 100
        execution_rate = (results['execution_tests_passed'] / results['hooks_tested']) * 100
        integration_rate = (results['integration_tests_passed'] / results['hooks_tested']) * 100
        overall_rate = (trigger_rate + execution_rate + integration_rate) / 3
    else:
        trigger_rate = execution_rate = integration_rate = overall_rate = 0
    
    # Print results
    print("\n" + "=" * 50)
    print("📊 TEST RESULTS")
    print("=" * 50)
    print(f"Total Hooks: {results['total_hooks']}")
    print(f"Hooks Tested: {results['hooks_tested']}")
    print(f"Trigger Tests Passed: {results['trigger_tests_passed']}/{results['hooks_tested']} ({trigger_rate:.1f}%)")
    print(f"Execution Tests Passed: {results['execution_tests_passed']}/{results['hooks_tested']} ({execution_rate:.1f}%)")
    print(f"Integration Tests Passed: {results['integration_tests_passed']}/{results['hooks_tested']} ({integration_rate:.1f}%)")
    print(f"Overall Success Rate: {overall_rate:.1f}%")
    
    # Detailed results
    print("\n📋 DETAILED RESULTS")
    print("-" * 30)
    for hook_result in results['details']:
        print(f"\n🔧 {hook_result['name']}:")
        for test in hook_result['tests']:
            print(f"  {test}")
    
    # Requirements validation
    print("\n✅ REQUIREMENTS VALIDATION")
    print("-" * 30)
    
    # Check for monitoring hooks (Requirement 5.1)
    monitoring_hooks = [h for h in results['details'] if 'monitoring' in h['name'] or 'infrastructure' in h['name']]
    if monitoring_hooks:
        print("✅ Requirement 5.1: Infrastructure monitoring hooks found")
    else:
        print("❌ Requirement 5.1: No infrastructure monitoring hooks found")
    
    # Check for security hooks (Requirement 6.4)
    security_hooks = [h for h in results['details'] if 'security' in h['name'] or 'compliance' in h['name']]
    if security_hooks:
        print("✅ Requirement 6.4: Security compliance hooks found")
    else:
        print("❌ Requirement 6.4: No security compliance hooks found")
    
    # Check for autonomous operation hooks (Requirements 10.1, 10.2, 10.3)
    autonomous_hooks = [h for h in results['details'] if 'autopilot' in h['name'] or 'autonomous' in h['name']]
    if autonomous_hooks:
        print("✅ Requirements 10.1-10.3: Autonomous operation hooks found")
    else:
        print("❌ Requirements 10.1-10.3: No autonomous operation hooks found")
    
    # Save results
    with open('hook-automation-test-results.json', 'w') as f:
        json.dump({
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_hooks': results['total_hooks'],
                'hooks_tested': results['hooks_tested'],
                'trigger_success_rate': trigger_rate,
                'execution_success_rate': execution_rate,
                'integration_success_rate': integration_rate,
                'overall_success_rate': overall_rate
            },
            'details': results['details']
        }, f, indent=2)
    
    print(f"\n💾 Results saved to: hook-automation-test-results.json")
    
    # Return success if overall rate is good
    return overall_rate >= 70

if __name__ == "__main__":
    success = test_hook_automation()
    sys.exit(0 if success else 1)
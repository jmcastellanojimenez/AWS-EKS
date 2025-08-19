#!/usr/bin/env python3
"""
Kiro Context Understanding Test Script

This script validates Kiro's understanding of platform architecture and workflows
by testing responses to key questions about the infrastructure platform.
"""

import json
import time
from datetime import datetime
from typing import Dict, List, Tuple

class KiroContextTest:
    def __init__(self):
        self.test_results = []
        self.start_time = datetime.now()
        
    def log_test_result(self, test_name: str, query: str, expected_keywords: List[str], 
                       response: str, passed: bool, notes: str = ""):
        """Log test result for analysis"""
        result = {
            "test_name": test_name,
            "query": query,
            "expected_keywords": expected_keywords,
            "response": response,
            "passed": passed,
            "notes": notes,
            "timestamp": datetime.now().isoformat()
        }
        self.test_results.append(result)
        
    def validate_response(self, response: str, expected_keywords: List[str]) -> Tuple[bool, List[str]]:
        """Validate response contains expected keywords"""
        response_lower = response.lower()
        missing_keywords = []
        
        for keyword in expected_keywords:
            if keyword.lower() not in response_lower:
                missing_keywords.append(keyword)
                
        passed = len(missing_keywords) == 0
        return passed, missing_keywords
    
    def test_workflow_dependencies(self) -> Dict:
        """Test 1.1: Workflow Dependencies and Deployment Sequence"""
        test_name = "Workflow Dependencies and Deployment Sequence"
        query = "What is the correct deployment sequence for all 7 infrastructure workflows and why?"
        
        expected_keywords = [
            "Foundation Platform",
            "Workflow 1",
            "Ingress",
            "Workflow 2", 
            "Observability",
            "Workflow 3",
            "parallel",
            "dependencies",
            "sequential"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        # In a real implementation, this would query Kiro
        # For now, we'll simulate the test structure
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed, 
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_resource_planning(self) -> Dict:
        """Test 1.2: Resource Planning and Allocation"""
        test_name = "Resource Planning and Allocation"
        query = "How should I plan resource allocation across all 7 workflows for a production environment?"
        
        expected_keywords = [
            "6-20 CPU cores",
            "24-80GB RAM",
            "spot instance",
            "80%",
            "auto-scaling",
            "microservices",
            "t3.large"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_cross_workflow_integration(self) -> Dict:
        """Test 1.3: Cross-Workflow Integration Points"""
        test_name = "Cross-Workflow Integration Points"
        query = "How do the 7 workflows integrate with each other, and what are the key integration points?"
        
        expected_keywords = [
            "shared VPC",
            "observability",
            "service mesh",
            "GitOps",
            "integration points",
            "monitoring",
            "Istio",
            "ArgoCD"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_dev_environment_config(self) -> Dict:
        """Test 2.1: Development Environment Configuration"""
        test_name = "Development Environment Configuration"
        query = "What are the specific configuration differences for the development environment?"
        
        expected_keywords = [
            "90% spot",
            "relaxed",
            "DEBUG",
            "aggressive",
            "development-hours scaling",
            "cost optimization"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_prod_environment_config(self) -> Dict:
        """Test 2.2: Production Environment Configuration"""
        test_name = "Production Environment Configuration"
        query = "What are the key differences in production environment configuration compared to development?"
        
        expected_keywords = [
            "50% spot",
            "conservative",
            "strict security",
            "high availability",
            "audit logging",
            "disaster recovery"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_ecotrack_architecture(self) -> Dict:
        """Test 3.1: EcoTrack Application Architecture"""
        test_name = "EcoTrack Application Architecture"
        query = "Describe the EcoTrack microservices architecture and how it integrates with the platform."
        
        expected_keywords = [
            "5 microservices",
            "user-service",
            "product-service",
            "order-service",
            "payment-service",
            "notification-service",
            "Spring Boot",
            "Actuator",
            "PostgreSQL",
            "Redis"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_service_mesh_integration(self) -> Dict:
        """Test 3.2: Service Mesh Integration"""
        test_name = "Service Mesh Integration"
        query = "How does the service mesh integrate with the EcoTrack microservices?"
        
        expected_keywords = [
            "Istio",
            "sidecar injection",
            "mTLS",
            "traffic management",
            "circuit breaking",
            "observability"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def test_cost_optimization(self) -> Dict:
        """Test 5.1: Spot Instance Management"""
        test_name = "Spot Instance Management"
        query = "How should I optimize spot instance usage for cost savings while maintaining reliability?"
        
        expected_keywords = [
            "diversified",
            "interruption handling",
            "60-70% savings",
            "mixed capacity",
            "multiple AZ",
            "pod disruption budgets"
        ]
        
        print(f"\n🧪 Testing: {test_name}")
        print(f"Query: {query}")
        print("Expected keywords:", ", ".join(expected_keywords))
        
        response = "PLACEHOLDER - This would be Kiro's actual response"
        
        passed, missing = self.validate_response(response, expected_keywords)
        self.log_test_result(test_name, query, expected_keywords, response, passed,
                           f"Missing keywords: {missing}" if missing else "All keywords found")
        
        return {"test": test_name, "passed": passed, "missing_keywords": missing}
    
    def run_all_tests(self) -> Dict:
        """Run all context understanding tests"""
        print("🚀 Starting Kiro Context Understanding Tests")
        print("=" * 60)
        
        test_methods = [
            self.test_workflow_dependencies,
            self.test_resource_planning,
            self.test_cross_workflow_integration,
            self.test_dev_environment_config,
            self.test_prod_environment_config,
            self.test_ecotrack_architecture,
            self.test_service_mesh_integration,
            self.test_cost_optimization
        ]
        
        results = []
        for test_method in test_methods:
            try:
                result = test_method()
                results.append(result)
                status = "✅ PASS" if result["passed"] else "❌ FAIL"
                print(f"Status: {status}")
                if not result["passed"]:
                    print(f"Missing keywords: {result['missing_keywords']}")
            except Exception as e:
                print(f"❌ ERROR: {str(e)}")
                results.append({"test": test_method.__name__, "passed": False, "error": str(e)})
        
        # Calculate summary statistics
        total_tests = len(results)
        passed_tests = sum(1 for r in results if r.get("passed", False))
        pass_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        
        summary = {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": total_tests - passed_tests,
            "pass_rate": pass_rate,
            "results": results,
            "execution_time": (datetime.now() - self.start_time).total_seconds()
        }
        
        print("\n" + "=" * 60)
        print("📊 TEST SUMMARY")
        print("=" * 60)
        print(f"Total Tests: {total_tests}")
        print(f"Passed: {passed_tests}")
        print(f"Failed: {total_tests - passed_tests}")
        print(f"Pass Rate: {pass_rate:.1f}%")
        print(f"Execution Time: {summary['execution_time']:.2f} seconds")
        
        return summary
    
    def generate_report(self, summary: Dict) -> str:
        """Generate detailed test report"""
        report = f"""
# Kiro Context Understanding Test Report

**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Execution Time**: {summary['execution_time']:.2f} seconds

## Summary
- **Total Tests**: {summary['total_tests']}
- **Passed**: {summary['passed_tests']}
- **Failed**: {summary['failed_tests']}
- **Pass Rate**: {summary['pass_rate']:.1f}%

## Test Results

"""
        
        for i, result in enumerate(summary['results'], 1):
            status = "✅ PASS" if result.get("passed", False) else "❌ FAIL"
            report += f"### {i}. {result['test']}\n"
            report += f"**Status**: {status}\n"
            
            if not result.get("passed", False) and "missing_keywords" in result:
                report += f"**Missing Keywords**: {', '.join(result['missing_keywords'])}\n"
            
            if "error" in result:
                report += f"**Error**: {result['error']}\n"
            
            report += "\n"
        
        report += """
## Recommendations

### For Failed Tests
1. Review and update relevant steering documents
2. Add missing information or clarify existing content
3. Ensure cross-document consistency
4. Re-run tests after updates

### For Continuous Improvement
1. Run tests weekly to validate steering document effectiveness
2. Add new tests based on operational experience
3. Update validation criteria as platform evolves
4. Monitor pass rates over time to track improvement

## Next Steps
1. Address any failed tests by updating steering documents
2. Validate fixes by re-running specific tests
3. Schedule regular testing to maintain context quality
4. Expand test coverage based on operational needs
"""
        
        return report

def main():
    """Main test execution function"""
    tester = KiroContextTest()
    
    print("Note: This is a test framework for validating Kiro's context understanding.")
    print("In a real implementation, this would query Kiro directly and validate responses.")
    print("Currently showing test structure and validation criteria.\n")
    
    # Run all tests
    summary = tester.run_all_tests()
    
    # Generate and save report
    report = tester.generate_report(summary)
    
    with open("kiro-context-test-report.md", "w") as f:
        f.write(report)
    
    print(f"\n📄 Detailed report saved to: kiro-context-test-report.md")
    
    # Save raw results as JSON
    with open("kiro-context-test-results.json", "w") as f:
        json.dump({
            "summary": summary,
            "test_results": tester.test_results
        }, f, indent=2)
    
    print(f"📊 Raw results saved to: kiro-context-test-results.json")
    
    return summary

if __name__ == "__main__":
    main()
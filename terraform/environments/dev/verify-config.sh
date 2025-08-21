#!/bin/bash

echo "🔍 LGTM Configuration Verification"
echo "=================================="

echo ""
echo "📋 Component Toggles in tfvars:"
grep -E "enable_(mimir|loki|tempo|prometheus|grafana)" terraform.tfvars | sort

echo ""
echo "📋 Default Values in Module Variables:"
grep -A2 -E "variable \"enable_(mimir|loki|tempo|prometheus|grafana)" ../../modules/lgtm-observability/variables.tf | grep -E "(variable|default)" 

echo ""
echo "📋 Terraform Plan Preview (LGTM resources only):"
terraform plan -target=module.lgtm_observability 2>/dev/null | grep -E "(helm_release\.|aws_s3_bucket\.)" | head -10

echo ""
echo "✅ Verification Complete"
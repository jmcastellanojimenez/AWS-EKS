#!/bin/bash
set -e

# Fix ALB Controller permissions by adding ACM access to node group role
# This is a temporary fix until the Terraform changes are applied

ENVIRONMENT="${1:-dev}"
ROLE_NAME="eks-learning-lab-${ENVIRONMENT}-eks-node-group-role"
POLICY_NAME="ALBControllerACMAccess"

echo "🔧 Adding ACM permissions to node group role: $ROLE_NAME"

# Create the policy document
POLICY_DOCUMENT='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "acm:ListCertificates",
        "acm:DescribeCertificate",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:DescribeTargetHealth"
      ],
      "Resource": "*"
    }
  ]
}'

# Check if policy already exists
if aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" >/dev/null 2>&1; then
    echo "✅ Policy $POLICY_NAME already exists on role $ROLE_NAME"
else
    echo "📝 Creating inline policy $POLICY_NAME on role $ROLE_NAME"
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "$POLICY_NAME" \
        --policy-document "$POLICY_DOCUMENT"
    echo "✅ Policy created successfully"
fi

# Restart ALB controller to pick up new permissions
echo "🔄 Restarting AWS Load Balancer Controller..."
kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system

echo "⏳ Waiting for ALB controller to be ready..."
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=300s

echo "✅ ALB Controller permissions fixed and restarted"
echo "🔍 You can now check the controller logs:"
echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20"
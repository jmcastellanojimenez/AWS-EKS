/**
 * 
 * Permissions
 * 
 * This module will allow the modification of permissions
 * 
 */

import { Fn } from "cdktf";
import { EksStack } from '../../main';
import { AwsProvider } from "../../../.gen/providers/aws/provider";
import { IamRole } from "../../../.gen/providers/aws/iam-role";
import { IamOpenidConnectProvider } from "../../../.gen/providers/aws/iam-openid-connect-provider";
import { IamRolePolicy } from "../../../.gen/providers/aws/iam-role-policy";
import { DataAwsRoute53Zone } from "../../../.gen/providers/aws/data-aws-route53-zone";
import { EksCluster } from "../../../.gen/modules/eks_cluster";

export class externalDNSRoleCreation {

  constructor(scope: EksStack, eksCluster: EksCluster, clusterName: string) {

    const networkingProvider = new AwsProvider(scope, "aws-networking", {
      alias: "networking",
      region: "eu-central-1",
      profile: "epo_networking"
    });

    const clusterOidc = eksCluster.oidcProviderOutput

    // Create Identity Provider for the new cluster on Networking account
    new IamOpenidConnectProvider(scope, `identity-provider-${clusterName}`, {
      provider: networkingProvider,
      url: `https://${clusterOidc}`,
      clientIdList: ["sts.amazonaws.com"]
    })

    // Obtain hosted zone
    let domain = ""
    if (clusterName.includes("np-")) {
      domain = "platform-staging.aws.internal.epo.org"
    } else if (clusterName.includes("np-")) {
      domain = "platform.aws.internal.epo.org"
    } else {
      domain = "platform-lab.aws.internal.epo.org"
    }

    // Obtain route53 hosted zones
    const domainInfo = new DataAwsRoute53Zone(scope, "selected", {
      provider: networkingProvider,
      name: domain,
      privateZone: true,
      dependsOn: [eksCluster]
    });

    // Define the new Role Trusted Policy statement
    const newStatement = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": `arn:aws:iam::733565320759:oidc-provider/${clusterOidc}`
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              [`${clusterOidc}:sub`]: "system:serviceaccount:external-dns-system:external-dns"
            }
          }
        }
      ]
    };

    // Define the new Role
    const route53Role = new IamRole(scope, "cross-account-external-dns-role", {
      provider: networkingProvider,
      assumeRolePolicy: JSON.stringify(newStatement),
      name: `EPOCrossAccountExternalDNSRole${clusterName}`,
      dependsOn: [eksCluster]
    });

    // Define the new role policy
    new IamRolePolicy(scope, "route53-access", {
      provider: networkingProvider,
      role: route53Role.id,
      policy: Fn.jsonencode({
        Version: "2012-10-17",
        Statement: [
          {
            Action: [
              "route53:ChangeResourceRecordSets",
              "route53:ListResourceRecordSets"
            ],
            Effect: "Allow",
            Resource: [domainInfo.arn]
          },
          {
            Action: [
              "route53:ListHostedZones",
            ],
            Effect: "Allow",
            Resource: "*"
          },
        ]
      })
    })
  }
}

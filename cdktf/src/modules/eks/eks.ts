/**
 * 
 * EKS
 * 
 * This module creates the EKS resource
 * 
 * Necessary variables
 * Cluster Name
 * Cluster Version
 * Project Name
 * environment
 * vpc ID
 * Subnet IDs
 * 
 */


import { EksStack } from "../../main";
import { EksCluster } from "../../../.gen/modules/eks_cluster";

export class eksCreation {
  private cluster: EksCluster;

  constructor(scope: EksStack, clusterName: string, clusterVersion: string, project: string, env: string, vpcId: string, subnetIds: string[]) {

    // Build the EKS cluster based on the variables provided
    this.cluster = new EksCluster(scope, clusterName, {
      authenticationMode: "API_AND_CONFIG_MAP",
      clusterName: clusterName,
      clusterVersion: clusterVersion,
      clusterEndpointPrivateAccess: true,
      clusterEndpointPublicAccess: false,
      enableClusterCreatorAdminPermissions: true,
      vpcId: vpcId,
      subnetIds: subnetIds,
      clusterSecurityGroupAdditionalRules: {
        ingress_epo_https_tcp: {
          description: "Allow inbound HTTPS from EPO",
          protocol: "tcp",
          from_port: 443,
          to_port: 443,
          type: "ingress",
          cidr_blocks: ["10.0.0.0/8"],
        },
      },
      tags: {
        environment: env,
        project: project,
      }
    });
  }

  // Returns the cluster resource
  public getCluster(): EksCluster {
    return this.cluster;
  }
}

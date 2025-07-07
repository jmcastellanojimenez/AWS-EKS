/**
 * 
 * EKS Nodegroups
 * 
 * This module create N nodegroups defined in the cluster configuration
 * 
 * Necessary variable:
 * 
 * Cluster Name
 * Cluster Version
 * Project Name
 * Subnet IDs
 * nodegroup - this is a list with all the nodegroups information
 * eksCluster - this is the eks terraform resource
 * installCilium - this is a boolean variable to install or not cilium
 * 
 */

import { Fn } from "cdktf";
import { EksStack } from "../../main";
import { nodegroupsConfig } from "../../main"
import { KeyPair } from "../../../.gen/providers/aws/key-pair"
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup"
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { getVaultSecret } from "../vault/vault"
import { GetVpcInfo } from "../vpc/vpcData"

export class eksNodegroupCreation {
    private nodeGroup!: EksNodegroup;

    public instanceTypeMap: Record<string, string> = {
        XS: "t3.small",
        S: "t3.medium",
        M: "m6a.2xlarge",
        L: "m6a.4xlarge",
        XL: "m6a.8xlarge",
        XXL: "m6a.16xlarge",
    };

    public maxNodeCapacityMap: Record<string, number> = {
        XS: 3,
        S: 7,
        M: 15,
        L: 31,
        XL: 63,
        XXL: 127,
    };

    constructor(scope: EksStack, clusterName: string, clusterVersion: string, projectName: string, subnetIds: string[], nodegroups: nodegroupsConfig[], eksCluster: EksCluster, vpcInfo: GetVpcInfo) {

        // Obtain the SSH keys for the nodes
        const secret = new getVaultSecret(scope, "idrsa", "secret/all-clusters/kube-system/ssh")
        const publicKey = Fn.lookup(secret.getSecret().data, "id_rsa.pub", "");

        // Set the keypairs on AWS
        const keyPair = new KeyPair(scope, `ssh-keypair-${clusterName}`, {
            keyName: `ssh-keypair-${clusterName}`,
            publicKey: publicKey,
        });

        for (let i = 0; i < nodegroups.length; i++) {
            const nodegroup = nodegroups[i];

            const instanceTypes: string[] = [];
            const instanceType = nodegroup.instanceType
                ? instanceTypes.concat(
                    Array.isArray(nodegroup.instanceType)
                        ? nodegroup.instanceType
                        : [nodegroup.instanceType]
                )
                : [this.instanceTypeMap[nodegroup.nodeSize]];
            //const instanceType = this.instanceTypeMap[nodegroup.nodeSize] ?? "m6a.xlarge";

            const maxNodeCapacity = this.maxNodeCapacityMap[nodegroup.nodeSize] ?? 4;

            const preBootstrapUserData = `#!/bin/bash
            set -ex
            cat <<-EOF > /etc/profile.d/bootstrap.sh
            export CONTAINER_RUNTIME="containerd"
            export USE_MAX_PODS=false
            export KUBELET_EXTRA_ARGS="--max-pods=110"
            EOF
            # Source extra environment variables in bootstrap script
            sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
            `;

            const taints: { [key: string]: any } = {}

            // Create the nodegroup
            this.nodeGroup = new EksNodegroup(scope, `nodegroup-${projectName}-${i}`, {
                clusterName: clusterName,
                clusterVersion: clusterVersion,
                subnetIds: subnetIds,
                name: nodegroup.nodeName,
                minSize: 1,
                maxSize: maxNodeCapacity,
                desiredSize: nodegroup.desireNumberNodes,
                instanceTypes: instanceType,
                capacityType: "SPOT",
                clusterServiceCidr: vpcInfo.getVpcCidrRange(),
                preBootstrapUserData: preBootstrapUserData,
                useCustomLaunchTemplate: false,
                taints: taints,
                remoteAccess: {
                    ec2_ssh_key: keyPair.keyName,
                },
                dependsOn: [eksCluster, keyPair]
            });
        }
    }

    // Returns the create nodegroup
    public getNodeGroup(): EksNodegroup {
        return this.nodeGroup;
    }
}
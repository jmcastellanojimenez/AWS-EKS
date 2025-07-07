/**
 *
 * EKS Addons
 *
 * This module install the EKS Addons
 *
 * Necessary variable:
 *
 * eksCluster this is the eks resource
 * eksNodegroup this is the nodegroup resource
 * install Cilium this is a boolean variable designed to know if Cilium is going to be installed or not
 *
 */

import { EksStack } from "../../main";
import { eksCiliumAddon } from "../../modules/eks_addons/cilium";
import { EksAddons } from "../../../.gen/modules/eks_addons";
import { DataAwsEksAddonVersion } from "../../../.gen/providers/aws/data-aws-eks-addon-version";
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup";
import { EbsCsiDriverIrsa } from "../../../.gen/modules/ebs_csi_driver_irsa";

export class eksAddonsCreation {
  private addons: EksAddons;

  public addonsMaps = new Map<string, string>([
    ["coredns", ""],
    ["aws-ebs-csi-driver", ""],
    ["eks-pod-identity-agent", ""],
    ["vpc-cni", ""],
    ["kube-proxy", ""],
  ]);

  constructor(
    scope: EksStack,
    clusterName: string,
    eksCluster: EksCluster,
    eksNodegroup: EksNodegroup,
    installCilium: boolean,
  ) {
    for (let key of this.addonsMaps.keys()) {
      // Get the version for each addon
      const addonVersion = new DataAwsEksAddonVersion(scope, `adddon-${key}`, {
        addonName: key,
        kubernetesVersion: eksCluster.clusterVersionOutput,
      });

      this.addonsMaps.set(key, addonVersion.version);
    }

    // Create permissions for the EBS CSI controller
    const ebsServiceAccountRole = new EbsCsiDriverIrsa(
      scope,
      `ebs-csi-driver-${clusterName}`,
      {
        roleNamePrefix: "ebs-csi-driver-",
        attachEbsCsiPolicy: true,
        oidcProviders: {
          main: {
            provider_arn: eksCluster.oidcProviderArnOutput,
            namespace_service_accounts: ["kube-system:ebs-csi-controller-sa"],
          },
        },
      },
    );

    const addons: { [key: string]: any } = {
      coredns: {
        addon_version: this.addonsMaps.get("coredns"),
      },
      "aws-ebs-csi-driver": {
        addon_version: this.addonsMaps.get("aws-ebs-csi-driver"),
        service_account_role_arn: ebsServiceAccountRole.iamRoleArnOutput,
      },
      "eks-pod-identity-agent": {
        addon_version: this.addonsMaps.get("eks-pod-identity-agent"),
      },
    };

    let depends: any[] = [eksCluster, eksNodegroup];
    if (!installCilium) {
      addons["vpc-cni"] = {
        addon_version: this.addonsMaps.get("vpc-cni"),
      };
      addons["kube-proxy"] = {
        addon_version: this.addonsMaps.get("kube-proxy"),
      };
    } else {
      // Install cilium
      const ciliumInstall = new eksCiliumAddon(
        scope,
        eksCluster,
        eksNodegroup,
        clusterName,
      ).getHelmRelease();
      depends.push(ciliumInstall);
    }

    // Install the addons on EKS
    this.addons = new EksAddons(scope, `eksaddons-${clusterName}`, {
      clusterEndpoint: eksCluster.clusterEndpointOutput,
      clusterName: clusterName,
      clusterVersion: eksCluster.clusterVersionOutput,
      oidcProviderArn: eksCluster.oidcProviderArnOutput,
      eksAddons: addons,
      dependsOn: depends,
    });
  }

  // Returns the created addons
  public getAddons(): EksAddons {
    return this.addons;
  }
}

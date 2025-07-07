/**
 *
 * Bootstrap
 *
 * This module runs the bootstrap ansible playbook
 *
 * Necessary variables:
 *  cluster name
 *  environment
 *  region
 *  cluster url
 *  aws account
 *
 */

import { EksStack } from "../../main";
import { EksCluster } from "../../../.gen/modules/eks_cluster";
import { EksNodegroup } from "../../../.gen/modules/eks_nodegroup";
import { EksAddons } from "../../../.gen/modules/eks_addons";

import { JobTemplateLaunch } from "../../../.gen/providers/awx/job-template-launch";

import { awxProvider } from "../../providers";

export class clusterBoostrap {
  constructor(
    scope: EksStack,
    eksCluster: EksCluster,
    eksNodegroup: EksNodegroup,
    eksAddons: EksAddons,
    clusterName: string,
    env: string,
    region: string,
    clusterUrl: string,
    awsAccount: string,
  ) {
    const mode = process.env.CDKTF_MODE;

    // Call the AWX provider
    awxProvider(scope);

    if (mode === "apply") {
      // Launch the ansible playboook
      new JobTemplateLaunch(scope, "template-launch", {
        jobTemplateId: 779,
        extraVars: JSON.stringify({
          cluster_name: clusterName,
          env: env,
          cloud: "aws",
          region: region,
          cluster_url: clusterUrl,
          aws_account: awsAccount,
          // To be deleted, just for testing
          force_disable_pd: true,
        }),
        waitForCompletion: true,
        dependsOn: [eksCluster, eksNodegroup, eksAddons],
      });
    } else if (mode === "destroy") {
      // Launch the ansible playboook
      new JobTemplateLaunch(scope, "template-launch", {
        jobTemplateId: 780,
        extraVars: JSON.stringify({
          cluster_name: clusterName,
          env: env,
          cloud: "aws",
          region: region,
        }),
        waitForCompletion: true,
        dependsOn: [eksCluster, eksNodegroup, eksAddons],
      });
    }
  }
}

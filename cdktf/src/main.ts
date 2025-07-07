import { Construct } from "constructs";
import { App, TerraformStack } from "cdktf";
import { setUpProvider, setUpVaultProvider } from "./providers";

import { eksCreation } from "./modules/eks/eks";
import { eksNodegroupCreation } from "./modules/eks_nodegroups/eksNodegroups";
import { eksAddonsCreation } from "./modules/eks_addons/eksAddons";
import { GetVpcInfo } from "./modules/vpc/vpcData";
import { clusterBoostrap } from "./modules/bootstrap/bootstrap"
import { externalDNSRoleCreation } from "./modules/permission/permission"

interface stackConfig {
  stackName?: string;
  account: string;
  region: string;
}

export interface nodegroupsConfig {
  nodeName: string;
  nodeSize: "XS" | "S" | "M" | "L" | "XL" | "XXL"; // Allow only these sizes;
  desireNumberNodes: number;
  instanceType?: string | string[];
}

interface projConfig {
  [key: string]: {
    vpcId: string;
    k8sVersion: string;
    clusterName: string;
    installCilium: boolean;
    bootstrap: boolean;
    nodegroups: nodegroupsConfig[];
  };
}

export interface infraConfig extends stackConfig {
  tags: {
    environment: string;
    project: string;
  };
  projects: projConfig;
}

const CLUSTER = process.env.CLUSTER;

export class EksStack extends TerraformStack {
  private eksConfig: stackConfig;
  public clusterName: string;
  public environment: string;

  constructor(scope: Construct, id: string) {
    super(scope, id);
    this.clusterName = "";
    if (CLUSTER) {
      this.clusterName = CLUSTER
      if (this.clusterName.startsWith("np-")) {
        this.environment = "Non-Production";
      } else if (this.clusterName.startsWith("p-")) {
        this.environment = "Production";
      } else {
        this.environment = "Lab";
      }
    } else {
      console.error("CLUSTER is not set. Terminating the execution.");
      process.exit(1); // Exit the process with a failure code
    }

    this.eksConfig = this.readConfigFile(this.clusterName);

    const config = <infraConfig>this.eksConfig;

    // Set up Providers
    setUpProvider(this, config.region, this.clusterName, config.account);
    setUpVaultProvider(this)

    // Logging information
    console.log("Config loaded:");
    console.log("Stack Name:", config.stackName);
    console.log("Account:", config.account);
    console.log("Region:", config.region);

    console.log("Tags:");
    console.log(`  Environment: ${config.tags.environment}`);
    console.log(`  Project: ${config.tags.project}`);

    console.log("Projects:");
    for (const [projectName, projectConfig] of Object.entries(config.projects)) {

      console.log(`- Project: ${projectName}`);
      console.log(`    VPC ID: ${projectConfig.vpcId}`);
      console.log(`    Kubernetes Version: ${projectConfig.k8sVersion}`);
      console.log(`    Cluster Name: ${this.clusterName}`);
      console.log(`    Environment: ${this.environment}`);
      for (const [_, nodegroupConfig] of Object.entries(projectConfig.nodegroups)) {
        console.log(`        Node Name: ${nodegroupConfig.nodeName}`);
        console.log(`        Node Size: ${nodegroupConfig.nodeSize}`);
        console.log(`        Desire number of nodes: ${nodegroupConfig.desireNumberNodes}`);
      }

      // Get VPC information
      const vpcInfo = new GetVpcInfo(this, projectConfig.vpcId);
      const subnetIds = vpcInfo.getSubnetIds();

      // Create EKS cluster
      const eksCluster = (new eksCreation(this, this.clusterName, projectConfig.k8sVersion, projectName, this.environment, projectConfig.vpcId, subnetIds)).getCluster();

      // Create nodegroups
      const eksNode = (new eksNodegroupCreation(this, this.clusterName, projectConfig.k8sVersion, projectName, subnetIds, projectConfig.nodegroups, eksCluster, vpcInfo)).getNodeGroup();

      // Install Addons
      const clusterAddons = (new eksAddonsCreation(this, this.clusterName, eksCluster, eksNode, projectConfig.installCilium)).getAddons();

      // Generate Roles for External-DNS (Route53)
      new externalDNSRoleCreation(this, eksCluster, this.clusterName)

      if (projectConfig.bootstrap) {
        // Run Bootstrap
        new clusterBoostrap(this, eksCluster, eksNode, clusterAddons, this.clusterName, this.environment, config.region, eksCluster.clusterEndpointOutput, config.account)
      }
    }
  }

  // Get configuration information from files
  private readConfigFile(clusterName: string) {
    let path
    if (this.clusterName.startsWith("np-")) {
      path = "nonprod";
    } else if (this.clusterName.startsWith("lab-")) {
      path = "sandbox";
    } else {
      path = "prod";
    }
    const filePath = `${process.cwd()}/config/${path}/${clusterName}.json`;
    const config = <stackConfig>require(filePath);
    return config;
  }
}

const app = new App();
new EksStack(app, "ekscdktf");
app.synth();

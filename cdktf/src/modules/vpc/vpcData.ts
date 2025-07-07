/**
 * 
 * VPC Data
 * 
 * This module obtains information about the VPC and subnets in the account.
 * 
 * Necessary variable:
 * 
 * VPC ID
 * 
 */

import { EksStack } from "../../main";
import { DataAwsVpc } from "../../../.gen/providers/aws/data-aws-vpc";
import { DataAwsSubnets } from "../../../.gen/providers/aws/data-aws-subnets";

export class GetVpcInfo {
    private readonly subnetsInfo: DataAwsSubnets;
    private readonly vpcInfo: DataAwsVpc

    constructor(scope: EksStack, vpcId: string) {

        // Get VPC information
        this.vpcInfo = new DataAwsVpc(scope, `vpc-${vpcId}`, {
            id: vpcId,
        });

        // Get subnets information depending on the vpc and tags
        this.subnetsInfo = new DataAwsSubnets(scope, `subnets-${vpcId}`, {
            filter: [
                {
                    name: "vpc-id",
                    values: [this.vpcInfo.id],
                },
                {
                    name: "tag:Name",
                    values: ["*priv*"],
                },
            ],
        });
    }

    // Gets subnets IDs
    public getSubnetIds(): string[] {
        return this.subnetsInfo.ids;
    }

    // Gets subnets range
    public getVpcCidrRange(): string {
        return this.vpcInfo.cidrBlock;
    }
}

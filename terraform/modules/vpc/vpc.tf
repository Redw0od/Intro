################################################################################
# Data
################################################################################
data "aws_availability_zones" "available" {}
data "aws_region" "current" { }

#
# TAGS
#
module "vpc_label" {
  source     = "../labels"
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  tags       = "${var.tags}"
  attributes = ["${compact(var.attributes)}"]
}


################################################################################
# VPC
################################################################################
resource "aws_vpc" "this" {
  cidr_block                       = "${var.cidr_block}"
  instance_tenancy                 = "${var.tenancy}"
  enable_dns_support               = "${var.enable_dns_support}"
  enable_dns_hostnames             = "${var.enable_dns_hostnames}"
  enable_classiclink               = false
  assign_generated_ipv6_cidr_block = "${var.ipv6_cidr_block}" 
  tags       = "${module.vpc_label.tags}"
}

################################################################################
# DHCP Options
################################################################################
resource "aws_vpc_dhcp_options" "this" {
  domain_name         = "${var.name}.${var.domain_name}"
  domain_name_servers = [ "${var.dns_servers }" ]
  
  tags       = "${module.vpc_label.tags}"

  count  = "${var.domain_name == "" ? 0 : 1}"
}

resource "aws_vpc_dhcp_options_association" "this" {
  vpc_id          = "${aws_vpc.this.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"

  count  = "${var.domain_name == "" ? 0 : 1}"
}

################################################################################
# Internet Gateway
################################################################################
resource "aws_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"


  tags       = "${module.vpc_label.tags}"
}

################################################################################
# Internet IPv6 Egress Gateway
################################################################################
resource "aws_egress_only_internet_gateway" "this" {
  vpc_id = "${aws_vpc.this.id}"
  count  = "${var.ipv6_private_egress ? 1 : 0}"
}


################################################################################
# Routing Tables
################################################################################
resource "aws_default_route_table" "default" {
  default_route_table_id = "${aws_vpc.this.default_route_table_id}"  
 
  tags = "${merge(
    module.vpc_label.tags, 
  map(
    "Name", "${module.vpc_label.tags["Name"]}-default"
  )
  )}"
}


################################################################################
# Default Security Group
################################################################################
resource "aws_default_security_group" "default" {
  vpc_id = "${aws_vpc.this.id}"
  tags = "${merge(
    module.vpc_label.tags, 
  map(
    "Name", "${module.vpc_label.tags["Name"]}-default-deny-all"
  )
  )}"
}

################################################################################
# Flow Logs
################################################################################
resource "aws_cloudwatch_log_group" "vpc" {
  name              = "/aws/vpc/${module.vpc_label.tags["Name"]}-flow-logs"
  retention_in_days = 30
  count             = "${var.enable_vpc_flow_logs ? 1 : 0}"
}

resource "aws_iam_role" "flow_logs" {
  name   = "${var.vpc_flow_logs_name}"
  assume_role_policy = "${file("${path.module}/policies/vpc-flow-logs-assume-policy.json")}"
  count              = "${var.enable_vpc_flow_logs ? 1 : 0}"
}

resource "aws_iam_role_policy" "AmazonVPCFlowLogs" {
  name   = "${var.vpc_flow_logs_name}"
  role   = "${aws_iam_role.flow_logs.id}"
  policy = "${file("${path.module}/policies/vpc-flow-logs-policy.json")}"
  count  = "${var.enable_vpc_flow_logs ? 1 : 0}"
}

resource "aws_flow_log" "this" {
  vpc_id         = "${aws_vpc.this.id}"
  log_group_name = "${aws_cloudwatch_log_group.vpc.name}"
  iam_role_arn   = "${aws_iam_role.flow_logs.arn}"
  traffic_type   = "ALL"
  count          = "${var.enable_vpc_flow_logs ? 1 : 0}"
}
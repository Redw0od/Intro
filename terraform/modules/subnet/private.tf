locals {
  private_count = "${var.enabled == "true" && var.type == "private" ? length(var.availability_zones) : 0}"
  cidr_start = "${cidrsubnet(var.ipv6_cidr_block, 6, var.iteration)}" 
  
}

module "private_label" {
  source     = "../labels"
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  tags       = "${var.tags}"
  attributes = ["${compact(var.attributes)}"]
  enabled    = "${var.enabled}"
}

resource "aws_subnet" "private" {
  count             = "${local.private_count}"
  vpc_id            = "${var.vpc_id}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  cidr_block        = "${cidrsubnet(var.cidr_block, ceil(log(var.max_subnets, 2)), count.index)}"
  assign_ipv6_address_on_creation = "${var.enable_ipv6}"
  ipv6_cidr_block   = "${cidrsubnet(local.cidr_start, 2, count.index)}"

  tags = "${merge(
    module.private_label.tags, 
  map(
    "Type", var.type,
    
    "Name", "${module.private_label.tags["Name"]}-${substr(element(var.availability_zones, count.index),length(var.availability_zones[0]) - 1,1)}"
  )
  )}"
}

resource "aws_route_table" "private" {
  count  = "${local.private_count}"
  vpc_id = "${var.vpc_id}"

  tags = "${merge(
    module.private_label.tags, 
  map(
    "Name", "${module.private_label.tags["Name"]}-${substr(element(var.availability_zones, count.index),length(var.availability_zones[0]) - 1,1)}"
  )
  )}"
}

resource "aws_route" "ipv4" {
  count                  = "${local.private_count}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  network_interface_id   = "${var.eni_id}"
  nat_gateway_id         = "${element(split(",",var.ngw_id), count.index)}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "ipv6" {
  count                  = "${local.private_count}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
  network_interface_id   = "${var.eni_id}"
  destination_ipv6_cidr_block  = "::/0"
  egress_only_gateway_id = "${var.egw_id}"
}
resource "aws_route_table_association" "private" {
  count          = "${local.private_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_network_acl" "private" {
  count      = "${var.enabled == "true" && var.type == "private" && signum(length(var.private_network_acl_id)) == 0 ? 1 : 0}"
  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = ["${aws_subnet.private.*.id}"]
  egress     = "${var.private_network_acl_egress}"
  ingress    = ["${var.private_network_acl_ingress}"]
  tags       = "${module.private_label.tags}"
}
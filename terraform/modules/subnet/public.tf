locals {
  public_count = "${var.enabled == "true" && var.type == "public" ? length(var.availability_zones) : 0}"
  ngw_count    = "${var.enabled == "true" && var.type == "public" && var.nat_enabled == "true" ? length(var.availability_zones) : 0}"

}

module "public_label" {
  source     = "../labels"
  namespace  = "${var.namespace}"
  name       = "${var.name}"
  stage      = "${var.stage}"
  delimiter  = "${var.delimiter}"
  tags       = "${var.tags}"
  attributes = ["${compact(var.attributes)}"]
  enabled    = "${var.enabled}"
}

resource "aws_subnet" "public" {
  count             = "${local.public_count}"
  vpc_id            = "${var.vpc_id}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  cidr_block        = "${cidrsubnet(var.cidr_block, ceil(log(var.max_subnets, 2)), count.index)}"
  assign_ipv6_address_on_creation = "${var.enable_ipv6}"
  ipv6_cidr_block   = "${cidrsubnet(local.cidr_start, 2, count.index)}"
  map_public_ip_on_launch = "true"

  tags = "${merge(
    module.private_label.tags, 
  map(
    "Type", var.type,
    
    "Name", "${module.private_label.tags["Name"]}-${substr(element(var.availability_zones, count.index),length(var.availability_zones[0]) - 1,1)}"
  )
  )}"
}

resource "aws_route_table" "public" {
  count  = "1"
  vpc_id = "${var.vpc_id}"  
  tags   = "${module.public_label.tags}"
}

resource "aws_route" "public" {
  count                  = "1"
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${var.igw_id}"
  network_interface_id   = "${var.eni_id}"
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route" "public_v6" {
  count                  = "1"
  route_table_id         = "${aws_route_table.public.id}"
  gateway_id             = "${var.igw_id}"
  network_interface_id   = "${var.eni_id}"
  destination_ipv6_cidr_block = "::/0"
}
resource "aws_route_table_association" "public" {
  count          = "${local.public_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_network_acl" "public" {
  count      = "${var.enabled == "true" && var.type == "public" && signum(length(var.public_network_acl_id)) == 0 ? 1 : 0}"
  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = ["${aws_subnet.public.*.id}"]
  egress     = "${var.public_network_acl_egress}"
  ingress    = "${var.public_network_acl_ingress}"
  tags       = "${module.public_label.tags}"
}

resource "aws_eip" "default" {
  count = "${local.ngw_count}"
  vpc   = "true"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "default" {
  count         = "${local.ngw_count}"
  allocation_id = "${element(aws_eip.default.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
 
  tags = "${merge(
    module.private_label.tags, 
  map(
    "Name", "${module.private_label.tags["Name"]}-${substr(element(var.availability_zones, count.index),length(var.availability_zones[0]) - 1,1)}"
  )
  )}"

  lifecycle {
    create_before_destroy = true
  }
}
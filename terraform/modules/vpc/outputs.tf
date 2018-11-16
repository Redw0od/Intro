output "region"                       { 
    value = "${data.aws_region.current.name}"                         
    description = "Region where the VPC is created."
    }
output "vpc_id"                       { 
    value = "${aws_vpc.this.id}"                                       
    description = "VPC unique ID." 
    }
output "vpc_name"                     { 
    value = "${var.name}"                                             
    description = "VPC name." 
    }
output "ipv4_cidr_block"              { 
    value = "${aws_vpc.this.cidr_block}"                               
    description = "IPv4 assigned to the VPC." 
    }
output "ipv6_cidr_block"              { 
    value = "${aws_vpc.this.ipv6_cidr_block }"                         
    description = "IPv6 assigned to the VPC." 
    }
output "domain_name"                  { 
    value = "${var.domain_name}"                                      
    description = "Route53 internal hosted zone assigned to the VPC." 
    }
output "internet_gateway"             { 
    value = "${aws_internet_gateway.this.id}"                        
    description = "Intenret gateway assigned to the VPC" 
    }
output "availability_zones"           { 
    value = "${data.aws_availability_zones.available.names}"                                          
    description = "Availability Zones to use in VPC" 
    }
output "egress_only_gateway"             { 
    value = "${aws_egress_only_internet_gateway.this.id}"                        
    description = "Intenret gateway assigned to the VPC" 
    }
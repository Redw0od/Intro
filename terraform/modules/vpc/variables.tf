variable "namespace" {
  description = "Namespace (e.g. `company abbreviation`)"
  type        = "string"
}

variable "stage" {
  description = "Stage (e.g. `prod`, `dev`, `staging`)"
  type        = "string"
}

variable "delimiter" {
  type        = "string"
  default     = "-"
  description = "Delimiter to be used between `name`, `namespace`, `stage`, `attributes`"
}

variable "attributes" {
  type        = "list"
  default     = []
  description = "Additional attributes (e.g. `policy` or `role`)"
}

variable "tags" {
  type        = "map"
  default     = {}
  description = "Additional tags (e.g. map(`BusinessUnit`,`XYZ`)"
}
variable "name" {   
    type        = "string"                                              
    description = "AWS VPC name. This would be used as prefix in all the resources to support multiple VPCs."
    }
variable "domain_name"          { 
    default     = ""                      
    description = "Domain name used with DHCP options in the VPC." 
    }
variable "cidr_block"           { 
    default     = "172.16.0.0/18"           
    description = "CIDR block assigned to the VPC." 
    }
variable "ipv6_cidr_block"      { 
    default     = true                   
    description = "Enable IPv6." 
    }
variable "ipv6_private_egress"  { 
    default     = true                   
    description = "Enable IPv6 Egress Gateway for private subnets." 
    }
variable "tenancy"              { 
    default     = "default"               
    description = "Sets where the EC2 instance will run. Accepted values are 'default', 'dedicated' or 'host'." 
    }
variable "enable_dns_support"   { 
    default     = true                    
    description = "Queries to the Amazon provided DNS server at the 169.254.169.253 IP address, or the reserved IP address at the base of the VPC IPv4 network range plus two will succeed." 
    }
variable "enable_dns_hostnames" { 
    default     = true                    
    description = "Instances in the VPC get public DNS hostnames, but only if the enable_dns_support attribute is also set to true." 
    }
variable "enable_vpc_flow_logs" { 
    default     = true                   
    description = "Enable VPC Flow logs." 
    }
variable "vpc_flow_logs_name" {        
    description = "Name applied to flow logs IAM role" 
    }
variable "cidr_value"           { 
    default     = 8                      
    description = "The additional CIDR mask length to apply to subnets" 
    }
variable "dns_servers"          { 
    default     = "AmazonProvidedDNS"    
    description = "DNS Servers to issue via DHCP" 
    }
variable "az_limit"             { 
    default     = "0"                     
    description = "DNS Servers to issue via DHCP" 
}
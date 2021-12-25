variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

variable "availability_zones_count" {
  description = "AZ Count to create subnets in, needs to be <= amount of actual available AZs"
  type        = number
}

variable "project_name" {
  description = "Project Name"
  type        = string
}

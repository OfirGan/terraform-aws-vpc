##################################################################################
# VPC - New VPC
# Route53 Zone
# SUBNETS - public & private in each AZ
# Gateway - Internet Gateway + NAT Gateway for each private subnet
# Rout Tables - public to Internet Gateway & private to NAT Gateway on the same AZ
# IAM - Describe EC2 Instances
# IAM - Server Certificate
##################################################################################

##################################################################################
# VPC
##################################################################################

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

##################################################################################
# Route53 Zone
##################################################################################

resource "aws_route53_zone" "kandula_route53_zone" {
  name          = "kandula"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  tags = {
    Name = "${var.project_name}-route53-zone"
  }
}

##################################################################################
# SUBNETS
##################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnets" {
  count                   = var.availability_zones_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1 + count.index)
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count                = var.availability_zones_count
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 101 + count.index)
  availability_zone_id = data.aws_availability_zones.available.zone_ids[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 101}"
  }
}

##################################################################################
# Gateway
##################################################################################

####################
# Internet Gateway
####################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-internet-gateway"
  }
}

########################
# Internet NAT Gateway
########################

resource "aws_eip" "internet_nat_gateway_eips" {
  count = length(aws_subnet.public_subnets[*].id)
  tags = {
    Name = "${var.project_name}-eip-internet-nat-gateway-${count.index + 1}"
  }

  # EIP may require IGW to exist prior to association. 
  # Use depends_on to set an explicit dependency on the IGW.
  depends_on = [aws_internet_gateway.internet_gateway]
}

resource "aws_nat_gateway" "internet_nat_gateways" {
  count         = length(aws_subnet.public_subnets[*].id)
  allocation_id = aws_eip.internet_nat_gateway_eips[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.project_name}-internet-nat-gateway-${count.index + 1}"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet_gateway]
}

##################################################################################
# Rout Tables
##################################################################################

resource "aws_default_route_table" "default_route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  tags = {
    Name = "${var.project_name}-default-route-table"
  }
}

##########
# Public
##########

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

resource "aws_route" "route_to_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}


resource "aws_route_table_association" "public_route_table_association" {
  count          = length(aws_subnet.public_subnets[*].id)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}


##########
# Private
##########

resource "aws_route_table" "private_route_tables" {
  count  = var.availability_zones_count
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project_name}-private-route-table-${count.index + 1}"
  }
}

resource "aws_route" "route_to_internet_nat_gateway" {
  count                  = length(aws_route_table.private_route_tables[*].id)
  route_table_id         = aws_route_table.private_route_tables[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.internet_nat_gateways[count.index].id
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = length(aws_subnet.private_subnets[*].id)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
}

##################################################################################
# IAM - Describe EC2 Instances
##################################################################################

resource "aws_iam_role" "ec2_describe_instances_role" {
  name = "ec2_describe_instances_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "ec2_describe_instances_policy" {
  name = "ec2_describe_instances_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:Describe*",
          "sts:AssumeRole",
          "eks:DescribeCluster"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_describe_instances_policy_attachment" {
  name       = "ec2_describe_instances_policy_attachment"
  roles      = [resource.aws_iam_role.ec2_describe_instances_role.name]
  policy_arn = resource.aws_iam_policy.ec2_describe_instances_policy.arn
}

resource "aws_iam_instance_profile" "ec2_describe_instances_instance_profile" {
  name = "ec2_describe_instances_instance_profile"
  role = resource.aws_iam_role.ec2_describe_instances_role.name
}

##################################################################################
# IAM - Server Certificate
##################################################################################

resource "aws_iam_server_certificate" "self_signed_cert" {
  name             = "${var.project_name}-self_signed_cert"
  certificate_body = var.tls_self_signed_cert_pem_content
  private_key      = var.cert_private_key_pem_content
}

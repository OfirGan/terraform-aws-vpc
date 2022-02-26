###################################################################################
# OUTPUT
###################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "public_subnets_ids" {
  description = "Public Subnets IDs"
  value       = aws_subnet.public_subnets.*.id
}

output "private_subnets_ids" {
  description = "Private Subnets IDs"
  value       = aws_subnet.private_subnets.*.id
}

output "ec2_describe_instances_role_arn" {
  description = "EC2 Describe Instances Role ARN"
  value       = aws_iam_role.ec2_describe_instances_role.arn
}

output "ec2_describe_instances_instance_profile_id" {
  description = "EC2 Describe Instances Instance Profile ID"
  value       = aws_iam_instance_profile.ec2_describe_instances_instance_profile.id
}

output "aws_iam_server_certificate_arn" {
  description = "AWS IAM Server Certificate ARN"
  value       = aws_iam_server_certificate.self_signed_cert.arn
}

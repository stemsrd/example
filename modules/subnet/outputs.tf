output "private_subnet_zone1_id" {
  description = "The ID of the private subnet in zone 1"
  value       = aws_subnet.private_zone1.id
}

output "private_subnet_zone2_id" {
  description = "The ID of the private subnet in zone 2"
  value       = aws_subnet.private_zone2.id
}

output "public_subnet_zone1_id" {
  description = "The ID of the public subnet in zone 1"
  value       = aws_subnet.public_zone1.id
}

output "public_subnet_zone2_id" {
  description = "The ID of the public subnet in zone 2"
  value       = aws_subnet.public_zone2.id
}

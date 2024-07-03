resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id

  tags = {
    Name = "${var.env}-nat"
  }

  depends_on = [var.igw_id]
}

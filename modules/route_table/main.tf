resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_id
  }

  tags = {
    Name = "${var.env}-private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }

  tags = {
    Name = "${var.env}-public"
  }
}

resource "aws_route_table_association" "private_zone1" {
  subnet_id      = var.private_subnet_zone1_id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_zone2" {
  subnet_id      = var.private_subnet_zone2_id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_zone1" {
  subnet_id      = var.public_subnet_zone1_id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_zone2" {
  subnet_id      = var.public_subnet_zone2_id
  route_table_id = aws_route_table.public.id
}

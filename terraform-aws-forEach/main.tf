# -------- aws vpc block --------#

# vpc
# Internet Gateway 
# security_group (open ingress icmp, 22, 80, 443 ------ egress 0.0.0.0/0)
# subnets (two public and two private)
# route table (one public subnets and one private subnets)
# route_table_association (two)
# one eip
# one NAT Gateway


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  #access_key = ""
  #secret_key = ""
}


data "aws_availability_zones" "available" {}

locals {
  azs = data.aws_availability_zones.available.names

  subnet_az_mapping = {
    pub-1  = local.azs[0]
    priv-1 = local.azs[0]
    pub-2  = local.azs[1]
    priv-2 = local.azs[1]
  }
  cluster_name = "${var.env}-my-cluster"
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_ciders

  tags = {
    Name = "${var.env}-vpc"
  }
}


# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-igw"
  }
}


resource "aws_security_group" "web_sg" {
  name        = "${var.env}-web-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress = concat(
    [
      for port in var.allowed_ports : {
        description      = "Allow inbound port ${port}"
        from_port        = port
        to_port          = port
        protocol         = "tcp"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        security_groups  = []
        self             = false
      }
    ],
    [
      {
        description      = "Allow ICMP (ping)"
        from_port        = -1
        to_port          = -1
        protocol         = "icmp"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        security_groups  = []
        self             = false
      }
    ]
  )

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-SG"
  }
}



resource "aws_subnet" "public-subnet" {
  for_each                = var.public_subnets_ciders
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = local.subnet_az_mapping[each.key]


  tags = {
    Name                                          = "${var.env}-${each.key}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

resource "aws_subnet" "private-subnet" {
  for_each                = var.private_subnets_ciders
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = false
  availability_zone       = local.subnet_az_mapping[each.key]


  tags = {
    Name                                          = "${var.env}-${each.key}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# --- Public Route Table ---
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env}-public-rt"
  }
}

# --- Associate Public Subnets ---
resource "aws_route_table_association" "public_assoc" {
  for_each = aws_subnet.public-subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public-rt.id
}

# --- NAT Gateways ---
# Create one NAT gateway per public subnet (HA)
resource "aws_eip" "nat" {
  #for_each = aws_subnet.public-subnet
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-subnet["pub-1"].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.env}-nat"
  }
}

# --- Private Route Table ---
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.env}-private-rt"
  }
}

# --- Route private subnets to NAT (choose first NAT for simplicity) ---
resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private-rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# --- Associate Private Subnets ---
resource "aws_route_table_association" "private_assoc" {
  for_each = aws_subnet.private-subnet

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private-rt.id
}































































# resource "aws_security_group" "web_sg" {
#   name        = "web-security-group"
#   description = "Allow inbound traffic"
#   vpc_id      = aws_vpc.main.id

#   ingress = [
#     for port in var.allowed_ports : {
#       description = "Allow inbound port ${port}"
#       from_port   = port
#       to_port     = port
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   ]

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${var.env}-SG"
#   }
# }






# resource "aws_security_group" "web_sg" {
#   name        = "web-security-group"
#   description = "Allow inbound"
#   vpc_id      = aws_vpc.main.id

#   tags = {
#     Name = "web-sg"
#   }
# }

# resource "aws_security_group_rule" "ingress_rules" {
#   for_each = toset(var.allowed_ports)

#   type              = "ingress"
#   from_port         = each.value
#   to_port           = each.value
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.web_sg.id
# }


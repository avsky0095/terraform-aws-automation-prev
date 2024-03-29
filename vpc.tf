
# CREATE VPC
# ---------------------------------------------------------------

#  Create the VPC
resource "aws_vpc" "Main" {                               # Creating VPC here
  cidr_block            = var.vpc_main_cidr_block         # Defining the CIDR block use 10.0.0.0/16 for demo
  instance_tenancy      = "default"
  enable_dns_support    = true
  enable_dns_hostnames  = true

  tags = {
    Name = "${var.default_name}"
  }
}


# CREATE SUBNETS
# ---------------------------------------------------------------

// MANAGEMENT 10.0.0.0                CIDR /24
// PUBLIC     10.0.1.0    10.0.2.0
// PRIVATE    10.0.3.0    10.0.4.0

resource "aws_subnet" "managementsubnet" {
  vpc_id                  = aws_vpc.Main.id
  cidr_block              = cidrsubnet(aws_vpc.Main.cidr_block, 8, 0)           // 10.0.0.0/24
  availability_zone       = data.aws_availability_zones.az_available.names[0]   // AZ-1
  map_public_ip_on_launch = false

  tags = {
    Name = "Management Subnet"
  }
}

resource "aws_subnet" "publicsubnets" {             # Creating Public Subnets
  count                   = 2                 // create 2 subnets

  vpc_id                  = aws_vpc.Main.id                           // count index mulai dari 10.0.1.0
  cidr_block              = cidrsubnet(aws_vpc.Main.cidr_block, 8, count.index+1)            # CIDR block of public subnets
  availability_zone       = data.aws_availability_zones.az_available.names[count.index]           // ap-southeast-3
  map_public_ip_on_launch = true                            // auto-assign public ip address di instance

  tags = {
    Name = "Public Subnet ${count.index+1}"
  }
}

resource "aws_subnet" "privatesubnets" {             # Creating Public Subnets
  count                   = 2

  vpc_id                  = aws_vpc.Main.id                           // network mulai dari 10.0.{length pubsub}.0
  cidr_block              = cidrsubnet(aws_vpc.Main.cidr_block, 8, count.index+length(aws_subnet.publicsubnets)+1 )            # CIDR block of public subnets
  availability_zone       = data.aws_availability_zones.az_available.names[count.index]           // ap-southeast-3 // gunakan %2 (modulus) agar looping AZ
  map_public_ip_on_launch = false                            // auto-assign public ip address di instance

  tags = {
    Name = "Private Subnet ${count.index+1}"
  }
}


# CREATE GATEWAYS IGW/NAT-GW/NAT-interface
# ---------------------------------------------------------------

#  Create Internet Gateway and attach it to VPC
resource "aws_internet_gateway" "IGW" {                   # Creating Internet Gateway
  vpc_id = aws_vpc.Main.id                                # vpc_id will be generated after we create VPC

  tags = {
    Name = "Internet Gateway (igw)"
  }
}

// DISABLED FOR FUTURE USE
# Creating Elastic IP for NAT Gateway/NAT Instance
# resource "aws_eip" "nateIP" {
#   network_interface = aws_network_interface.net-interface.id
#   vpc               = true

#   tags = {
#     # "Name" = "test - Elastic IP for natgw"
#     "Name" = "Elastic IP for NAT-Instance"
#   }
# }

# nat interface for nat-instance
resource "aws_network_interface" "net-interface" {
  subnet_id         = aws_subnet.managementsubnet.id
  security_groups   = [aws_security_group.NATBas-sg.id]
  private_ip        = "10.0.0.10" 
  source_dest_check = false

  tags = {
    "Name" = "NAT instance network interface"
  }
}

// disabled for future use
# #  Creating the NAT Gateway using subnet_id and allocation_id
# resource "aws_nat_gateway" "NATgw" {
#   allocation_id = aws_eip.nateIP.id
#   subnet_id     = aws_subnet.publicsubnets.id

#   tags = {
#     Name = "test - NAT Gateway (nat-gw)"
#   }
# }


# CREATE ROUTE TABLES
# ---------------------------------------------------------------

#  Route table for Public Subnet's
resource "aws_route_table" "PublicRTigw" {                       # Creating RT for Public Subnet
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block = "0.0.0.0/0"                                  # Traffic from Public Subnet reaches Internet via Internet Gateway
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "Route Table pubsub -> igw -> inet"
  }
}

# Route table for Private Subnet's (ke nat instance)
resource "aws_route_table" "PrivateRTnatgw" {                      # Creating RT for Private Subnet
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block           = "0.0.0.0/0"                        # Traffic from Private Subnet reaches Internet via NAT Gateway
    network_interface_id = aws_network_interface.net-interface.id
    # nat_gateway_id = aws_nat_gateway.NATgw.id   // pakai ini bila mengaktifkan nat-gw
  }

  tags = {
    # Name = "Route Table privsub -> natgw -> inet"
    Name = "Route Table privsub -> nat-inst -> inet"
  }
}


# ROUTE TABLES ASSOCIATION TO
# ---------------------------------------------------------------

resource "aws_route_table_association" "ManagementRTassociation" {
  subnet_id      = aws_subnet.managementsubnet.id
  route_table_id = aws_route_table.PublicRTigw.id
}

resource "aws_route_table_association" "PublicRTassociation" {
  count = length(aws_subnet.publicsubnets)
  
  subnet_id      = aws_subnet.publicsubnets[count.index].id
  route_table_id = aws_route_table.PublicRTigw.id
}

resource "aws_route_table_association" "PrivateRTassociation" {
  count = length(aws_subnet.privatesubnets)
  
  subnet_id      = aws_subnet.privatesubnets[count.index].id
  route_table_id = aws_route_table.PrivateRTnatgw.id
}











# DRAFTS
# ---------------------------------------------------------------

# #  Route table Association with Public Subnet's
# resource "aws_route_table_association" "PublicRTassociation" {
#   subnet_id      = aws_subnet.publicsubnets_primary.id
#   route_table_id = aws_route_table.PublicRT.id
# }

# #  Route table Association with Private Subnet's
# resource "aws_route_table_association" "PrivateRTassociation" {
#   subnet_id      = aws_subnet.privatesubnets_primary.id
#   route_table_id = aws_route_table.PrivateRT.id
# }

# # 2nd subnet assoc
# #  Route table Association with Public Subnet's Secondary
# resource "aws_route_table_association" "PublicRTassociationSec" {
#   subnet_id      = aws_subnet.publicsubnets_secondary.id
#   route_table_id = aws_route_table.PublicRT.id
# }

# #  Route table Association with Private Subnet's Secondary
# resource "aws_route_table_association" "PrivateRTassociationSec" {
#   subnet_id      = aws_subnet.privatesubnets_secondary.id
#   route_table_id = aws_route_table.PrivateRT.id
# }

// public subnet -> route table -> igw -> internet
// private subnet -> route table -> nat-gw -> internet



#  Create a Public Subnets.
# resource "aws_subnet" "publicsubnets_primary" {             # Creating Public Subnets
#   vpc_id                  = aws_vpc.Main.id 
#   cidr_block              = local.pubsub_prim_cidrblock            # CIDR block of public subnets
#   availability_zone       = local.availability_zone_1           // ap-southeast-3
#   map_public_ip_on_launch = true                            // auto-assign public ip address di instance

#   tags = {
#     Name = "Public Subnet I - Primary"
#   }
# }

# #  Create a Private Subnet
# resource "aws_subnet" "privatesubnets_primary" {
#   vpc_id                  = aws_vpc.Main.id
#   cidr_block              = local.privsub_prim_cidrblock               # CIDR block of private subnets
#   availability_zone       = local.availability_zone_1
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "Private Subnet I - Primary"
#   }
# }

# # CREATE SUBNETS SECOND AVAILABILITY ZONE
# # ------------------

# #  Create a Public Subnets 2
# resource "aws_subnet" "publicsubnets_secondary" {             # Creating Public Subnets
#   vpc_id                  = aws_vpc.Main.id
#   cidr_block              = local.pubsub_sec_cidrblock            # CIDR block of public subnets
#   availability_zone       = local.availability_zone_2
#   map_public_ip_on_launch = true                              // auto-assign public ip address di instance

#   tags = {
#     Name = "Public Subnet II - Secondary"
#   }
# }

# #  Create a Private Subnet 2
# resource "aws_subnet" "privatesubnets_secondary" {
#   vpc_id                  = aws_vpc.Main.id
#   cidr_block              = local.privsub_sec_cidrblock              # CIDR block of public subnets  
#   availability_zone       = local.availability_zone_2
#   map_public_ip_on_launch = false

#   tags = {
#     Name = "Private Subnet II - Secondary"
#   }
# }

#####Create A VPC Configuration############
resource "aws_vpc" "CapOnePH1USR" {
  cidr_block = "10.0.0.0/23" # 512 IPs 
  tags = {
    Name = "CapOnePH1USR"
  }
}

###### Create Public subent ####################
resource "aws_subnet" "CapOnePH1USR_subnet_1a" {
  vpc_id                  = aws_vpc.CapOnePH1USR.id
  cidr_block              = "10.0.0.0/27" #32 IPs
  map_public_ip_on_launch = true          # allocate public IP
  availability_zone       = "ap-southeast-1a"
}
resource "aws_subnet" "CapOnePH1USR_subnet_1b" {
  vpc_id                  = aws_vpc.CapOnePH1USR.id
  cidr_block              = "10.0.0.32/27" #32 IPs
  map_public_ip_on_launch = true           # allocate public IP
  availability_zone       = "ap-southeast-1b"
}

##### Create Private Subnet ######################
resource "aws_subnet" "CapOnePH1USR_subnet_2" {
  vpc_id                  = aws_vpc.CapOnePH1USR.id
  cidr_block              = "10.0.1.0/27" #32 IPs
  map_public_ip_on_launch = false         # No Public IP allocation
  availability_zone       = "ap-southeast-1b"
}

### Internet Gateway for Public Subnet ###########
resource "aws_internet_gateway" "CapOnePH1USR_GW" {
  vpc_id = aws_vpc.CapOnePH1USR.id
}

### Route Table Configuration - Public ############
resource "aws_route_table" "CapOnePH1USR_RT_public" {
  vpc_id = aws_vpc.CapOnePH1USR.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.CapOnePH1USR_GW.id
  }
}
###### Route Table Association with public subnet 1a #####
resource "aws_route_table_association" "CapOnePH1USR_RT_PUB_1a" {
  subnet_id      = aws_subnet.CapOnePH1USR_subnet_1a.id
  route_table_id = aws_route_table.CapOnePH1USR_RT_public.id
}
##### associate the route table with public subnet 1b ######
resource "aws_route_table_association" "CapOnePH1USR_RT_PUB_1b" {
  subnet_id      = aws_subnet.CapOnePH1USR_subnet_1b.id
  route_table_id = aws_route_table.CapOnePH1USR_RT_public.id
}
# Generate Elastic IP for NAT gateway ##########
resource "aws_eip" "CapOnePH1USR_EIP" {
  depends_on = [aws_internet_gateway.CapOnePH1USR_GW]
  domain     = "vpc"
  tags = {
    Name = "CapOnePH1USR_EIP_NAT"
  }
}

##### NAT gateway for private subnets to access internet ###############
resource "aws_nat_gateway" "CapOnePH1USR_NAT_private_subnet" {
  allocation_id = aws_eip.CapOnePH1USR_EIP.id
  subnet_id     = aws_subnet.CapOnePH1USR_subnet_1a # nat should be in public subnet

  tags = {
    Name = "CapOnePH1USR_NAT_private_subnet"
  }

  depends_on = [aws_internet_gateway.CapOnePH1USR_GW]
}

#### Include NAT in Route Table ###############
resource "aws_route_table" "CapOnePH1USR_RT_PRI" {
  vpc_id = aws_vpc.CapOnePH1USR.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.CapOnePH1USR_NAT_private_subnet.id
  }
}
#### Route Table association with private subnet ###############
resource "aws_route_table_association" "CapOnePH1USR_RT_PUB_2" {
  subnet_id      = aws_subnet.CapOnePH1USR_subnet_2.id
  route_table_id = aws_route_table.CapOnePH1USR_RT_PRI.id
}


####### Applicaton Load Balancer ######################
resource "aws_lb" "CapOnePH1USR_lb" {
  name               = "CapOnePH1USR-lb-asg"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.CapOnePH1USR_SG_elb.id]
  subnets            = [aws_subnet.CapOnePH1USR_subnet_1a, aws_subnet.CapOnePH1USR_subnet_1b]
  depends_on         = [aws_internet_gateway.CapOnePH1USR_GW]
}

resource "aws_lb_target_group" "CapOnePH1USR_alb_tg" {
  name     = "CapOnePH1USR-lb-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.CapOnePH1USR.id
}

resource "aws_lb_listener" "CapOnePH1USR_FE" {
  load_balancer_arn = aws_lb.CapOnePH1USR_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.CapOnePH1USR_alb_tg.arn
  }
}

########### Security Group Configuration ##############################
resource "aws_security_group" "CapOnePH1USR_SG_elb" {
  name   = "CapOnePH1USR_SG_elb"
  vpc_id = aws_vpc.CapOnePH1USR.id

  ingress {
    description      = "Allow http request from anywhere"
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Allow https request from anywhere"
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "CapOnePH1USR_SG_ec2" {
  name   = "CapOnePH1USR_SG_ec2"
  vpc_id = aws_vpc.CapOnePH1USR.id

  ingress {
    description     = "Allow http request from Load Balancer"
    protocol        = "tcp"
    from_port       = 80 # range of
    to_port         = 80 # port numbers
    security_groups = [aws_security_group.CapOnePH1USR_SG_elb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
################### ASG with Launch template ###########################
resource "aws_launch_template" "CapOnePH1USR_ec2_Template" {
  name_prefix   = "CapOnePH1USR_ec2_Template"
  image_id      = "ami-08cdffd7dd047752c"
  instance_type = "C5.large"
  user_data     = <<-EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                echo "Demo page" > /var/www/html/index.html
              EOF

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.CapOnePH1USR_subnet_2.id
    security_groups             = [aws_security_group.CapOnePH1USR_SG_ec2.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "CapOnePH1USR-series-instance" # Name for the EC2 instances
    }
  }
}

resource "aws_autoscaling_group" "CapOnePH1USR_asg" {
  # no of instances
  desired_capacity = 1
  max_size         = 1
  min_size         = 1

  # Connect to the target group
  target_group_arns = [aws_lb_target_group.CapOnePH1USR_alb_tg.arn]

  vpc_zone_identifier = [ # EC2 instances creation in private subnet
    aws_subnet.CapOnePH1USR_subnet_2.id
  ]

  launch_template {
    id      = aws_launch_template.CapOnePH1USR_ec2_Template.id
    version = "$Latest"
  }
}
resource "aws_route53_record" "hostnameIMP" {
  zone_id = aws_route53_zone.zone_test.zone_id
  name    = "test.example.com"
  type    = "A"
  ttl     = 300
  records = [aws_alb.CapOnePH1USR_lb.dns_name]
}
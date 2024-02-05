#Creating a VPC
resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr //cidr is created in variables.tf
}

#Creating public subnets
resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.sub1_cidr //cidr have created in variables.tf
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.sub2_cidr
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

#Creating Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
}

#Creating route table and attaching it to the subnets
resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

#Attaching route table with the subnets
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.rt.id
}

#Creating Security group
resource "aws_security_group" "sg" {
    name = "websg"
    vpc_id = aws_vpc.vpc.id

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "outbound traffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "WebSG"
    }
}

#Creating a S3 bucket
resource "aws_s3_bucket" "s3bucket" {
    bucket = "vinay-terraform-bucket"
}

#Creating Ec2 Instances
resource "aws_instance" "webserver1" {
    ami = "ami-03f4878755434977f"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.sg.id]
    subnet_id = aws_subnet.sub1.id //Assigning subnet so that EC2 instances will belong to that subnet.
    user_data = file("userdata.sh") //Executing the script file after the EC2 instance is created.
}

resource "aws_instance" "webserver2" {
    ami = "ami-03f4878755434977f"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.sg.id]
    subnet_id = aws_subnet.sub2.id
    user_data = file("userdata1.sh")
}

#Creating a Load balancer to balance the traffic among both the instances
resource "aws_lb" "webserver_lb" {
    name = "webserver-lb"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.sg.id]
    subnets = [aws_subnet.sub1.id,aws_subnet.sub2.id]
    enable_deletion_protection = true

    tags = {
        Name = "webserver-loadbalancer"
    }
}

#Creating a target group through which port the traffic should pass
resource "aws_lb_target_group" "tg" {
    name = "aws-lb-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.vpc.id

    health_check {
      path = "/"
    }
}

#Attaching the target group with the instances
resource "aws_lb_target_group_attachment" "tga1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver1.id
    port = 80
}

resource "aws_lb_target_group_attachment" "tga2" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver2.id
    port = 80
}

#Attaching the target group with the load balancer
resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.webserver_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        target_group_arn = aws_lb_target_group.tg.arn
        type = "forward"
    }   
}

#Output of Load Balancer
output "loadbalancerdns" {
    value = aws_lb.webserver_lb.dns_name
}

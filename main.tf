# --- VPC Module ---
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  aws_region           = var.aws_region
}

# --- SSH Key Pair ---
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-tf-key"
  public_key = file(var.ssh_public_key_path)
}

# --- Security Group Modules ---
module "proxy_sg" {
  source       = "./modules/sg"
  project_name = var.project_name
  sg_name      = "proxy-sg"
  vpc_id       = module.vpc.vpc_id
  ingress_rules = [
    # Allow HTTP from anywhere (for Public ALB)
    { port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP" },
    # Allow SSH from your IP (replace if needed)
    { port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow SSH" }
  ]
}

module "backend_sg" {
  source       = "./modules/sg"
  project_name = var.project_name
  sg_name      = "backend-sg"
  vpc_id       = module.vpc.vpc_id
  ingress_rules = [
    # Allow traffic on port 80 from the proxy security group (for Internal ALB)
    { port = 80, protocol = "tcp", self = true, description = "Allow HTTP from Internal ALB" },
    { port = 80, protocol = "tcp", source_security_group_id = module.proxy_sg.security_group_id, description = "Allow Nginx to proxy to Internal ALB" },
    # Allow SSH from the proxy security group (for file provisioner via bastion)
    { port = 22, protocol = "tcp", source_security_group_id = module.proxy_sg.security_group_id, description = "Allow SSH from Proxy" }
  ]
}

# --- Proxy EC2 Instances ---
module "proxy_ec2" {
  source          = "./modules/ec2"
  count           = 2
  instance_name   = "${var.project_name}-proxy-${count.index + 1}"
  ami_id          = data.aws_ami.amazon_linux_2.id
  instance_type   = var.instance_type
  subnet_id       = module.vpc.public_subnet_ids[count.index]
  security_group_ids = [module.proxy_sg.security_group_id]
  key_name        = aws_key_pair.deployer.key_name
  associate_public_ip = true
  
  # Provisioner to install and configure Nginx as a reverse proxy
  provisioner_script = <<-EOT
    #!/bin/bash
    sudo yum update -y
    # CORRECT WAY TO INSTALL NGINX ON AMAZON LINUX 2
    sudo amazon-linux-extras install -y nginx1
    
    # The rest of the script can now succeed
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo 'server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://${module.internal_alb.lb_dns_name};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }' | sudo tee /etc/nginx/conf.d/reverse_proxy.conf
    sudo systemctl restart nginx
  EOT
}

# --- Backend EC2 Instances ---
module "backend_ec2" {
  source          = "./modules/ec2"
  count           = 2
  instance_name   = "${var.project_name}-backend-${count.index + 1}"
  ami_id          = data.aws_ami.amazon_linux_2.id
  instance_type   = var.instance_type
  subnet_id       = module.vpc.private_subnet_ids[count.index]
  security_group_ids = [module.backend_sg.security_group_id]
  key_name        = aws_key_pair.deployer.key_name

  # File provisioner to copy app files
  source_file      = "${path.root}/app/index.html"
  destination_file = "/tmp/index.html"

  # Connection block to use the proxy as a bastion host
  bastion_host = module.proxy_ec2[count.index].public_ip
  
  # Provisioner to install a simple web server (Apache)
  provisioner_script = <<-EOT
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    # Add instance IP to the content for demonstration
    IP=$(hostname -I | awk '{print $1}')
    sudo sed -i "s/@/$IP/" /tmp/index.html
    sudo cp /tmp/index.html /var/www/html/index.html
  EOT
}

# --- Load Balancer Modules ---
module "public_alb" {
  source             = "./modules/alb"
  lb_name            = "${var.project_name}-public-alb"
  is_internal        = false
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnet_ids
  security_groups    = [module.proxy_sg.security_group_id]
  target_instances   = module.proxy_ec2.*.id
  health_check_path  = "/health"
}

module "internal_alb" {
  source             = "./modules/alb"
  lb_name            = "${var.project_name}-internal-alb"
  is_internal        = true
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.private_subnet_ids
  security_groups    = [module.backend_sg.security_group_id]
  target_instances   = module.backend_ec2.*.id
}

# --- Data Source for AMI ---
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- Local-exec Provisioner to output IPs ---
resource "null_resource" "output_ips" {
  depends_on = [module.proxy_ec2]

  provisioner "local-exec" {
    command = <<-EOT
      echo "# Public IPs of Proxy Servers" > all-ips.txt
      %{ for i, ip in module.proxy_ec2.*.public_ip ~}
      echo "public-ip${i + 1}  ${ip}" >> all-ips.txt
      %{ endfor ~}
    EOT
  }
}
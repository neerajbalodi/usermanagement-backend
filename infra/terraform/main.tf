# ---------------------------------------------------------------
# Day 1 infrastructure: 3 EC2 instances in the default VPC
#   um-frontend (Angular)  -> port 4200 open to everyone
#   um-backend  (Spring)   -> port 8080 open to everyone
#   um-db       (Postgres) -> port 5432 open ONLY to the backend SG
# ---------------------------------------------------------------

# --- Look-ups ---------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# Latest Ubuntu 24.04 LTS image published by Canonical
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Public IP of the machine running Terraform (the Jenkins server),
# so that only it (and optionally you) can SSH into the servers.
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  runner_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  ssh_cidrs   = compact([local.runner_cidr, var.extra_ssh_cidr])
}

# --- SSH key pair (generated, so nobody has to create one by hand) ---

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/generated/${var.name_prefix}-key.pem"
  file_permission = "0600"
}

# --- Security groups ----------------------------------------------

resource "aws_security_group" "frontend" {
  name        = "${var.name_prefix}-frontend-sg"
  description = "Angular frontend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_cidrs
  }

  ingress {
    description = "Angular dev server"
    from_port   = 4200
    to_port     = 4200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-frontend-sg" }
}

resource "aws_security_group" "backend" {
  name        = "${var.name_prefix}-backend-sg"
  description = "Spring Boot backend"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_cidrs
  }

  # The browser calls the API directly, so 8080 must be public
  ingress {
    description = "Spring Boot API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-backend-sg" }
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "PostgreSQL database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_cidrs
  }

  # Only servers in the backend security group may reach PostgreSQL
  ingress {
    description     = "PostgreSQL from backend only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-db-sg" }
}

# --- EC2 instances -------------------------------------------------

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.db.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.name_prefix}-db", Role = "db" }
}

resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.backend.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.name_prefix}-backend", Role = "backend" }
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.frontend.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = { Name = "${var.name_prefix}-frontend", Role = "frontend" }
}

# --- Hand-off to Ansible: inventory written from the real IPs -------

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    db_public_ip       = aws_instance.db.public_ip
    db_private_ip      = aws_instance.db.private_ip
    backend_public_ip  = aws_instance.backend.public_ip
    frontend_public_ip = aws_instance.frontend.public_ip
    vpc_cidr           = data.aws_vpc.default.cidr_block
    ssh_key_path       = abspath(local_sensitive_file.private_key.filename)
  })
}

# ---------------------------------------------------------------
# Day 3: Redis cache server
#   um-redis -> port 6379 open ONLY to the backend security group
#   (same pattern as the database). Redis itself is set up by Ansible.
#   In production you would use the managed service ElastiCache instead.
# ---------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-redis-sg"
  description = "Redis cache"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_cidrs
  }

  # Only servers in the backend security group may reach Redis
  ingress {
    description     = "Redis from backend only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-redis-sg" }
}

resource "aws_instance" "redis" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.redis_instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.redis.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  # Keep the server when Ubuntu publishes a newer image (don't recreate it)
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name_prefix}-redis", Role = "redis" }
}

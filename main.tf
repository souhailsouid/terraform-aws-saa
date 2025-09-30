resource "aws_security_group" "web_sg" {
  name        = "ec2-web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = var.vpc_id # à récupérer (default VPC ou ton module VPC)

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["194.98.67.99/32"]
  }

 ingress {
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_groups          = [aws_security_group.alb_sg.id]
  description              = "HTTP from ALB only"
}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-iam-readonly-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}


resource "aws_instance" "web" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id_a # public subnet
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = "myArchitectureKeyPair"

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # Web
    yum update -y
    yum install -y httpd awscli xfsprogs
    systemctl enable --now httpd
    echo "Hello from Terraform EC2" > /var/www/html/index.html

    # === Préparer /data sur /dev/xvdb ===
    DEVICE=/dev/xvdb
    MOUNT=/data

    # Attendre que le device apparaisse (après l'attachement)
    for i in {1..20}; do
      if [ -b "$DEVICE" ]; then break; fi
      sleep 3
    done

    # Créer le FS s'il n'existe pas encore
    if ! file -s $DEVICE | grep -qi 'filesystem'; then
      mkfs -t xfs $DEVICE
    fi

    mkdir -p $MOUNT
    # Monter et rendre persistant (idempotent)
    if ! grep -q "$DEVICE" /etc/fstab; then
      echo "$DEVICE  $MOUNT  xfs  defaults,nofail  0  2" >> /etc/fstab
    fi
    mount -a

    echo "data volume ready: $(date)" > $MOUNT/health.txt
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "saa-dev-ec2"
    TTL  = "1h"   # ← ici
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-iam-readonly-profile"
  role = aws_iam_role.ec2_role.name
}


# === EBS supplémentaire (8 Go, gp3, chiffré) ===
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web.availability_zone
  size              = 8
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "saa-dev-ec2-data", TTL = "1h" }
}

# Attacher le volume /dev/xvdb à l'instance
resource "aws_volume_attachment" "data_attach" {
  device_name = "/dev/xvdb"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}

# Nouveau SG pour l'ALB (ouvre HTTP au monde)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP from the Internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}


resource "aws_instance" "web2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id_b
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = "myArchitectureKeyPair"

  # même user_data que web (serveur httpd)
  user_data = aws_instance.web.user_data

  tags = {
    Name = "saa-dev-ec2-2"
    TTL  = "1h"
  }
}

# alb 
# Application Load Balancer
resource "aws_lb" "app" {
  name               = "demo-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [var.subnet_id_a, var.subnet_id_b]  # 2 subnets publics (AZ différentes)
  tags = { Name = "demo-alb", TTL = "1h" }
}

# Target Group (instances, HTTP:80)
resource "aws_lb_target_group" "tg" {
  name     = "demo-tg-alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }

  tags = { Name = "demo-tg-alb" }
}

# Attacher les 2 EC2 au Target Group
resource "aws_lb_target_group_attachment" "tg_web1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_web2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web2.id
  port             = 80
}

# Listener HTTP 80 → forward vers le TG
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_lb_listener_rule" "error_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 5

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found - Custom Error"
      status_code  = "404"
    }
  }

  condition {
    path_pattern {
      values = ["/error"]
    }
  }
}

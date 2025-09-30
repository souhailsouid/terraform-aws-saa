resource "aws_security_group" "web_sg" {
  name        = "ec2-web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = "vpc-01c48ae5d78b50401" # à récupérer (default VPC ou ton module VPC)

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["194.98.67.99/32"]
  }

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
  ami                    = "ami-03601e822a943105f" # Amazon Linux 2 dans ta région
  instance_type          = "t3.nano"
  subnet_id              = "subnet-0a70919ea988bc34e" # public subnet
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

  tags = { Name = "saa-dev-ec2" }
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
  tags              = { Name = "saa-dev-ec2-data" }
}

# Attacher le volume /dev/xvdb à l'instance
resource "aws_volume_attachment" "data_attach" {
  device_name = "/dev/xvdb"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
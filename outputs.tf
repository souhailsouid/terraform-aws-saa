output "web_public_ip" {
  description = "L'adresse IP publique de l'instance EC2"
  value       = aws_instance.web.public_ip
}

output "web_public_dns" {
  description = "Le nom DNS public de l'instance EC2"
  value       = aws_instance.web.public_dns
}

output "instance_id" {
  description = "L'ID de l'instance EC2"
  value       = aws_instance.web.id
}

output "security_group_id" {
  description = "L'ID du groupe de sécurité"
  value       = aws_security_group.web_sg.id
}
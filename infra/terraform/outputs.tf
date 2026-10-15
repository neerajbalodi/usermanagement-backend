output "frontend_url" {
  description = "Open this in the browser"
  value       = "http://${aws_instance.frontend.public_ip}:4200"
}

output "backend_url" {
  description = "Users API"
  value       = "http://${aws_instance.backend.public_ip}:8080/api/users"
}

output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}

output "db_public_ip" {
  value = aws_instance.db.public_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "ssh_key_file" {
  description = "Private key for: ssh -i <file> ubuntu@<public ip>"
  value       = abspath(local_sensitive_file.private_key.filename)
}

output "instance_public_ip" {
  value = aws_instance.python_app.public_ip
}

output "rsa_key" {
  value = local_file.private_key.filename
}
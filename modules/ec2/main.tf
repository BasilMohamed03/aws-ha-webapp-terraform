# In modules/ec2/main.tf

resource "aws_instance" "main" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip
  
  tags = { Name = var.instance_name }

  # A single connection block for all provisioners
  connection {
    type                = "ssh"
    user                = "ec2-user"
    private_key         = file("~/.ssh/tf-key")
    # This logic correctly handles both public and private instances
    host                = var.bastion_host != null ? self.private_ip : self.public_ip
    bastion_host        = var.bastion_host
    bastion_user        = "ec2-user"
    bastion_private_key = file("~/.ssh/tf-key")
  }

  # First, the file provisioner runs.
  # It will only attempt to run if a source file is provided.
  # on_failure = "continue" tells Terraform not to error out on the proxy instances
  # where var.source_file is intentionally null.
  provisioner "file" {
    source      = var.source_file
    destination = var.destination_file
    on_failure  = "continue"
  }

  # Second, the remote-exec provisioner runs, guaranteed to be AFTER the file is uploaded.
  provisioner "remote-exec" {
    inline = [
      var.provisioner_script
    ]
  }
}
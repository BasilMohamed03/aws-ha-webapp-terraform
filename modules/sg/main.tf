resource "aws_security_group" "main" {
  name        = "${var.project_name}-${var.sg_name}"
  description = "Security group for ${var.sg_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = try(ingress.value.description, "Rule managed by Terraform")
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      self        = try(ingress.value.self, false)
      cidr_blocks = try(ingress.value.cidr_blocks, null)
      
      # This is the corrected line with the proper attribute name "security_groups"
      security_groups = can(ingress.value.source_security_group_id) ? [ingress.value.source_security_group_id] : null
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.sg_name}"
  }
}

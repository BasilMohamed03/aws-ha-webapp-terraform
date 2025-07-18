resource "aws_lb" "main" {
  name               = var.lb_name
  internal           = var.is_internal
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets
  tags = { Name = var.lb_name }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.lb_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = var.health_check_path
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
  tags = { Name = "${var.lb_name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group_attachment" "main" {
  count            = length(var.target_instances)
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = var.target_instances[count.index]
  port             = 80
}
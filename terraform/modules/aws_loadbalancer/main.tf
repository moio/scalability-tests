resource "aws_lb" "public-lb" {
  name               = "${var.subdomain}-public-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "server-443" {
  name     = "${var.subdomain}-443"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 10
    timeout             = 6
    path                = "/healthz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = ""
  }

  stickiness {
    type    = "source_ip"
    enabled = false
  }
}

resource "aws_lb_target_group" "server-80" {
  name     = "${var.subdomain}-80"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    interval            = 10
    timeout             = 6
    path                = "/healthz"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399"
  }

  stickiness {
    type    = "source_ip"
    enabled = false
  }
}

resource "aws_lb_listener" "server-port_443" {
  load_balancer_arn = aws_lb.public-lb.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server-443.arn
  }
}

resource "aws_lb_listener" "server-port_80" {
  load_balancer_arn = aws_lb.public-lb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server-80.arn
  }
}

#############################
### Create Public Rancher DNS
#############################
data "aws_route53_zone" "dns_zone" {
  count = var.use_route53 ? 1 : 0
  name  = var.domain
}

resource "aws_route53_record" "public" {
  count   = var.use_route53 ? 1 : 0
  zone_id = data.aws_route53_zone.dns_zone.0.zone_id
  name    = "${var.subdomain}.${var.domain}"
  type    = "CNAME"
  ttl     = 30
  records = [aws_lb.public-lb.dns_name]
}

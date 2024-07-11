# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Subnets
resource "aws_subnet" "main" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}

# Route Table Associations
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main[0].id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.main[1].id
  route_table_id = aws_route_table.main.id
}

# Security Group
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
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

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "yogesh_ecs_task_exe_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "yogesh-ecs-cluster"
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "reactjs" {
  family                   = "yogesh_reactjs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "512"
  cpu                      = "256"

  container_definitions = jsonencode([{
    name  = "yogesh_reactjs-container"
    image = "yogeshnimbalkar07/myreactjsapp:reactjs" # Docker Hub image for ReactJS
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_task_definition" "strapi" {
  family                   = "yogesh_strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  memory                   = "512"
  cpu                      = "256"

  container_definitions = jsonencode([{
    name  = "yogesh_strapi-container"
    image = "yogeshnimbalkar07/strapi:1.0.0" # Docker Hub image for Strapi
    portMappings = [{
      containerPort = 1337
      hostPort      = 1337
    }]
    environment = [
      {
        name  = "DATABASE_CLIENT"
        value = "sqlite"
      },
      {
        name  = "DATABASE_FILENAME"
        value = "./.tmp/data.db"
      },
      {
        name  = "JWT_SECRET"
        value = "your-jwt-secret"
      },
      {
        name  = "ADMIN_JWT_SECRET"
        value = "your-admin-jwt-secret"
      },
      {
        name  = "NODE_ENV"
        value = "production"
      }
    ]
  }])
}

# ECS Services
resource "aws_ecs_service" "reactjs" {
  name            = "yogesh_reactjs-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.reactjs.arn
  desired_count   = 1

  network_configuration {
    subnets         = aws_subnet.main[*].id
    security_groups = [aws_security_group.main.id]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 1
  }
}

resource "aws_ecs_service" "strapi" {
  name            = "yogesh_strapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1

  network_configuration {
    subnets         = aws_subnet.main[*].id
    security_groups = [aws_security_group.main.id]
    assign_public_ip = true
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 1
  }
}

data "aws_availability_zones" "available" {}
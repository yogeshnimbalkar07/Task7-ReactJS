output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.strapi.arn
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "ecs_service_name" {
  value = aws_ecs_service.strapi.name
}

output "ecs_service_task_definition" {
  value = aws_ecs_service.strapi.task_definition
}
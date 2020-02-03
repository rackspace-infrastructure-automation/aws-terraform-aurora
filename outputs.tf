output "cluster_endpoint_address" {
  description = "The DNS address of the RDS cluster"
  value       = aws_rds_cluster.db_cluster.endpoint
}

output "cluster_endpoint_port" {
  description = "The port of the RDS cluster"
  value       = aws_rds_cluster.db_cluster.port
}

output "cluster_endpoint_reader" {
  description = " A read-only endpoint for the Aurora cluster"
  value       = aws_rds_cluster.db_cluster.reader_endpoint
}

# Since terraform will build across all modules synchronously, read replicas could potentially be created
# after the master cluster, but before the master nodes.  To prevent this, we placed a dependency on
# the output, preventing the replica module from learning the master cluster ID until all nodes have
# built successfully.
output "cluster_id" {
  description = "The DB Cluster identifier"
  value       = aws_rds_cluster.db_cluster.id

  depends_on = [aws_rds_cluster_instance.cluster_instance]
}

output "db_instance" {
  description = "The DB instance identifier"
  value       = aws_rds_cluster_instance.cluster_instance.*.id
}

output "monitoring_role" {
  description = "The IAM role used for Enhanced Monitoring"
  value       = local.monitoring_role_arn
}

output "option_group" {
  description = "The Option Group used by the DB Instance"
  value       = local.option_group
}

output "parameter_group" {
  description = "The Parameter Group used by the DB Instance"
  value       = local.parameter_group
}

output "subnet_group" {
  description = "The DB Subnet Group used by the DB Instance"
  value       = local.subnet_group
}


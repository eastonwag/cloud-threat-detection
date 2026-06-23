output "state_machine_arn" {
  description = "ARN of the incident response Step Functions state machine"
  value       = aws_sfn_state_machine.incident_response.arn
}

output "quarantine_sg_id" {
  description = "ID of the quarantine security group applied to isolated EC2 instances"
  value       = aws_security_group.quarantine.id
}

output "isolate_ec2_function_arn" {
  description = "ARN of the isolate-ec2 Lambda function"
  value       = aws_lambda_function.isolate_ec2.arn
}

output "revoke_credentials_function_arn" {
  description = "ARN of the revoke-credentials Lambda function"
  value       = aws_lambda_function.revoke_credentials.arn
}

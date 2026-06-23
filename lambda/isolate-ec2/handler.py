import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')


def handler(event, context):
    """
    Isolates an EC2 instance by replacing its security groups
    with a pre-created quarantine security group (no inbound/outbound rules).
    """
    try:
        instance_id = event['detail']['resource']['instanceDetails']['instanceId']
        quarantine_sg_id = os.environ['QUARANTINE_SG_ID']

        logger.info(f"Isolating instance {instance_id}")

        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[quarantine_sg_id]
        )

        ec2.create_tags(
            Resources=[instance_id],
            Tags=[
                {'Key': 'SecurityStatus', 'Value': 'QUARANTINED'},
                {'Key': 'QuarantineReason', 'Value': 'GuardDuty HIGH finding - automated response'}
            ]
        )

        logger.info(f"Instance {instance_id} successfully quarantined")
        return {'status': 'success', 'instance_id': instance_id}

    except Exception as e:
        logger.error(f"Failed to isolate instance: {str(e)}")
        raise

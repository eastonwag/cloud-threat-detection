import boto3
import logging
import json
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client('iam')

DENY_ALL_POLICY = json.dumps({
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Deny",
        "Action": "*",
        "Resource": "*"
    }]
})


def handler(event, context):
    """
    Attaches a deny-all inline policy to a flagged IAM entity.
    Does not delete the user/role — preserves forensic state.
    """
    try:
        principal = event['detail']['resource']['accessKeyDetails']
        user_name = principal.get('userName')

        if not user_name or user_name == 'ANONYMOUS_PRINCIPAL':
            logger.warning("No valid IAM user to revoke — skipping")
            return {'status': 'skipped', 'reason': 'no_valid_principal'}

        policy_name = f"SECURITY-DENY-ALL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"

        logger.info(f"Revoking credentials for user: {user_name}")

        iam.put_user_policy(
            UserName=user_name,
            PolicyName=policy_name,
            PolicyDocument=DENY_ALL_POLICY
        )

        logger.info(f"Deny-all policy applied to {user_name}")
        return {'status': 'success', 'user_name': user_name, 'policy_name': policy_name}

    except Exception as e:
        logger.error(f"Failed to revoke credentials: {str(e)}")
        raise

import boto3
import os


def handler(event, context):
    print(event)

    default_region = os.environ.get("AWS_REGION", "us-east-1")
    retain_days = int(os.environ.get("RETAIN_DAYS", "30"))
    loggroup_name_match = os.environ.get("LOGGROUP_NAME_MATCH", "")
    if not loggroup_name_match:
        return "CloudWatchLogRetention.Error: LOGGROUP_NAME_MATCH not set"

    session = boto3.Session()
    client = session.client("ec2", region_name=default_region)
    regions = client.describe_regions()["Regions"]

    for region_dict in regions:
        region = region_dict["RegionName"]
        print("Region:", region)

        logs = session.client("logs", region_name=region)
        log_groups = logs.describe_log_groups(logGroupNamePrefix=loggroup_name_match)

        for log_group in log_groups["logGroups"]:
            log_group_name = log_group["logGroupName"]
            print("log_group_name:", log_group_name)

            if loggroup_name_match not in log_group_name:
                continue

            if (
                "retentionInDays" in log_group
                and log_group["retentionInDays"] == retain_days
            ):
                print(region, log_group_name, log_group["retentionInDays"], "days")
            else:
                print(region, log_group_name, retain_days, "days **PUT**")
                logs.put_retention_policy(
                    logGroupName=log_group_name,
                    retentionInDays=retain_days,
                )

    return "CloudWatchLogRetention.Success"


if __name__ == "__main__":
    handler(None, None)

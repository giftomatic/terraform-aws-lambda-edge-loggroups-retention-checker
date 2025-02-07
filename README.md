## Lambda Edge Loggroups Retention Checker

As https://renaghan.com/posts/lambda-cloudwatch-log-retain-manager/ wrote:

> it is very common to have services, applications, and worldwide CloudFront
> Edge Locations (especially Lambda@Edge) creating CloudWatch Log Groups in
> regions across the world. By default new CloudWatch Log Groups have retention
> set to Never, which is never what I want.

So this is a terraform module that wraps the suggested python script to set the
retention policy of all loggroups to a specified value.

### Usage

```hcl
module "loggroups_retention" {
  source         = "github.com/giftomatic/terraform-aws-lambda-edge-loggroups-retention-checker"
  name           = "loggroups-retention-checker"
  retention_days = 30
}
```

### Alternatives

- https://github.com/Codzs-Architecture/terraform-aws-cloudwatch-log-retention

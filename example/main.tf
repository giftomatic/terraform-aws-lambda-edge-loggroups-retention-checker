
module "loggroups_retention_check" {
  source              = "../"
  name                = "loggroups"
  loggroup_name_match = "/aws/lambda/us-east-1.test"
}

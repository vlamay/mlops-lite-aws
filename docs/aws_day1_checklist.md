Создать IAM user mlops-lite-local (programmatic) и получить keys.

В терминале:

aws configure
aws sts get-caller-identity
aws s3 ls s3://mlops-lite-tfstate-vlad-20260124


Terraform:

make tf-init
make tf-plan
make tf-apply
terraform -chdir=infra/terraform output


API smoke:

API_URL="$(terraform -chdir=infra/terraform output -raw api_invoke_url)"
curl -sS -X POST "$API_URL/predict" -H "content-type: application/json" -d @service/contract_tests/request_example.json | cat


Log retention check:

aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/" \
  --query "logGroups[?contains(logGroupName, 'mlops')].[logGroupName, retentionInDays]" --output table

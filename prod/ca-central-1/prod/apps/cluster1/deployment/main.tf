terraform {
  backend "local" {
    path = "../../../../../../../tf_state/prod/ca-central-1/prod/apps/cluster1/deployment/terraform.tfstate"
  }
}

module "deployment" {
  source = "../../../../../../modules/apps/deployment"

  cluster_name = "cluster1"

  pipelines = {
    webapp1 = {},
    tcpapp1 = {}
  }
}

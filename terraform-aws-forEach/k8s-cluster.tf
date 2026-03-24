#---- iam role and policy ----#
resource "aws_iam_role" "master" {
  name = "${var.env}-eks-master"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

#------------  policy for master iam role -----------#

resource "aws_iam_role_policy_attachment" "amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}


resource "aws_iam_role_policy_attachment" "amazon_eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master.name
}


resource "aws_iam_role_policy_attachment" "amazon_eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.master.name
}


#-----------  worker iam role  -----------#

resource "aws_iam_role" "worker" {
  name = "${var.env}-eks-worker"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        #Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

#------------  policy for worker iam role -----------#
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}


resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker.name
}

#---- eks cluster ----#

resource "aws_eks_cluster" "eks" {
  name     = "${var.env}-my-cluster"
  role_arn = aws_iam_role.master.arn
  version  = "1.29"

  vpc_config {
    subnet_ids = concat(
      values(aws_subnet.public-subnet)[*].id,
      values(aws_subnet.private-subnet)[*].id
    )
    #subnet_ids = values(aws_subnet.public-subnet)[*].id    # only public subnets

    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.amazon_eks_service_policy,
    aws_iam_role_policy_attachment.amazon_eks_vpc_resource_controller,
    #aws_iam_role_policy_attachment.amazon_elastic_container_registry
  ]

}

#---- eks node group ----#
resource "aws_eks_node_group" "nodes_general" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "nodes_general"
  node_role_arn   = aws_iam_role.worker.arn

  subnet_ids = values(aws_subnet.private-subnet)[*].id

  instance_types = ["t3.small"]
  capacity_type  = "ON_DEMAND"
  disk_size      = 20

#    remote_access {
#     ec2_ssh_key = "your-key-pear-name-from-aws"
#   }

  labels = {
    env = "dev"
  }

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  update_config {
    max_unavailable = 1
  }


  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
  ]
}
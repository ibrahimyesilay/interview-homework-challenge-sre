import pulumi
import pulumi_kubernetes as k8s

from pulumi_kubernetes.apps.v1 import Deployment, DeploymentSpecArgs
from pulumi_kubernetes.core.v1 import Service, ServiceSpecArgs, ServicePortArgs, PodTemplateSpecArgs, PodSpecArgs, ContainerArgs
from pulumi_kubernetes.meta.v1 import ObjectMetaArgs, LabelSelectorArgs


def deploy_nginx(namespace: str = "orcrist", replicas: int = 3):
    labels = {"app": "nginx"}

    dep = Deployment(
        "nginx-deployment",
        metadata=ObjectMetaArgs(name="nginx-deployment", namespace=namespace, labels=labels),
        spec=DeploymentSpecArgs(
            replicas=replicas,
            selector=LabelSelectorArgs(match_labels=labels),
            template=PodTemplateSpecArgs(
                metadata=ObjectMetaArgs(labels=labels),
                spec=PodSpecArgs(
                    containers=[
                        ContainerArgs(
                            name="nginx",
                            image="nginx:latest",
                            ports=[{"containerPort": 80}],
                        )
                    ]
                ),
            ),
        ),
    )

    svc = Service(
        "nginx-service",
        metadata=ObjectMetaArgs(name="nginx-service", namespace=namespace),
        spec=ServiceSpecArgs(
            type="ClusterIP",
            selector=labels,
            ports=[ServicePortArgs(port=80, target_port=80)],
        ),
    )

    return dep, svc
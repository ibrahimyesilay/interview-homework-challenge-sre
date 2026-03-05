from pulumi import ResourceOptions
from pulumi_kubernetes.core.v1 import Pod, PodSpecArgs, ContainerArgs
from pulumi_kubernetes.meta.v1 import ObjectMetaArgs


def create_pod(name: str, namespace: str, image: str, deps, command=None, args=None):
    containers = [
        ContainerArgs(
            name=name,
            image=image,
            command=command,
            args=args,
        )
    ]

    return Pod(
        name,
        metadata=ObjectMetaArgs(
            name=name,
            namespace=namespace,
        ),
        spec=PodSpecArgs(containers=containers),
        opts=ResourceOptions(
            depends_on=deps,
            delete_before_replace=True,
            replace_on_changes=["spec"],
        ),
    )


def create_example_pods(deps_by_ns):
    create_pod(
        name="pod-example-integration",
        namespace="integration",
        image="busybox:latest",
        deps=deps_by_ns["integration"],
        command=["sh", "-c"],
        args=["echo hello from integration; sleep 3600"],
    )

    create_pod(
        name="pod-example-monitoring",
        namespace="monitoring",
        image="busybox:latest",
        deps=deps_by_ns["monitoring"],
        command=["sh", "-c"],
        args=["echo hello from monitoring; sleep 3600"],
    )

    create_pod(
        name="pod-example-orcrist",
        namespace="orcrist",
        image="busybox:latest",
        deps=deps_by_ns["orcrist"],
        command=["sh", "-c"],
        args=["echo hello from orcrist; sleep 3600"],
    )

    create_pod(
        name="pod-nginx-tools",
        namespace="tools",
        image="nginx:latest",
        deps=deps_by_ns["tools"],
    )
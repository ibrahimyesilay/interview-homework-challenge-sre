import pulumi
import pulumi_kubernetes as k8s
from pulumi_kubernetes.core.v1 import Namespace
from pulumi_kubernetes.meta.v1 import ObjectMetaArgs


def create_namespaces(names=None):
    """
    Create required namespaces.
    """
    if names is None:
        names = ["collector", "integration", "orcrist", "monitoring", "tools"]

    created = {}
    for ns in names:
        created[ns] = Namespace(
            f"ns-{ns}",
            metadata=ObjectMetaArgs(name=ns),
        )

    return created
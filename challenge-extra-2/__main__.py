from infra.config import get_config
from infra.namespaces import create_namespaces
from infra.nginx import deploy_nginx
from infra.pods import create_example_pods
from infra.exports import export_basic

cfg = get_config()

# 1) Namespaces
ns = create_namespaces(cfg.namespaces)

# 2) Explicit dependency map
deps_by_ns = {
    "collector": [ns["collector"]],
    "integration": [ns["integration"]],
    "orcrist": [ns["orcrist"]],
    "monitoring": [ns["monitoring"]],
    "tools": [ns["tools"]],
}

# 3) Nginx deployment + service in orcrist
deploy_nginx(namespace="orcrist", replicas=3)

# 4) Example pods, explicitly dependent on namespaces
create_example_pods(deps_by_ns)

# 5) Outputs
export_basic(cfg.namespaces, cfg.nginx_image, cfg.nginx_namespace, cfg.nginx_service_name)
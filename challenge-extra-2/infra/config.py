from dataclasses import dataclass

@dataclass(frozen=True)
class AppConfig:
    namespaces: list[str]
    nginx_namespace: str
    nginx_name: str
    nginx_replicas: int
    nginx_image: str
    nginx_service_name: str
    nginx_service_port: int
    nginx_container_port: int

def get_config() -> AppConfig:
    return AppConfig(
        namespaces=["collector","integration","orcrist","monitoring","tools"],
        nginx_namespace="orcrist",
        nginx_name="nginx-deployment",
        nginx_replicas=3,
        nginx_image="nginx:latest",
        nginx_service_name="nginx-service",
        nginx_service_port=80,
        nginx_container_port=80,
    )

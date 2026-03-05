import pulumi

def export_basic(namespaces, nginx_image, nginx_ns, nginx_svc_name):
    pulumi.export("namespaces", namespaces)
    pulumi.export("nginx_image", nginx_image)
    pulumi.export("nginx_service", f"{nginx_ns}/{nginx_svc_name}")

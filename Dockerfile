FROM gitea/act_runner:latest

# Установка базовых утилит
RUN apk add --no-cache curl nodejs npm unzip openssh-client

# --- Установка kubectl ---
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && mkdir -p /root/.kube

# --- Установка Terraform ---
COPY terraform_1.14.1_linux_amd64.zip /tmp/terraform.zip
RUN unzip /tmp/terraform.zip -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/terraform \
    && rm /tmp/terraform.zip

# --- Установка ПРОВАЙДЕРА bpg/proxmox ---
RUN curl -L -o /tmp/proxmox-provider.zip \
    "https://github.com/bpg/terraform-provider-proxmox/releases/download/v0.56.1/terraform-provider-proxmox_0.56.1_linux_amd64.zip"

RUN unzip /tmp/proxmox-provider.zip -d /tmp/ \
    && mkdir -p /root/.terraform.d/plugins/registry.terraform.io/bpg/proxmox/0.56.1/linux_amd64/ \
    && mv /tmp/terraform-provider-proxmox_v0.56.1 /root/.terraform.d/plugins/registry.terraform.io/bpg/proxmox/0.56.1/linux_amd64/ \
    && chmod +x /root/.terraform.d/plugins/registry.terraform.io/bpg/proxmox/0.56.1/linux_amd64/terraform-provider-proxmox_v0.56.1 \
    && rm /tmp/proxmox-provider.zip

# --- Установка Ansible ---
RUN apk add --no-cache ansible python3 py3-pip

# Проверяем установку
RUN terraform -version && which ssh-keygen && ansible --version

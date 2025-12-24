🚀 Автоматический деплой Kubernetes кластера на Proxmox
https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white
https://img.shields.io/badge/Proxmox-E57000?style=flat&logo=proxmox&logoColor=white
https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white

Автоматическая система развертывания Kubernetes кластера на Proxmox VE с использованием Terraform и CI/CD.

📁 Структура проекта
text
terrafotm_k8s_home/
├── .gitea/workflows/deploy-master.yml    # CI/CD пайплайн
├── config.auto.tfvars                     # Основная конфигурация
├── variables.tf                          # Общие переменные Terraform
├── auto_find_ip_range.sh                 # Скрипт поиска свободных IP
├── main.tf                               # Главный файл Terraform
├── template/                             # Шаблон ВМ
│   ├── main.tf                          # Terraform для шаблона
│   ├── variables.tf                     # Переменные шаблона
│   └── outputs                          # Выводы шаблона
├── master/                               # Master нода
│   ├── main.tf                          # Terraform для master
│   └── variables.tf                     # Переменные master
└── worker/                               # Worker ноды
    ├── main.tf                          # Terraform для workers
    └── variables.tf                     # Переменные workers
🎯 Быстрый старт
1. Настройка Proxmox API токена
На Proxmox хосте выполните:

bash
# Создание пользователя для Terraform
pveum user add terraform-prov@pve --password <secure_password>

# Создание роли с минимальными правами
pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"

# Назначение прав
pveum aclmod / -user terraform-prov@pve -role TerraformProv

# Создание API токена
pveum token add terraform-token --user terraform-prov@pve --privsep 0
Запишите полученные данные:

Token ID: terraform-prov@pve!terraform-token

Token Secret: сгенерированный UUID

2. Настройка секретов в CI/CD
Добавьте следующие секреты в ваш Git сервер (Gitea/GitHub/GitLab):

Для Gitea:
text
Settings → Secrets → New Secret
Для GitHub:
text
Settings → Secrets and variables → Actions → New repository secret
Необходимые секреты:
Название секрета	Описание	Пример значения
PM_API_URL	URL Proxmox API	https://192.168.0.223:8006/api2/json
PM_API_TOKEN_ID	ID API токена	terraform-prov@pve!terraform-token
PM_API_TOKEN_SECRET	Секрет API токена	xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
PROXMOX_SSH_USERNAME	SSH пользователь Proxmox	root
PROXMOX_SSH_PASSWORD	SSH пароль Proxmox	ваш_пароль
PROXMOX_SSH_PUBKEY	Публичный SSH ключ для ВМ	ssh-ed25519 AAAAC3...
3. Создание SSH ключа на Proxmox
bash
# Создаем SSH ключ на Proxmox хосте
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q

# Копируем публичный ключ для секрета PROXMOX_SSH_PUBKEY
cat /root/.ssh/id_ed25519.pub
# Копируйте весь вывод включая "ssh-ed25519 AAA... user@host"
4. Настройка конфигурационного файла
Отредактируйте config.auto.tfvars под вашу инфраструктуру:

hcl
# Основные настройки
target_node = "pve-k8s"  # Имя ноды Proxmox

# Шаблон ВМ
template_vmid = 9001

# Кластер Kubernetes
cluster_config = {
  masters_count = 1        # Количество master нод
  workers_count = 2        # Количество worker нод
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
}

# Диапазоны VM ID
vmid_ranges = {
  masters = { start = 2000, end = 2009 }  # Master ноды: 2000-2009
  workers = { start = 2100, end = 2109 }  # Worker ноды: 2100-2109
}

# Спецификации ВМ
vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 4096    # 4GB RAM
    disk_size_gb       = 30      # 30GB диск
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048    # 2GB RAM
    disk_size_gb       = 20      # 20GB диск
    disk_storage       = "local-lvm"
    disk_iothread      = true
    cloudinit_storage  = "local-lvm"
  }
}

# Сетевая конфигурация
network_config = {
  subnet       = "192.168.0.0/24"   # Ваша подсеть
  gateway      = "192.168.0.1"      # Ваш шлюз
  dns_servers  = ["8.8.8.8", "1.1.1.1"]  # DNS серверы
  bridge       = "vmbr0"            # Сетевой мост Proxmox
}

# Cloud-init настройки
cloud_init = {
  user           = "ubuntu"          # Пользователь по умолчанию
  search_domains = ["home.lab"]     # Домены поиска
}

# Настройки шаблона
template_specs = {
  cpu_cores     = 2
  cpu_sockets   = 1
  memory_mb     = 2048
  disk_size_gb  = 12
  disk_iothread = true
}

# Хранилища
storage_iso = "local"      # Хранилище для ISO образов
storage_vm  = "local-lvm"  # Хранилище для дисков ВМ

# Автоподбор IP (заполняется workflow)
static_ip_base = 100
5. Настройка Workflow (опционально)
Если используете другой CI/CD, настройте переменные окружения:

yaml
env:
  TF_VAR_pm_api_url: ${{ secrets.PM_API_URL }}
  TF_VAR_pm_api_token_id: ${{ secrets.PM_API_TOKEN_ID }}
  TF_VAR_pm_api_token_secret: ${{ secrets.PM_API_TOKEN_SECRET }}
  TF_VAR_proxmox_ssh_username: ${{ secrets.PROXMOX_SSH_USERNAME }}
  TF_VAR_proxmox_ssh_password: ${{ secrets.PROXMOX_SSH_PASSWORD }}
  TF_VAR_ssh_public_key: ${{ secrets.PROXMOX_SSH_PUBKEY }}
🚀 Запуск деплоя
Автоматический деплой (CI/CD)
bash
# Просто сделайте push в main ветку
git add .
git commit -m "Деплой кластера"
git push origin main
Ручной деплой
bash
# Инициализация Terraform
cd template && terraform init
cd ../master && terraform init
cd ../worker && terraform init

# Создание шаблона
cd template
terraform apply -auto-approve -var-file="../config.auto.tfvars" \
  -var="pm_api_url=$PM_API_URL" \
  -var="pm_api_token_id=$PM_API_TOKEN_ID" \
  -var="pm_api_token_secret=$PM_API_TOKEN_SECRET" \
  -var="ssh_public_key=$(cat /root/.ssh/id_ed25519.pub)"

# Развертывание кластера
cd ../master
terraform apply -auto-approve -var-file="../config.auto.tfvars" \
  -var="pm_api_url=$PM_API_URL" \
  -var="pm_api_token_id=$PM_API_TOKEN_ID" \
  -var="pm_api_token_secret=$PM_API_TOKEN_SECRET"

cd ../worker
terraform apply -auto-approve -var-file="../config.auto.tfvars" \
  -var="pm_api_url=$PM_API_URL" \
  -var="pm_api_token_id=$PM_API_TOKEN_ID" \
  -var="pm_api_token_secret=$PM_API_TOKEN_SECRET"
🔗 Подключение к кластеру
После успешного деплоя:

bash
# Master нода (обычно .111)
ssh -i /root/.ssh/id_ed25519 ubuntu@192.168.0.111

# Worker ноды (обычно .112, .113)
ssh -i /root/.ssh/id_ed25519 ubuntu@192.168.0.112
ssh -i /root/.ssh/id_ed25519 ubuntu@192.168.0.113
Создание алиасов для удобства
bash
# Добавьте в ~/.bashrc на Proxmox
echo "alias k-master='ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 ubuntu@192.168.0.111'" >> ~/.bashrc
echo "alias k-w1='ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 ubuntu@192.168.0.112'" >> ~/.bashrc
echo "alias k-w2='ssh -o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519 ubuntu@192.168.0.113'" >> ~/.bashrc
source ~/.bashrc
⚙️ Кастомизация
Изменение количества нод
hcl
# В config.auto.tfvars измените:
cluster_config = {
  masters_count = 1    # Увеличьте для High Availability
  workers_count = 3    # Добавьте больше worker нод
}
Изменение ресурсов ВМ
hcl
vm_specs = {
  master = {
    cpu_cores          = 4      # Больше CPU
    memory_mb          = 8192   # 8GB RAM
    disk_size_gb       = 50     # 50GB диск
  }
  worker = {
    cpu_cores          = 4
    memory_mb          = 4096   # 4GB RAM
    disk_size_gb       = 40     # 40GB диск
  }
}
🔧 Устранение неполадок
Проблема: SSH подключение не работает
bash
# Проверьте что ВМ запущены
ssh root@<proxmox_ip> "qm list | grep -E '(2000|2100|2101)'"

# Добавьте ключ вручную
ssh root@<proxmox_ip> "qm terminal 2000"
# Внутри ВМ:
sudo mkdir -p /home/ubuntu/.ssh
echo "ssh-ed25519 ВАШ_КЛЮЧ" | sudo tee /home/ubuntu/.ssh/authorized_keys
Проблема: ВМ не загружается
bash
# Переключите на UEFI
ssh root@<proxmox_ip> "qm set 2000 --bios ovmf"
ssh root@<proxmox_ip> "qm set 2000 --machine pc-q35-8.1"
ssh root@<proxmox_ip> "qm set 2000 --efidisk0 local-lvm:1,format=raw,efitype=4m"
📊 Проверка состояния
bash
# Проверка всех ВМ
ssh root@<proxmox_ip> "qm list | grep -E '(2000|2100|2101)'"

# Проверка IP адресов
for vm in 2000 2100 2101; do
  echo "VM $vm:"
  ssh root@<proxmox_ip> "qm config $vm | grep ipconfig0"
done
🔐 Безопасность
API токен: Используйте минимально необходимые права

SSH ключи: Храните приватный ключ только на Proxmox

Секреты: Никогда не коммитьте секретные данные в Git

Сеть: Настройте firewall правила для изоляции кластера

📞 Поддержка
При возникновении проблем:

Проверьте логи workflow в CI/CD системе

Убедитесь что все секреты настроены правильно

Проверьте доступность Proxmox API

Убедитесь что SSH ключи совпадают

Автоматический деплой Kubernetes кластера на Proxmox
Версия: 1.0.0 | Декабрь 2025

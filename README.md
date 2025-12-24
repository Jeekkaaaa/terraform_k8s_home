🚀 Автоматический деплой Kubernetes кластера на Proxmox
Полное решение для автоматического развертывания K8s кластера через Terraform и Git CI/CD.

📋 Содержание
🎯 Основные возможности

🏗️ Архитектура

📁 Структура проекта

⚙️ Предварительная настройка

🔐 Настройка секретов CI/CD

🛠️ Конфигурационный файл

🚀 Использование

🔧 Устранение неполадок

🔄 Workflow процесс

🎯 Основные возможности
✅ Полная автоматизация — от шаблона до работающего кластера
✅ UEFI загрузка — современная загрузка всех ВМ
✅ Автоподбор IP — умный поиск свободных адресов
✅ Гибкая конфигурация — настройка количества нод через один файл
✅ CI/CD интеграция — деплой по push в Git
✅ Безопасность — SSH ключи через секреты, API токены

🏗️ Архитектура
text
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Git Server    │    │   CI/CD Runner  │    │   Proxmox VE    │
│   (Gitea)       │────│   (Workflow)    │────│   (192.168.0.223)│
│                 │    │                 │    │                 │
│  • Репозиторий  │    │  • Terraform    │    │  • Шаблон 9001  │
│  • Secrets      │    │  • Автоподбор IP│    │  • Master 2000  │
│  • Workflows    │    │                 │    │  • Workers 2100+│
└─────────────────┘    └─────────────────┘    └─────────────────┘
📁 Структура проекта
text
terrafotm_k8s_home/
├── .gitea/
│   └── workflows/
│       └── deploy-master.yml    # CI/CD пайплайн
├── config.auto.tfvars           # Основная конфигурация
├── variables.tf                 # Общие переменные Terraform
├── template/                    # Шаблон ВМ (9001)
│   ├── main.tf                  
│   └── variables.tf
├── master/                      # Master ноды
│   ├── main.tf                 # Terraform для master
│   └── variables.tf
└── worker/                      # Worker ноды
    ├── main.tf                 # Terraform для workers
    └── variables.tf
⚙️ Предварительная настройка
1. Создание API токена в Proxmox
bash
# На Proxmox хосте (192.168.0.223):
pveum user add terraform-prov@pve --password <ваш_пароль>
pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
pveum aclmod / -user terraform-prov@pve -role TerraformProv
pveum token add terraform-token --user terraform-prov@pve --privsep 0
Запишите:

Token ID: terraform-prov@pve!terraform-token

Token Secret: сгенерированный UUID

2. Создание SSH ключа
bash
# На Proxmox хосте:
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
cat /root/.ssh/id_ed25519.pub  # Сохраните вывод
🔐 Настройка секретов CI/CD
Для Gitea/GitHub/GitLab добавьте:
Секрет	Значение	Пример
PM_API_URL	URL Proxmox API	https://192.168.0.223:8006/api2/json
PM_API_TOKEN_ID	ID API токена	terraform-prov@pve!terraform-token
PM_API_TOKEN_SECRET	Секрет API токена	xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
PROXMOX_SSH_USERNAME	SSH пользователь Proxmox	root
PROXMOX_SSH_PASSWORD	SSH пароль Proxmox	ваш_пароль
PROXMOX_SSH_PUBKEY	Публичный SSH ключ	ssh-ed25519 AAAAC3...
Важно: Все 6 секретов обязательны!

🛠️ Конфигурационный файл
config.auto.tfvars — единый файл управления
hcl
# Основные
target_node = "pve-k8s"          # Имя ноды Proxmox

# Шаблон
template_vmid = 9001

# Кластер (НАСТРАИВАЙТЕ ЗДЕСЬ!)
cluster_config = {
  masters_count = 0              # Сколько master нод (0-9)
  workers_count = 3              # Сколько worker нод (0-9)
  cluster_name  = "home-k8s-cluster"
  domain        = "home.lab"
}

# VM ID (диапазоны)
vmid_ranges = {
  masters = { start = 2000, end = 2009 }  # Master ноды
  workers = { start = 2100, end = 2109 }  # Worker ноды
}

# Характеристики ВМ
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

# Сеть (НАСТРОЙТЕ ПОД СВОЮ СЕТЬ!)
network_config = {
  subnet       = "192.168.0.0/24"   # Ваша подсеть
  gateway      = "192.168.0.1"      # Ваш шлюз
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"            # Сетевой мост
}

# Cloud-init
cloud_init = {
  user           = "ubuntu"          # Пользователь по умолчанию
  search_domains = ["home.lab"]
}

# Автоподбор IP (заполняется автоматически)
static_ip_base = 100
🚀 Использование
Автоматический деплой (рекомендуется)
bash
# Любой push в main ветку запускает деплой
git add .
git commit -m "Обновление кластера"
git push origin main
Подключение к кластеру после деплоя
bash
# Master нода (если masters_count > 0)
ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.111

# Worker ноды
ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.112
ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.113

# Быстрые алиасы (добавьте в ~/.bashrc на Proxmox)
alias k-master='ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.111'
alias k-w1='ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.112'
alias k-w2='ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.113'
Проверка состояния
bash
# На Proxmox хосте
qm list | grep -E '(2000|2100|2101)'

# Проверка IP адресов
for vm in 2000 2100 2101; do
  echo "VM $vm:"
  qm config $vm | grep ipconfig0
done
🔧 Устранение неполадок
❌ Ошибка: got: = при деплое
Причина: Пустые секреты PM_API_TOKEN_ID или PM_API_TOKEN_SECRET
Решение: Проверьте все 6 секретов в CI/CD системе

❌ Ошибка: SSH WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED
Причина: ВМ пересоздана, изменился SSH host key
Решение:

bash
ssh-keygen -f '/root/.ssh/known_hosts' -R '192.168.0.111'
ssh -o StrictHostKeyChecking=no ubuntu@192.168.0.111
⚠️ Предупреждение: Value for undeclared variable
Причина: Лишние переменные в config.auto.tfvars
Решение: Удалите строки bridge = ... и storage = ...

❌ Master создается при masters_count = 0
Причина: Старая версия master/main.tf
Решение: Обновите файл с поддержкой count = var.cluster_config.masters_count

🔄 Workflow процесс
При каждом push в main ветку:

✅ Checkout code — загрузка репозитория

🔍 Read network config — чтение подсети

🎯 Auto-find Free IP Range — поиск свободных IP

📝 Update config — обновление static_ip_base

🏗️ Create Template — создание/обновление шаблона 9001

🚀 Deploy Cluster — создание master и worker нод

📊 Примеры конфигураций
Только workers (без master)
hcl
cluster_config = {
  masters_count = 0
  workers_count = 3
}
Результат: 3 worker ноды с IP .111, .112, .113

Классический кластер
hcl
cluster_config = {
  masters_count = 1
  workers_count = 2
}
Результат: 1 master (.111) + 2 workers (.112, .113)

High Availability
hcl
cluster_config = {
  masters_count = 3
  workers_count = 3
}
Результат: 3 masters (.111-.113) + 3 workers (.114-.116)

🔐 Безопасность
API токены — отдельный пользователь с минимальными правами

SSH ключи — приватный ключ только на Proxmox

Секреты — никогда не в Git, только в CI/CD системе

Сеть — рекомендуется настройка firewall

📞 Поддержка
Проверьте перед обращением:

✅ Все 6 секретов установлены и не пустые

✅ config.auto.tfvars настроен под вашу инфраструктуру

✅ API токен Proxmox имеет необходимые права

✅ Proxmox доступен из сети CI/CD runner

Логи:

Workflow логи в Gitea: Settings → Actions → Runs

Terraform логи в workflow output

Proxmox логи: qm config <vmid> и journalctl

🎯 Быстрый старт
Настройте Proxmox API токен

Добавьте 6 секретов в Gitea/GitHub/GitLab

Отредактируйте config.auto.tfvars (особенно подсеть и шлюз)

Сделайте push в main ветку

Подключайтесь: ssh ubuntu@192.168.0.111

Версия: 2.0.0
Последнее обновление: Декабрь 2025
Автор: Автоматизированная система деплоя K8s

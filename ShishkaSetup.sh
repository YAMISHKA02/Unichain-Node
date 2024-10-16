#!/bin/bash

show() {
    echo -e "\033[33m$1\033[0m"
}

# Вывод текста построчно
show " ____   _   _  ___  ____   _   _  _  __    _    "
show "/ ___| | | | ||_ _|/ ___| | | | || |/ /   / \   "
show "\___ \ | |_| | | | \___ \ | |_| || ' /   / _ \  "
show " ___) ||  _  | | |  ___) ||  _  || . \  / ___ \ "
show "|____/ |_| |_||___||____/ |_| |_||_|\_\/_/   \_\ "
show "  ____  ____ __   __ ____  _____  ___           "
show " / ___||  _ \\ \ / /|  _ \|_   _|/ _ \          "
show "| |    | |_) |\ V / | |_) | | | | | | |         "
show "| |___ |  _ <  | |  |  __/  | | | |_| |         "
show " \____||_| \_\ |_|  |_|     |_|  \___/          "
show " _   _   ___   ____   _____  ____               "
show "| \ | | / _ \ |  _ \ | ____|/ ___|              "
show "|  \| || | | || | | ||  _|  \___ \              "
show "| |\  || |_| || |_| || |___  ___) |             "
show "|_| \_| \___/ |____/ |_____||____/              "


# Проверяем, что скрипт запущен от root
if [ "$(id -u)" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами root."
    exit 1
fi

# Обновление и установка необходимых пакетов
show "Обновляем систему и устанавливаем необходимые пакеты..."
sudo apt update && sudo apt upgrade -y

# Установка Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Устанавливаем Docker..."
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
else
    show "Docker уже установлен."
fi

# Установка Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Устанавливаем Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    show "Docker Compose уже установлен."
fi

# Клонируем репозиторий Unichain
if [ ! -d "unichain-node" ]; then
    echo "Клонируем репозиторий Unichain..."
    git clone https://github.com/Uniswap/unichain-node
else
    show "Репозиторий Unichain уже клонирован."
fi

# Меняем директорию на unichain-node
cd unichain-node || { echo "Ошибка: не удалось перейти в директорию unichain-node"; exit 1; }

# Настройка .env.sepolia
if [ -f ".env.sepolia" ]; then
    echo "Настраиваем .env.sepolia..."
    sed -i 's|OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=https://ethereum-sepolia-rpc.publicnode.com|' .env.sepolia
    sed -i 's|OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com|' .env.sepolia
else
    echo "Файл .env.sepolia не найден!"
    exit 1
fi

# Изменение docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "Изменяем docker-compose.yml..."

    cat > docker-compose.yml <<EOL
volumes:
  shared:

services:
  execution-client:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:v1.101408.0
    env_file:
      - .env
      - .env.sepolia
    ports:
      - 30403:30303/udp
      - 30403:30303/tcp
      - 8745:8545/tcp
      - 8746:8546/tcp
    volumes:
      - \${HOST_DATA_DIR}:/data
      - shared:/shared
      - ./chainconfig:/chainconfig
      - ./op-geth-entrypoint.sh:/entrypoint.sh
    healthcheck:
      start_interval: 5s
      start_period: 240s
      test: wget --no-verbose --tries=1 --spider http://localhost:8545 || exit 1
    restart: always
    entrypoint: /entrypoint.sh

  op-node:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.9.1
    env_file:
      - .env
      - .env.sepolia
    ports:
      - 9322:9222/udp
      - 9322:9222/tcp
      - 9645:9545/tcp
    volumes:
      - shared:/shared
      - ./chainconfig:/chainconfig
    healthcheck:
      start_interval: 5s
      start_period: 240s
      test: wget --no-verbose --tries=1 --spider http://localhost:9545 || exit 1
    depends_on:
      execution-client:
        condition: service_healthy
    restart: always
EOL

else
    show "Файл docker-compose.yml не найден!"
    exit 1
fi

# Запускаем ноду
show "Запускаем ноду..."
docker-compose up -d

# Проверяем работу ноды с помощью curl
show "Пробуем запрос к ноде..."
curl -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' \
  -H "Content-Type: application/json" http://localhost:8745


show "Установка завершена! Node Exporter и сервис отправки метрик запущены."
show "Не забудь подписаться https://t.me/shishka_crypto"

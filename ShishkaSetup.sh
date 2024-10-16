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
echo "Обновляем систему и устанавливаем необходимые пакеты..."
sudo apt update && sudo apt upgrade -y

# Установка Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Устанавливаем Docker..."
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
else
    echo "Docker уже установлен."
fi

# Установка Docker Compose
if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Устанавливаем Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose уже установлен."
fi

# Клонируем репозиторий Unichain
if [ ! -d "unichain-node" ]; then
    echo "Клонируем репозиторий Unichain..."
    git clone https://github.com/Uniswap/unichain-node
else
    echo "Репозиторий Unichain уже клонирован."
fi

# Меняем директорию на unichain-node
cd unichain-node || { echo "Ошибка: не удалось перейти в директорию unichain-node"; exit 1; }

# Настройка .env.sepolia
if [ -f ".env.sepolia" ]; then
    show "Настраиваем .env.sepolia..."
    sed -i 's|OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=https://ethereum-sepolia-rpc.publicnode.com|' .env.sepolia
    sed -i 's|OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=https://ethereum-sepolia-beacon-api.publicnode.com|' .env.sepolia
else
    echo "Файл .env.sepolia не найден!"
    exit 1
fi

# Запускаем ноду
echo "Запускаем ноду..."
docker-compose up -d

# Проверяем работу ноды с помощью curl
show "Пробуем запрос к ноде..."
curl -d '{"id":1,"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",false]}' \
  -H "Content-Type: application/json" http://localhost:8545

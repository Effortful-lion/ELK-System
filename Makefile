# 环境准备
# 安装Docker和docker-compose
pre-env:
	@echo "prepare the environment"
	@echo "install the docker and docker-compose"
	@./pre-docker.sh

# 避免并行拉取阻塞网络
pull_es:
	@echo "pull the elasticsearch"
	@docker pull elasticsearch:7.14.0

pull_kibana:
	@echo "pull the kibana"
	@docker pull elastic/kibana:7.14.0

pull_logstash:
	@echo "pull the logstash"
	@docker pull elastic/logstash:7.14.0

pull_filebeat:
	@echo "pull the filebeat"
	@docker pull elastic/filebeat:7.14.0

# 创建文件夹 & 文件
folder:
	@echo "create the folder"
	@echo "create the folder at the current directory"
	@mkdir -p elasticsearch7/data elasticsearch7/config elasticsearch7/logs
	@mkdir -p kibana/config
	@mkdir -p logstash
	@touch filebeat/filebeat.yml
	@echo "create the folder done"
	@echo "[warn]and then we need the content of filebeat.yml"

# 创建docker外部网络
docker-net:
	@echo "create the docker network"
	@docker network create base-env-network

# 启动容器
start-container:
	@echo "start the container"
	@echo "start the container at the current directory"
	@docker-compose up -d
	@echo "start the container done"
	@echo "look whether healthy"
	@docker ps

# 拷贝容器内目录、文件
copy:
	@echo "copy from docker to local"
	@echo "at the ELK"
	@./copy.sh




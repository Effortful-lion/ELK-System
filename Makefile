# 环境准备
# 安装Docker和docker-compose
pre-env:
	@echo "prepare the environment"
	@echo "install the docker and docker-compose"
	@./pre-docker.sh

# 创建文件夹 & 文件
folder:
	@echo "create the folder"
	@echo "create the folder at the current directory"
	@mkdir -p es/data es/logs es/config
	@mkdir -p kibana/config kibana/plugins
	@mkdir -p logstash
	@mkdir -p filebeat/config
	@touch filebeat/config/filebeat.yaml
	@echo "create the folder done"
	@echo "[warn]and then we need the content of filebeat.yml"

# 启动容器
start-container:
	@echo "start the container"
	@echo "start the container at the current directory"
	@docker-compose up -d
	@echo "start the container done"

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


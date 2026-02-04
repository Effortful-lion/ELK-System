# ELK 技术栈 Docker 部署配置介绍

## 整体架构

该配置文件基于 Docker Compose 3.5 版本，部署了完整的 ELK (Elasticsearch, Logstash, Kibana) 技术栈，并集成了 Filebeat 作为日志收集器，形成了一个完整的日志收集、处理和可视化系统。

## 服务组件详情

### 1. Elasticsearch (7.14.0)
- **容器配置**：
  - 容器名称：`elasticsearch`
  - 主机名：`elasticsearch`
  - 自动重启：`always`
  - 端口映射：`9200:9200`
- **存储配置**：
  - 临时文件系统：挂载 `/tmp`
  - 持久化卷：
    - 日志目录：`./elasticsearch7/logs:/usr/share/elasticsearch/logs`
    - 数据目录：`./elasticsearch7/data:/usr/share/elasticsearch/data`
    - 配置文件：
      - `./elasticsearch7/config/single-node.yml:/usr/share/elasticsearch/config/elasticsearch.yml`
      - `./elasticsearch7/config/jvm.options:/usr/share/elasticsearch/config/jvm.options`
      - `./elasticsearch7/config/log4j2.properties:/usr/share/elasticsearch/config/log4j2.properties`
- **环境变量**：
  - JVM 内存设置：`-Xms512m -Xmx512m`
  - 时区：`Asia/Shanghai`
  - 文件权限：`TAKE_FILE_OWNERSHIP=true`（确保挂载卷权限正确）
- **系统限制**：解除内存锁定限制

### 2. Kibana (7.14.0)
- **容器配置**：
  - 容器名称：`kibana`
  - 端口映射：`15601:5601`（使用非标准端口 15601 对外暴露）
- **存储配置**：
  - 配置文件：`./elasticsearch7/config/kibana.yml:/usr/share/kibana/config/kibana.yml`
- **依赖关系**：依赖于 Elasticsearch 服务
- **系统限制**：设置最大进程数为 65535，解除内存锁定限制

### 3. Logstash (7.14.0)
- **容器配置**：
  - 容器名称：`logstash`
  - 主机名：`logstash`
  - 自动重启：`always`
  - 端口映射：
    - `19600:9600`（监控端口）
    - `15044:5044`（Beats 输入端口）
- **存储配置**：
  - 配置文件：
    - `./logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf`
    - `./logstash/logstash.yml:/usr/share/logstash/config/logstash.yml`

### 4. Filebeat (7.14.0)
- **容器配置**：
  - 容器名称：`filebeat`
  - 自动重启：`always`
  - 用户：`root`（需要足够权限读取日志文件）
- **存储配置**：
  - 日志源目录（只读）：
    - `/data/ct_server/bin:/data/ct_server/bin:ro`
    - `/data/tools/natslogServer/bin:/data/tools/natslogServer/bin:ro`
  - 配置文件：`./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:rw`
- **依赖关系**：依赖于 Logstash 服务

## 网络配置

所有服务均部署在名为 `base-env-network` 的外部网络中，并配置了相应的网络别名，确保服务间可以通过服务名进行通信。

## 版本兼容性

- Elasticsearch：7.14.0
- Kibana：7.14.0
- Logstash：7.14.0
- Filebeat：7.14.0

所有组件版本保持一致，确保系统兼容性和稳定性。

## 部署说明

1. **网络准备**：需先创建外部网络 `base-env-network`（配置文件注释中已提示）
2. **目录结构**：需确保以下目录结构存在：
   - `./elasticsearch7/logs`
   - `./elasticsearch7/data`
   - `./elasticsearch7/config/`（包含 `single-node.yml`, `jvm.options`, `log4j2.properties`, `kibana.yml`）
   - `./logstash/`（包含 `logstash.conf`, `logstash.yml`）
   - `./filebeat/`（包含 `filebeat.yml`）
3. **启动服务**：在配置文件所在目录执行 `docker-compose up -d` 命令启动所有服务

## 功能说明

该配置实现了一个完整的日志管理系统：
1. **Filebeat**：从指定目录收集日志文件
2. **Logstash**：接收 Filebeat 发送的日志，进行处理和转换
3. **Elasticsearch**：存储和索引处理后的日志数据
4. **Kibana**：提供 Web 界面，用于日志数据的可视化分析和查询

此部署适用于中小型应用的日志集中管理和分析场景，通过 Docker 容器化部署，简化了系统搭建和维护流程。

---

# 注意事项

## 基本介绍

可以查看 `基本介绍.md`

---

## 启动前需要修改/知道

### 路径挂载配置

看自己爱好

---

### 网络配置（这个名字无所谓）

自定义网络

---

### 资源配置

主要是为了服务器资源的考虑，建议在生产环境使用：

#### Elasticsearch 内存设置
- 建议设置 `-Xms512m -Xmx512m`，根据实际内存情况调整
```yaml
environment:
  - "ES_JAVA_OPTS=-Xms512m -Xmx512m"  # 例如：8GB 内存环境可调整为 "-Xms4g -Xmx4g" 一般为宿主机的一半
```

#### 系统限制
原文件中 `Elasticsearch` 和 `Kibana` 解除了内存锁定限制，若目标环境有特殊限制要求，可调整 `ulimits` 配置。

---

### 版本升级/降级的版本兼容性

例如这里是 Elasticsearch 7.14.0 版本，Kibana 7.14.0 版本，Logstash 7.14.0 版本，Filebeat 7.14.0 版本。

---

### 环境变量

#### 时区设置
- 建议设置 `Asia/Shanghai`，根据实际环境调整
```yaml
environment:
  - "TZ=Asia/Shanghai"
```

#### Elasticsearch 文件权限设置
- 建议设置 `TAKE_FILE_OWNERSHIP=true`，自动处理挂载卷权限，若无需此功能（如不挂载外部文件），可删除该配置：
```yaml
environment:
  - "TAKE_FILE_OWNERSHIP=true"
```

---

### 配置文件内容

除了 docker-compose.yaml 本身，还需根据目标环境修改以下关联配置文件：

- Elasticsearch 配置 ： ./elasticsearch7/config/single-node.yml → 需根据集群模式（单节点/集群）调整
- Kibana 配置 ： ./elasticsearch7/config/kibana.yml → 需修改 elasticsearch.hosts 指向实际 Elasticsearch 地址
- Logstash 配置 ： ./logstash/logstash.conf → 需调整输入/输出插件配置（如 Filebeat 输入、Elasticsearch 输出）
- Filebeat 配置 ： ./filebeat/filebeat.yml → 需修改 paths 指向实际日志文件路径， output.logstash 指向实际 Logstash 地址

---

### 依赖关系
原文件中 Kibana 依赖 Elasticsearch，Filebeat 依赖 Logstash，若修改服务名称或网络配置，需确保依赖关系仍正确。

---

## 启动后的注意事项

### 密码生成器 —— 生成随机密码命令
```bash
# docker 启动后
# 进入 es 容器内: docker exec -it elasticsearch sh(bin/bash没有，sh简洁)
docker exec -it elasticsearch sh
# (interactive)交互式生成密码 —— 手动；auto 随机生成强密码
bin/elasticsearch-setup-passwords interactive
```
elasticsearch-setup-passwords 生成ES内置用户密码 → Kibana/Logstash 配置该密码 → 三者完成认证，形成可正常工作的ELK集群

---

# docker-compose.yaml

```yaml
# 注意：已删除废弃的version字段（Docker Compose V2+无需指定）
services:
  # Elasticsearch 服务
  elasticsearch:
    image: elasticsearch:7.14.0
    container_name: elasticsearch
    privileged: true
    environment:
      - ES_JAVA_OPTS=-Xms512m -Xmx512m  # JVM堆内存配置，按你的需求来
      - discovery.type=single-node     # 单节点模式（测试/轻量部署）
      - xpack.security.enabled=true    # 开启安全认证（后续用setup-passwords设密码）
    ports:
      - "9200:9200"
      - "9300:9300"
      # volumes:
      # - ./es/config:/usr/share/elasticsearch/config
      # - ./es/data:/usr/share/elasticsearch/data  # 数据持久化
      # - ./es/plugins:/usr/share/elasticsearch/plugins
    networks:
      - base-env-network
    restart: always  # 开机自启/异常重启

  # Kibana 服务
  kibana:
    image: elastic/kibana:7.14.0
    container_name: kibana
    privileged: true
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200  # 连接容器内的ES
      - I18N_LOCALE=zh-CN  # 中文界面
    ports:
      - "5601:5601"
      # volumes:
      # - ./kibana/config:/usr/share/kibana/config
      # - ./kibana/plugins:/usr/share/kibana/plugins
    networks:
      - base-env-network
    depends_on:
      - elasticsearch  # 依赖ES，ES启动后再启动Kibana
    restart: always

  # Logstash 服务
  logstash:
    image: elastic/logstash:7.14.0
    container_name: logstash
    privileged: true
    environment:
      - LS_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "5044:5044"
      - "9600:9600"
      # volumes:
      # - ./logstash/config:/usr/share/logstash/config
      # - ./logstash/pipeline:/usr/share/logstash/pipeline
    networks:
      - base-env-network
    depends_on:
      - elasticsearch
    restart: always

  # Filebeat 服务（日志采集）
  filebeat:
    image: elastic/filebeat:7.14.0
    container_name: filebeat
    privileged: true
    volumes:
      - ./filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml  # 配置文件
      - /var/log:/var/log  # 挂载宿主机日志目录（按需调整）
      - /var/lib/docker/containers:/var/lib/docker/containers  # 采集Docker容器日志
    networks:
      - base-env-network
    depends_on:
      - elasticsearch
      - logstash
    restart: always
    command: ["filebeat", "-e", "-c", "/usr/share/filebeat/filebeat.yml", "--strict.perms=false"] # 核心修改：新增 --strict.perms=false 跳过权限校验
# 网络配置：修正external.name过时问题（核心！消除告警）
networks:
  base-env-network:
    name: base-env-network  # 外部网络的名称（和你原有网络名一致）
    external: true # 需要手动：docker network create base-env-network

# 网络配置：改为Compose自动创建（删除external: true，去掉name单独声明）
#networks:
#  base-env-network:
#    driver: bridge  # 用Docker默认的桥接网络（通用，适合单机ELK部署）
#    # 可选：自定义网络网段（避免和宿主机/其他容器网段冲突，非必须）
#    # ipam:
#    #   config:
#    #     - subnet: 172.20.0.0/16# 声明为「外部网络」（该网络需提前创建：docker network create base-env-network）
```

注意：
1. 手动创建网络:docker network create base-env-network
2. 第一次启动先注释掉除了 filebeat 的 config 挂载，避免覆盖容器内默认配置
3. 手动创建filebeat.yaml文件并写入内容：日志采集源，日志输出源
```yaml
# Filebeat 7.14.0 基础配置（适配你的ELK环境）
filebeat.inputs:
  # 采集Docker容器日志（核心，适配你的场景）
  - type: container
    enable: false # 控制收集开关
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_docker_metadata: ~
  # 采集宿主机系统日志（可选，按需保留）
  - type: log
    enable: true # 控制收集开关
    paths:
      #- /data/project1/logs/*.log # linux
      - ./logs/*.log

# 输出到Logstash（容器间通过服务名访问，Compose网络内互通）
output.logstash:
  hosts: ["logstash:5044"]

# 关闭Elasticsearch输出（避免冲突）
output.elasticsearch:
  enabled: false

# 基础配置
setup.kibana:
  host: "kibana:5601"
setup.ilm.enabled: false
logging.level: info
logging.to_files: false
```
4. 全部运行起来后，在 es 容器内执行：
```bash
# docker 启动后
# 进入 es 容器内: docker exec -it elasticsearch sh(bin/bash没有，sh简洁)
docker exec -it elasticsearch sh
# (interactive)交互式生成密码 —— 手动；auto 随机生成强密码
bin/elasticsearch-setup-passwords interactive
```
目前：我全都是lion123

5. 然后：把注释打开，将除了 filebeat 的其他容器的配置 copy 到外部，用于之后的外部修改

```shell
# cd es/config
docker cp elasticsearch:/usr/share/elasticsearch/config/elasticsearch.yml .
docker cp elasticsearch:/usr/share/elasticsearch/config/jvm.options .
docker cp elasticsearch:/usr/share/elasticsearch/config/log4j2.properties .
```

```shell
# cd kibana/config
docker cp kibana:/usr/share/kibana/config/kibana.yml .
```

```shell
# cd logstash
docker cp logstash:/usr/share/logstash/config/logstash.yml .
docker cp logstash:/usr/share/logstash/pipeline/logstash.conf .
```

修改文件：给出例子了
增加 es 设置的各个应用的密码

6. 然后使用我们的外部文件挂载运行：
```shell
docker-compose up -d
```



---

# 查看日志可视化


# Docker 下载和安装脚本

```shell
#!/bin/bash

# 环境准备脚本
echo "========================================"
echo "        环境准备脚本"
echo "========================================"
echo ""

# 检查是否以root用户运行
if [ "$(id -u)" != "0" ]; then
    echo "[错误] 请以root用户运行此脚本"
    exit 1
fi

# 安装Docker
echo "install Docker and docker-compose..."
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，正在安装..."
    # 安装Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    chmod +x get-docker.sh
    sh get-docker.sh
    # 添加当前用户到docker组
    usermod -aG docker $SUDO_USER
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    echo "Docker安装完成"
    echo "Docker已自动添加到环境变量中"
else
    echo "Docker已安装"
    echo "Docker命令路径: $(which docker)"
fi

# 配置Docker中国代理
echo "配置Docker中国代理..."
docker_config="/etc/docker/daemon.json"
mkdir -p /etc/docker

# 生成daemon.json配置
echo '{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://proxy.1panel.live",
    "https://docker.1panel.top",
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://docker.ketches.cn",
    "https://docker.xuanyuan.me/"
  ]
}' > $docker_config

echo "Docker代理配置已更新"
echo "配置文件: $docker_config"
echo "使用的代理地址:"
echo "  - https://docker.mirrors.ustc.edu.cn"
echo "  - https://hub-mirror.c.163.com"
echo "  - https://mirror.baidubce.com"
echo "  - https://proxy.1panel.live"
echo "  - https://docker.1panel.top"
echo "  - https://docker.m.daocloud.io"
echo "  - https://docker.1ms.run"
echo "  - https://docker.ketches.cn"
echo "  - https://docker.xuanyuan.me/"

# 重启Docker服务使配置生效
echo "重启Docker服务..."
systemctl restart docker
echo "Docker服务已重启，代理配置生效"

# 验证Docker状态
echo "验证Docker状态..."
systemctl status docker --no-pager | head -20

echo "docker installed!"
```


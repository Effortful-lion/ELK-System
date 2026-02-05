#!/bin/bash
# 功能：从运行中的ELK容器批量拷贝核心配置文件到本地指定目录
# 适配：Windows(Git Bash/MINGW64)、Linux、Mac
# 注意：执行前确保elasticsearch/logstash/kibana容器已正常运行

# 定义颜色输出（方便看执行日志）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 恢复默认颜色

# 打印提示函数
info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
}
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}
error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# 第一步：检查容器是否运行
check_container() {
    local container_name=$1
    if ! docker ps | grep -q "$container_name"; then
        error "容器 $container_name 未运行，请先启动容器后再执行脚本！"
    fi
}
info "开始检查ELK容器运行状态..."
check_container "elasticsearch"
check_container "logstash"
check_container "kibana"
success "所有ELK容器均正常运行，开始拷贝配置文件..."

# 第二步：创建本地目标目录（不存在则自动创建，避免拷贝失败）
info "开始创建本地配置目录（不存在则自动创建）..."
mkdir -p ./elasticsearch7/config
mkdir -p ./logstash
mkdir -p ./kibana/config
success "本地目录创建完成！"

# 第三步：批量拷贝配置文件（按你的需求对应路径）
info "开始拷贝Elasticsearch配置文件..."
docker cp elasticsearch:/usr/share/elasticsearch/config/elasticsearch.yml ./elasticsearch7/config/single-node.yml || error "拷贝elasticsearch.yml失败！"
docker cp elasticsearch:/usr/share/elasticsearch/config/jvm.options ./elasticsearch7/config/jvm.options || error "拷贝jvm.options失败！"
docker cp elasticsearch:/usr/share/elasticsearch/config/log4j2.properties ./elasticsearch7/config/log4j2.properties || error "拷贝log4j2.properties失败！"
success "Elasticsearch配置文件拷贝完成！"

info "开始拷贝Logstash配置文件..."
docker cp logstash:/usr/share/logstash/config/logstash.yml ./logstash/logstash.yml || error "拷贝logstash.yml失败！"
docker cp logstash:/usr/share/logstash/pipeline/logstash.conf ./logstash/logstash.conf || error "拷贝logstash.conf失败！"
success "Logstash配置文件拷贝完成！"

info "开始拷贝Kibana配置文件..."
docker cp kibana:/usr/share/kibana/config/kibana.yml ./kibana/config/kibana.yml || error "拷贝kibana.yml失败！"
success "Kibana配置文件拷贝完成！"

# 最终提示
success "============================================="
success "所有ELK核心配置文件已全部拷贝成功！"
success "配置文件存放路径："
success "  - Elasticsearch: ./elasticsearch7/config/"
success "  - Logstash:      ./logstash/"
success "  - Kibana:        ./kibana/config/"
success "============================================="
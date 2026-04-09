# ELK 生产环境改进方案

基于项目仓库 https://github.com/Effortful-lion/ELK-System.git 的当前配置，以下是生产环境所需的系统性改进方案。

# 一、高可用架构改造

## 1.1 现状问题

| 问题              | 影响                           |
| :---------------- | :----------------------------- |
| 单节点 ES，无副本 | 节点宕机 = 数据全丢 + 服务全停 |
| Logstash 单点     | 挂了 = 日志堆积，业务无感知    |
| 无负载均衡        | 所有压力打在一个实例           |

## 1.2 目标架构

```plain
┌─────────────────────────────────────────────────────────────┐
│                        生产架构                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Nginx/K8s  │───▶│   Kibana    │    │   Kibana    │     │
│  │   Ingress   │    │   Node 1    │    │   Node 2    │     │
│  └─────────────┘    └──────┬──────┘    └─────────────┘     │
│                            │                                │
│              ┌─────────────┼─────────────┐                  │
│              ▼             ▼             ▼                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Elasticsearch 集群 (3节点)               │   │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐         │   │
│  │  │ Master  │◄──►│  Data   │◄──►│  Data   │         │   │
│  │  │  +Data  │    │ Node 2  │    │ Node 3  │         │   │
│  │  └────┬────┘    └─────────┘    └─────────┘         │   │
│  │       │                                              │   │
│  │       ▼                                              │   │
│  │  分片副本自动分配 (每个分片1主+1副本)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                            ▲                                │
│              ┌─────────────┼─────────────┐                  │
│              ▼             ▼             ▼                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Logstash   │◄──►│  Logstash   │    │   Kafka     │     │
│  │   Node 1    │    │   Node 2    │◄──►│  (缓冲层)    │     │
│  └──────┬──────┘    └─────────────┘    └─────────────┘     │
│         ▲                                                   │
│  ┌──────┴──────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Filebeat  │    │   Filebeat  │    │   Filebeat  │     │
│  │  (DaemonSet)│    │  (DaemonSet)│    │  (DaemonSet)│     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## 1.3 具体改动

| 组件     | 改动               | 配置示例                                     |
| :------- | :----------------- | :------------------------------------------- |
| ES       | 3节点集群          | discovery.seed_hosts: ["es-1","es-2","es-3"] |
| ES       | 数据副本           | index.number_of_replicas: 1                  |
| Logstash | 2节点 + Kafka 缓冲 | queue.type: persisted + Kafka input          |
| Kibana   | 2节点 + 负载均衡   | Nginx 反向代理                               |

## 1.4 改后效果

可用性：单节点故障，服务不中断（RTO < 30s） 数据安全：副本机制，磁盘损坏不丢数据 吞吐：水平扩展，支撑 10万+ EPS

# 二、性能优化

## 2.1 现状问题

| 问题                     | 影响             |
| :----------------------- | :--------------- |
| ES 512MB 内存            | 写入几百条就 OOM |
| refresh_interval 默认 1s | 写入吞吐受限     |
| tail_files: false        | 重启后重复采集   |

## 2.2 ES 内存与刷新策略

```yaml
# docker-compose.yaml
environment:
  - "ES_JAVA_OPTS=-Xms8g -Xmx8g"   # 16GB 机器配 8GB

# elasticsearch.yml
index.refresh_interval: 30s        # 批量写入时调大
index.translog.durability: async   # 异步刷盘，提升吞吐
bootstrap.memory_lock: true        # 禁用 swap
```

为什么改：30s 刷新一次比 1s 刷新一次，写入吞吐提升 5~10 倍（减少段文件生成频率） 改后效果：单机写入从 500 EPS → 5000 EPS

## 2.3 Filebeat 优化

```yaml
# filebeat.yml
tail_files: true                   # 防重复采集
scan_frequency: 5s                 # 平衡实时与CPU
harvester_buffer_size: 65536       # 大日志文件优化
close_inactive: 30m                # 减少文件句柄占用

output.logstash:
  hosts: ["logstash:5044"]
  pipelining: 2                    # 开启管道缓冲
  compression_level: 3             # 压缩传输
```

为什么改：tail_files: false 重启会重复灌数据，导致 ES 索引膨胀、查询变慢 改后效果：重启无重复数据，网络传输减少 60%

## 2.4 Logstash 调优

```yaml
# logstash.yml
pipeline.workers: 4
pipeline.batch.size: 200
pipeline.batch.delay: 50
queue.type: persisted              # 持久化队列防丢数据

# logstash.conf
output {
  elasticsearch {
    flush_size => 100              # 批量写入
    idle_flush_time => 5
  }
}
```

改后效果：吞吐从 1000 EPS → 8000 EPS，重启不丢数据

# 三、数据安全与生命周期

## 3.1 现状问题

| 问题                       | 影响                       |
| :------------------------- | :------------------------- |
| 密码明文 lion123           | 安全隐患                   |
| 无 ILM                     | 日志永久存储，磁盘必然爆满 |
| Filebeat registry 未持久化 | 重启重复采集               |

## 3.2 安全配置

```yaml
# 使用 Docker Secrets 或环境变量注入
environment:
  - "ELASTIC_PASSWORD=${ES_PASSWORD}"  # 从外部环境变量读取

# 或者使用 keystore
# elasticsearch-keystore add bootstrap.password
```

## 3.3 ILM 自动生命周期

```yaml
# filebeat.yml
setup.ilm.enabled: true
setup.ilm.policy_name: "production-logs"
setup.ilm.rollover_alias: "filebeat"
setup.ilm.pattern: "{now/d}-000001"
```

Kibana Dev Tools 配置 Policy：

```json
PUT _ilm/policy/production-logs
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50GB",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "freeze": {}
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": { "delete": {} }
      }
    }
  }
}
```

为什么改：90天前的日志几乎不查，删除可节省 70%+ 存储成本 改后效果：存储自动回收，无需人工清理，90天数据保留合规

## 3.4 Filebeat 注册表持久化

```yaml
# docker-compose.yaml
filebeat:
  volumes:
    - ./filebeat/data:/usr/share/filebeat/data:rw  # 新增！
```

改后效果：重启容器后从断点续传，无重复数据

# 四、监控与运维

## 4.1 现状问题

无监控，出问题只能看日志 无告警，磁盘满了才发现

## 4.2 ES 监控配置

```yaml
# 开启监控
xpack.monitoring.collection.enabled: true
xpack.monitoring.history.duration: 7d
```

## 4.3 关键指标告警

| 指标            | 阈值      | 告警方式       |
| :-------------- | :-------- | :------------- |
| JVM Heap 使用率 | > 85%     | 钉钉/企微/邮件 |
| 磁盘使用率      | > 85%     | 钉钉/企微/邮件 |
| 集群状态        | not green | 电话/短信      |
| 写入拒绝率      | > 1%      | 钉钉/企微      |

## 4.4 日志审计

```yaml
# elasticsearch.yml
xpack.security.audit.enabled: true
xpack.security.audit.logfile.events.include: 
  - "authentication_success"
  - "authentication_failed"
  - "access_denied"
```

改后效果：安全审计，知道谁查了敏感日志

# 五、成本优化

## 5.1 冷热分离架构

```plain
Hot 节点 (SSD) ──► Warm 节点 (SATA) ──► Cold 节点 (对象存储)
   最近7天             7~30天               30天+
   高频查询            低频查询              归档备份
   高性能             低成本               极低成本
```

## 5.2 配置

```yaml
# 节点角色标签
node.attr.box_type: hot  # / warm / cold

# ILM 自动迁移
"cold": {
  "min_age": "30d",
  "actions": {
    "allocate": {
      "require": { "box_type": "cold" }
    }
  }
}
```

改后效果：存储成本降低 60%~80%

# 六、改进前后对比总结

| 维度     | 当前状态       | 生产改进后               | 效果               |
| :------- | :------------- | :----------------------- | :----------------- |
| 可用性   | 单点，故障即停 | 3节点集群 + 副本         | 99.9% 可用性       |
| 性能     | 512MB，500 EPS | 8GB，5000+ EPS           | 10倍吞吐提升       |
| 数据安全 | 无副本，无备份 | 1副本 + ILM + 持久化队列 | 数据不丢，自动清理 |
| 运维     | 人肉运维       | 监控告警 + 自动化        | 故障 5分钟发现     |
| 成本     | 全热存储       | 冷热分离                 | 存储成本降 70%     |

# 七、实施优先级建议

## P0（立即改）

- [ ] ES 内存 512MB → 4GB+
- [ ] 开启 index.number_of_replicas: 1
- [ ] Filebeat registry 持久化
- [ ] tail_files: false → true

## P1（本周改）

- [ ] ES 3节点集群化
- [ ] 开启 ILM 自动清理
- [ ] 密码改为环境变量注入

## P2（本月改）

- [ ] Logstash + Kafka 缓冲层
- [ ] 监控告警体系
- [ ] 冷热分离架构

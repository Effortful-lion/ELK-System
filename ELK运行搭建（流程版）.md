1. 下载docker&配置环境：make pre-env
2. 准备挂载目录和filebeat.yml文件：make folder
3. 编写docker-compose.yaml 文件（首次运行，注释除了filebeat的全部挂载卷，成功运行一次后，copy目录出来）
4. 编写filebeat.yml文件
5. 手动创建docker外部网络：make docker-net
6. 启动容器：make start-container(成功运行)
7. copy 目录：make copy
8. copy出来后，修改 es/single-node.yml \ kibana/kibana.yml  \ logstash/logstash.conf \ logstash/logstash.yml
9. 初始化 es 账号密码：docker exec -it elasticsearch sh \ bin/elasticsearch-setup-passwords interactive
10. 修改后，最好全部删掉，再重启，：docker-compose down -v  \  docker compose up -d
11. 登录：http://127.0.0.1:5601/ 测试：增加对应路径的日志
12. 打开Discover -> 新建索引（其实我们的索引已经有了，只需要匹配索引） -> filebeat-search-* -> 下一步 -> 可以看到了

注意：最麻烦的是配置文件的编写
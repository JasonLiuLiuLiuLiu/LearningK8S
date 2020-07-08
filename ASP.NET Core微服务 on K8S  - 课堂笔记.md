注： 本文档为课程笔记，需要搭配视频使用。

视频课程地址： [http://video.jessetalk.cn](http://video.jessetalk.cn) 

# 环境准备

安装 chocolate ( [https://chocolatey.org/](https://chocolatey.org/))

安装 ssh terminals ([https://chocolatey.org/packages/terminals](https://chocolatey.org/packages/terminals)) 

## Service 

开启负载均衡客户端绑定

service.spec.sessionAffinity = true 

服务发现

[https://segmentfault.com/a/1190000004960668](https://segmentfault.com/a/1190000004960668)

服务发现客户端模式与服务端发现模式对比 

[https://jimmysong.io/posts/service-discovery-in-microservices/](https://jimmysong.io/posts/service-discovery-in-microservices/) 

ASP.NET CORE服务发现 with consul 

[https://cecilphillip.com/using-consul-for-service-discovery-with-asp-net-core/](https://cecilphillip.com/using-consul-for-service-discovery-with-asp-net-core/)

## namespace

* 有些对象和namespace相关，而有些则不受namespace管辖
* 可以借助于resource quote 来控制 namespace的资源  

[https://kubernetes.io/docs/concepts/policy/resource-quotas/](https://kubernetes.io/docs/concepts/policy/resource-quotas/) 

## volumes

* emptyDir
* hostPath
* secret (secret的时候再讲 
* persistentVolumeClaim （讲到的时候再说）

use secret to store mysql password 

use config map to store appsetting files 

use pvc to create mysql instance  

[https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/](https://kubernetes.io/docs/tasks/run-application/run-single-instance-stateful-application/) 

# Deployment

kubectl command list

[https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply)

### Rolling Update 滚动更新

[https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/) 

* .spec.revisionHistoryLimit 项来指定保留多少旧的ReplicaSet。 余下的将在后台被当作垃圾收集。默认的，所有的revision历史就都会被保留。在未来的版本中，将会更改为2。
* .spec.minReadySeconds: 新创建的Pod状态为Ready持续的时间至少为.spec.minReadySeconds才认为Pod Available(Ready)。
* .spec.strategy.rollingUpdate.maxSurge: specifies the maximum number of Pods that can be created over the desired number of Pods. The value cannot be 0 if MaxUnavailable is 0. 可以为整数或者百分比，默认为desired Pods数的25%. Scale Up新的ReplicaSet时，按照比例计算出允许的MaxSurge，计算时向上取整(比如3.4，取4)。
* .spec.strategy.rollingUpdate.maxUnavailable: specifies the maximum number of Pods that can be unavailable during the update process. The value cannot be 0 if maxSurge is 0.可以为整数或者百分比，默认为desired Pods数的25%. Scale Down旧的ReplicaSet时，按照比例计算出允许的maxUnavailable，计算时向下取整(比如3.6，取3)。

在Deployment rollout时，需要保证Available(Ready) Pods数不低于 desired pods number - maxUnavailable; 保证所有的Pods数不多于 desired pods number + maxSurge。

### 资源限制

 kubectl get node xxx -o yaml 

```
allocatable:     cpu: "40"     memory: 263927444Ki     pods: "110"   capacity:     cpu: "40"     memory: 264029844Ki     pods: "110"
```

申请资源 

* cpu
* 内存 
### QOS分类 

* Guaranteed
* Burstable
* BestEffort
### 
### 自动水平扩展

前置条件：

1. k8s cluster (minikube, docker desktop,或者本地VM搭建的集群都可以）

开启 metrics server (1.10+) 

开启 heaptser 1.10以前 

1. deployment 需要设计资源申请和限制  
2. 创建HPA对象
3. 配置Jemter测试 

[http://mirrors.shu.edu.cn/apache//jmeter/binaries/apache-jmeter-5.1.zip](http://mirrors.shu.edu.cn/apache//jmeter/binaries/apache-jmeter-5.1.zip) 

 

新建

* 线程组
* HTTP请求（取样器）
* 察看结果树（监听器）
* 聚合报告 

roll status 监控

```
kubectl rollout status deployments nginx-deployment
kubectl rollout history deployment/nginx-deployment
查看单个revision 的详细信息：
kubectl rollout history deployment/nginx-deployment --revision=2
回退当前的 rollout 到之前的版本：
kubectl rollout undo deployment/nginx-deployment
也可以使用 --revision参数指定某个历史版本：
kubectl rollout undo deployment/nginx-deployment --to-revision=2
```

# 计算资源管理

```
resources:
  cpu: 200m
  memory: 10Mi
```
一个cpu有 1000m（毫核）, 200m即一个核的 1/5
# HELM

```
choco install kubernetes-helm
```
用阿里云的镜像来安装  

kubectl create serviceaccount tiller --namespace kube-system

rbac-config.yaml:

```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```
带上 service account 

helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.5.1 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts --service-account tiller

# HELM 3.0

```
choco install kubernetes-helm
```
# helm install  

# Prometheus

default username: admin

default password: prom-operator

# #Persistent Volume

EmptyDir与HostPath的区别

HostPath的不足之处

## EmptyDir

•在POD初始化的时候创建，是一个空文件夹

•同一个POD内的多个 Container共享

•当Pod从Node上移除时，emptyDir中的数据会被永久删除。

**最佳实践**

emptyDir可以在以下几种场景下使用：

* 临时空间，例如基于磁盘的合并排序
* 设置检查点以从崩溃事件中恢复未执行完毕的长计算
* 保存内容管理器容器从Web服务器容器提供数据时所获取的文件
## hostpath

hostPath类型则是映射node文件系统中的文件或者目录到pod里。在使用hostPath类型的存储卷时，也可以设置type字段，支持的类型有文件、目录、File、Socket、CharDevice和BlockDevice。

使用场景：

* 当运行的容器需要访问Docker内部结构时，如使用hostPath映射/var/lib/docker到容器；
* 当在容器中运行cAdvisor时，可以使用hostPath映射/dev/cgroups到容器中；

注意事项：

* 配置相同的pod（如通过podTemplate创建），可能在不同的Node上表现不同，因为不同节点上映射的文件内容不同
* 当Kubernetes增加了资源敏感的调度程序，hostPath使用的资源不会被计算在内
* 宿主机下创建的目录只有root有写权限。你需要让你的程序运行在privileged container上，或者修改宿主机上的文件权限。

用 hostpath挂载来创建mongodb

```
apiVersion: v1
	kind: Pod
	metadata:
	  name: mongodb 
	spec:
	  volumes:
	  - name: mongodb-data
	    hostPath:
	      path: /tmp/mongodb
	  containers:
	  - image: mongo
	    name: mongodb
	    volumeMounts:
	    - name: mongodb-data
	      mountPath: /data/db
	    ports:
	    - containerPort: 27017
```
	      protocol: TCP


pod nfs 挂载  

```
apiVersion: v1
	kind: Pod
	metadata:
	  name: mongodb-nfs
	spec:
	  volumes:
	  - name: mongodb-data
	    nfs:
	      server: 1.2.3.4
	      path: /some/path
	  containers:
	  - image: mongo
	    name: mongodb
	    volumeMounts:
	    - name: mongodb-data
	      mountPath: /data/db
	    ports:
	    - containerPort: 27017
	      protocol: TCP
```
aws pod挂载
```
apiVersion: v1
	kind: Pod
	metadata:
	  name: mongodb-aws
	spec:
	  volumes:
	  - name: mongodb-data
	    awsElasticBlockStore:
	      volumeID: my-volume
	      fsType: ext4
	  containers:
	  - image: mongo
	    name: mongodb
	    volumeMounts:
	    - name: mongodb-data
	      mountPath: /data/db
	    ports:
	    - containerPort: 27017
	      protocol: TCP
```
## 
## 

## PersistentVolume 

[https://jimmysong.io/posts/kubernetes-persistent-volume/](https://jimmysong.io/posts/kubernetes-persistent-volume/) 

* 配置（静态/动态） 
* 绑定
* 使用
1. 集群管理员创建某类型的网络存储（NFS或者其它）
2. 通过k8s api 传递PV声明来创建持久卷(PV)
3. 用户创建一个持久卷声明（PVC)
4. K8S 匹配到足够容量的PV将 PVC绑定到PV
5. 用户创建一个POD并通过卷配置来引用和PVC 

创建PersistentVolume

```
apiVersion: v1
	kind: PersistentVolume
	metadata:
	  name: mongodb-pv
	spec:
	  capacity: 
	    storage: 1Gi
	  accessModes:
	    - ReadWriteOnce
	    - ReadOnlyMany
	  persistentVolumeReclaimPolicy: Retain
	  hostPath:
	    path: /tmp/mongodb
```
## PersistentVolumeClaim 

以下为静态配置，将 PersistentVolumeClaim绑定到一个已级的PersistentVolumen上 。

```
apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  name: mongodb-pvc 
	spec:
	  resources:
	    requests:
	      storage: 1Gi
	  accessModes:
	  - ReadWriteOnce
	  storageClassName: ""
```
## **持久券静态配置 **

在POD中使用PVC

```
apiVersion: v1
	kind: Pod
	metadata:
	  name: mongodb 
	spec:
	  containers:
	  - image: mongo
	    name: mongodb
	    volumeMounts:
	    - name: mongodb-data
	      mountPath: /data/db
	    ports:
	    - containerPort: 27017
	      protocol: TCP
	  volumes:
	  - name: mongodb-data
	    persistentVolumeClaim:
	      claimName: mongodb-pvc
```
## 持久卷动态配置 

**通过StorageClass定义可用存储类型 **

```
apiVersion: storage.k8s.io/v1
	kind: StorageClass
	metadata:
	  name: fast
	provisioner: k8s.io/minikube-hostpath
	parameters:
	  type: pd-ssd
```
创建一个请求特定存储类的PVC 定义

```
    apiVersion: v1
	kind: PersistentVolumeClaim
	metadata:
	  name: mongodb-pvc 
	spec:
	  storageClassName: fast
	  resources:
	    requests:
	      storage: 100Mi
	  accessModes:
	    - ReadWriteOnce
```
## NFS本地集群动态配置持久卷

确保防火墙已经关闭

```
systemctl stop firewalld
systemctl disable firewalld
yum install -y nfs-common nfs-utils
```
创建共享目录

```
mkdir /nfsdata
```
授权共享目录

```
chmod 666 /nfsdata
```
编辑exports文件

```
vi /etc/exports
/nfsdata *(rw,no_root_squash,no_all_squash,sync)
```
  把*改成网段 比如在本地虚拟机的 192.168.139.0/24
/nfsdata 192.168.139.0/24(rw,no_root_squash,no_all_squash,sync)

192.168.139.0/24 跟()之间不能有空格 切记

配置生效

```
exportfs -r
```
** 启动rpc和nfs（注意顺序）**
必须先启动rpcbind服务，再启动nfs服务，这样才能让nfs服务在rpcbind服务上注册成功： 

```
 systemctl start rpcbind
 systemctl start nfs
 systemctl enable rpcbind.service nfs
```
在NFS服务器上创建成功共享目录 /nfsdata：
执行  showmount -e 判断NFS创建的共享目录是否成功

```
 showmount -e
 (Export list for K8sNFS:
/nfsdata 192.168.69.0/24)
```
代表启动成功
在k8s工作节点上安装NFS客户端

```
 yum install -y nfs-utils 
```
判断k8s从节点是否可以挂载NFS共享的目录
```
 showmount -e 192.168.139.128 (192.168.139.128 换成NFS的地址)
 Export list for 192.168.139.128:
/nfsdata 192.168.139.0/24
```
表示可以挂载

helm install nfs-client-provision --set nfs.server=192.168.139.128 --set nfs.path=/nfsdata ./nfs-client-provinsioner

[https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client](https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client)


如果下载quay的镜像比较慢可以从阿里云上拉下该镜像之后重新打tag，执行下面的脚本即可。

```
docker pull registry.cn-hangzhou.aliyuncs.com/jessetalk/nfs-client-provisioner:v3.1.0-k8s1.11
docker tag registry.cn-hangzhou.aliyuncs.com/jessetalk/nfs-client-provisioner:v3.1.0-k8s1.11 quay.io/external_storage/nfs-client-provision
er:v3.1.0-k8s1.11
```
[https://github.com/helm/charts](https://github.com/helm/charts)

## 总结

持久卷的创建 (PV）

持久卷声明的创建、绑定、使用 （PVC)

存储模式包括：

* ReadWriteOnce——该卷可以被单个节点以读/写模式挂载
* ReadOnlyMany——该卷可以被多个节点以只读模式挂载
* ReadWriteMany——该卷可以被多个节点以读/写模式挂载

在命令行中，访问模式缩写为：

* RWO - ReadWriteOnce
* ROX - ReadOnlyMany
* RWX - ReadWriteMany
### 回收策略

当前的回收策略包括：

* Retain（保留）——手动回收
* Recycle（回收）——基本擦除（rm -rf /thevolume/*）
* Delete（删除）——关联的存储资产（例如 AWS EBS、GCE PD、Azure Disk 和 OpenStack Cinder 卷）将被删除
### 状态

卷可以处于以下的某种状态：

* Available（可用）——一块空闲资源还没有被任何声明绑定
* Bound（已绑定）——卷已经被声明绑定
* Released（已释放）——声明被删除，但是资源还未被集群重新声明
* Failed（失败）——该卷的自动回收失败

命令行会显示绑定到 PV 的 PVC 的名称。

* 了解mongo ha
# Statefulset

* 稳定的网络标识(不是随机的名字，而是pod-0,pod-1
* 按顺序创建
### Mongo HA集群

[https://codelabs.developers.google.com/codelabs/cloud-mongodb-statefulset/index.html?index=..%2F..index#6](https://codelabs.developers.google.com/codelabs/cloud-mongodb-statefulset/index.html?index=..%2F..index#6)


手动配置

```
kubectl apply -f mongo-headless-service.yaml
kubectl apply -f mongo-statefulset.yaml
kubectl exec ‑it mongo‑0 -n mongo-rs-config ‑‑ mongo
rs.initiate()
var cfg = rs.conf();cfg.members[0].host="mongo‑0.mongo:27017";rs.reconfig(cfg)
rs.add("mongo‑1.mongo:27017")
rs.add("mongo-2.mongo:27017")

rs.status()
```
# 核心组件

## etcd

raft共识算法动画演示 

[http://www.kailing.pub/raft/index.html](http://www.kailing.pub/raft/index.html)

创建etcd on centos

```
yum install etcd
export ETCDCTL_API=3
etcdctl put key value
etcdctl get key
```
## kube-apiserver

下载kube-apiserver

```
mkdir /kube
cd /kube
wget https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kube-apiserver
chmod +x kube-apiserver
./kube-apiserver \
--etcd-servers=http://127.0.0.1:2379 \
--service-cluster-ip-range=10.0.0.0/16 \
--insecure-bind-address=0.0.0.0 \
--external-hostname=192.168.139.131 \
--disable-admission-plugins=ServiceAccount 
# 记得把IP地址替换成你本地的地址 
curl http://192.168.139.131:8080/api/v1/nodes
```
## kubelet

```
# 创建 kubeletconfig.yaml
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: http://127.0.0.1:8080
users:
- name: kubelet
contexts:
- context:
    cluster: local
    user: kubelet
  name: kubelet-context
current-context: kubelet-context
```
```
wget https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kubelet
chmod +x kubelet
./kubelet --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice --kubeconfig=/kube/master-kubeletconfig.yaml
curl http://localhost:10248/healthz
# 记得把IP地址替换成你本地的地址 
http://192.168.139.131:8080/api/v1/node
```
**assign a pod**
nginx.json  (下面的nodeName，替换成本地hostname) 

```
{
  "apiVersion": "v1",
  "kind": "Pod",
  "metadata": {
    "name": "nginx"
  },
  "spec": {
    "nodeName": "k8s-training",
    "containers": [
      {
        "name": "nginx",
        "image": "nginx",
        "ports": [
          {
            "containerPort": 80
          }
        ],
        "volumeMounts": [
          {
            "mountPath": "/var/log/nginx",
            "name": "nginx-logs"
          }
        ]
      },
      {
        "name": "log-truncator",
        "image": "busybox",
        "command": [
          "/bin/sh"
        ],
        "args": [
          "-c",
          "while true; do cat /dev/null > /logdir/access.log; sleep 10; done"
        ],
        "volumeMounts": [
          {
            "mountPath": "/logdir",
            "name": "nginx-logs"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "nginx-logs",
        "emptyDir": {
        }
      }
    ]
  }
}
```
nginx.yaml

```
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  nodeName: {YOUR-NODE-NAME}
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: /var/log/nginx
      name: nginx-logs
  - name: log-truncator
    image: busybox
    command:
    - /bin/sh
    args: [-c, 'while true; do cat /dev/null > /logdir/access.log; sleep 10; done']
    volumeMounts:
    - mountPath: /logdir
      name: nginx-logs
  volumes:
  - name: nginx-logs
    emptyDir: {}
```
执行pod

```
curl \
--stderr /dev/null \
--header "Content-Type: application/json" \
--request POST http://localhost:8080/api/v1/namespaces/default/pods \
--data @nginx.json | jq 'del(.spec.containers, .spec.volumes)'
```
查询pod list
```
curl --stderr /dev/null http://localhost:8080/api/v1/namespaces/default/pods \
```
## kubectl

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl
chmod +x kubectl 
```
## kube-scheduler

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kube-scheduler
chmod +x kube-scheduler
./kube-scheduler --master=http://localhost:8080
```
## 
## kubectl-controller-manager

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kube-controller-manager
chmod +x kube-controller-manager
./kube-controller-manager --master=http://localhost:8080
```
nginx-replicas.yaml

```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      tier: nginx
  template:
    metadata:
      labels:
        tier: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
```
## kube-proxy

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.16.3/bin/linux/amd64/kube-proxy
chmod +x kube-proxy
```
# 认证&授权 

创建新用户

[https://jimmysong.io/kubernetes-handbook/guide/kubectl-user-authentication-authorization.htm](https://jimmysong.io/kubernetes-handbook/guide/kubectl-user-authentication-authorization.html)


进入master节点上的证书目录 

cd /etc/kubernetes/pki

```
#生成私钥key
openssl genrsa -out client.key 2048
#生成公钥，颁发给admin
openssl req -new -key client.key -subj "/CN=admin" -out client.csr
#CA数字签名
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 3650
#验证证书
openssl verify -CAfile ca.crt client.crt
# 注意把下面的IP地址换成本地的
kubectl --server=https://192.168.139.128:6443 \
--certificate-authority=ca.crt \
--client-certificate=client.crt \
--client-key=client.key \
get pods --namespace=default 
```
admin-role

```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: default
  name: admin
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```
admin-rolebinding

```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin-rolebinding
  namespace: default
subjects:
- kind: User
  name: admin
  apiGroup: ""
roleRef:
  kind: Role
  name: admin
  apiGroup: ""
```
admin-clusterrole

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: admin-cluster
rules:
- apiGroups: [""]
  resources: ["secrets","nodes"]
  verbs: ["*"]
```
admin-clusterrolebinding

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-cluster
subjects:
- kind: User
  name: admin
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: admin-cluster
  apiGroup: ""
```
## token认证 

token文件的格式 

token,user,uid,"group1,group2,group3"

```
vi /etc/kubernetes/pki/tokens.csv
```
输入以一内容 
792c62a1b5f2b07b,admin,ab47c6cb-f403-11e6-95a3-0800279704c8,""

修改/etc/kubenetes/manifests/kube-apiserver.yaml，添加下面的参数 。

```
--token-auth-file=/etc/kubernetes/pki/tokens.csv
```
```
kubectl --server=https://192.168.139.128:6443 \
--token=792c62a1b5f2b07b \
--insecure-skip-tls-verify=true \
cluster-info
```
```
curl -k --header "Authorization: Bearer 792c62a1b5f2b07b" https://192.168.139.128:6443/api
```
返回以下内容  

```
{
  "kind": "APIVersions",
  "versions": [
    "v1"
  ],
  "serverAddressByClientCIDRs": [
    {
      "clientCIDR": "0.0.0.0/0",
      "serverAddress": "192.168.139.128:6443"
    }
  ]
}
```
# 网络 

安装网桥管理工具

```
yum install bridge-utils 
yum install tcpdump 
```
## Docker 网络回顾

## **网络命名空间** ip netns help


**docker 网络使用网络命名空间 **

找回docker容器的网络命名空间文件 

```
docker inspect --format='{{.State.Pid}}' 84ea01cf375d
```
ln **-**s /proc**/**{id}**/**ns**/**net **/**var**/**run**/**netns**/{id}**
```
# 打开一个终端
docker run --name box1 -it --rm busybox sh
# 再打开另一个终端运行 
docker run --name box2 -it --rm busybox sh
# 再打开另一个终端输入brctl show 
docker0         8000.02423117420b       no              veth645cee7
                                                        veth9fe8970
```
## **动手实践网络命名空间 **

创建网络namespace 

ip netns add ns2

创建一对veth pair

ip link add A type veth peer name B

添加到docker0 bridge

brctl addif docker0 A

启用A veth

ip link set A up

将B接口放到ns2

ip link set B netns ns2

命名为eth0

ip netns exec ns2 ip link set dev B name eth0

开启接口2

ip netns exec ns2 ip link set eth0 up

配置一个可用ip 

ip netns exec ns2 ip addr add 172.17.0.5/16 dev eth0

配置默认网关

 ip netns exec ns2 ip route add default via 172.17.0.1

在某个命名空间下执行命令 

ip netns exec ns2 ifconfig

在两个容器内分别查看他们的ifindex

```
cat /sys/class/net/eth0/ifindex
```
对veth 进行网络抓包 

```
tcpdump -nnt -i veth645cee7
```
## K8S CNI

## Flannel网络

查看本地 route转发规则 

ip route  show dev flannel.1

ip neigh show dev flannel.1

bridge fdb show dev flannel.1


关于flannel网络的更多扩展阅读：

[https://ggaaooppeenngg.github.io/zh-CN/2017/09/21/flannel-%E7%BD%91%E7%BB%9C%E6%9E%B6%E6%9E%84/](https://ggaaooppeenngg.github.io/zh-CN/2017/09/21/flannel-%E7%BD%91%E7%BB%9C%E6%9E%B6%E6%9E%84/)

[https://www.cnblogs.com/xzkzzz/p/9936467.html](https://www.cnblogs.com/xzkzzz/p/9936467.html)

## IPTabs

[https://www.zsythink.net/archives/1199](https://www.zsythink.net/archives/1199)

## Ipvs

[https://segmentfault.com/a/1190000016333317](https://segmentfault.com/a/1190000016333317)

ipvs vs iptables

[https://blog.fleeto.us/post/iptables-or-ipvs/](https://blog.fleeto.us/post/iptables-or-ipvs/)


Linux网络名词解释：

1. 网络的命名空间：Linux在网络栈中引入网络命名空间，将独立的网络协议栈隔离到不同的命令空间中，彼此间无法通信；docker利用这一特性，实现不容器间的网络隔离。
2. Veth设备对：Veth设备对的引入是为了实现在不同网络命名空间的通信。
3. Iptables/Netfilter：Netfilter负责在内核中执行各种挂接的规则(过滤、修改、丢弃等)，运行在内核 模式中；Iptables模式是在用户模式下运行的进程，负责协助维护内核中Netfilter的各种规则表；通过二者的配合来实现整个Linux网络协议栈中灵活的数据包处理机制。
4. 网桥：网桥是一个二层网络设备,通过网桥可以将linux支持的不同的端口连接起来,并实现类似交换机那样的多对多的通信。
5. 路由：Linux系统包含一个完整的路由功能，当IP层在处理数据发送或转发的时候，会使用路由表来决定发往哪里。

一个 network stack 包括： 

一个pod里面的所有容器共享受同一个network stack 

[https://www.kubernetes.org.cn/2059.htmlKubernetes 网络原理及方案](https://www.kubernetes.org.cn/2059.html)

[How Does The Kubernetes Networking Work? : Part 1](https://medium.com/@tao_66792/how-does-the-kubernetes-networking-work-part-1-5e2da2696701)

[How Does The Kubernetes Networking Work? : Part 2](https://medium.com/@tao_66792/how-does-the-kubernetes-networking-work-part-2-e81fc95ff2f6)

[How Does The Kubernetes Networking Work? : Part 3](https://medium.com/@tao_66792/how-does-the-kubernetes-networking-work-part-3-910ae2f8dc08)

## Ingress

```
openssl x509 -in ingress.jessetalk.cn.pem -out ingress.jessetalk.cn.crt

kubectl create secret tls ingress-tls --cert=ingress.jessetalk.cn.crt --key=ingress.jessetalk.cn.key -n k8s-demo
```
# 集群部署及管理

# [https://shimo.im/docs/t8qPwyjG6RD9H6Qd/](https://shimo.im/docs/t8qPwyjG6RD9H6Qd/) 《Kubernetes 17.1 二进制高可用集群搭建》

# 文档引用

中文文档地址：

[https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)

英文文档地址：

[https://www.kubernetes.org.cn/kubernetes-pod](https://www.kubernetes.org.cn/kubernetes-pod)


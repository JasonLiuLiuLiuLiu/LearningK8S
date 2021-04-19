视频地址： [http://video.jessetalk.cn/course/7](http://video.jessetalk.cn/course/7) 

如果因为网络原因下载kube组件比较慢，我已经将以下几个组件(1.17.1版本）打包上传到百度云，可以到这里直接下载 链接: [https://pan.baidu.com/s/1K1CtOuBSUBXlD76pbR9www](https://pan.baidu.com/s/1K1CtOuBSUBXlD76pbR9www) 提取码: af97 

* kubelet
* kube-proxy
* kube-shedule
* kube-apiserver
* kube-controller-manager
# 主要步骤

* 准备虚拟机环境，部署好centos，做好初始准备 
* 理解master节点组件和node节点组件的用处（视频第6章最好能自己实践一下）
* 理解TLS以及K8S中的认证授权（视频第7章），有助于理解部署时证书的用处
* 生成证书（注意保存好csr文件，可能需要重复生成证书）
* etcd 集群部署 
* Master节点部署
  * kube-apiserver
  * kube-controller-manager
  * kube-scheduler
* Node节点部署
  * kubelet
  * kube-proxy 
* 网络以及插件
  * coredns
  * dashboard
* Keepalived和ＨaProxy 
# 机器准备

| 192.168.0.201   | node00   | etcd, master, node,    keepalived, haproxy   | 
|:----|:----|:----|
| 192.168.0.202   | node01   | etcd, master, node, keepalived, haproxy   | 
| 192.168.0.203   | node02   | etcd, master, node, keepalived, haproxy   | 
| 192.168.0.210   |    | VIP   | 

* 最小2GB内存，2核心CPU，20GB硬盘
* 安装centos7 minimal ([http://mirrors.aliyun.com/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1908.iso](http://mirrors.aliyun.com/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1908.iso)) 
* 语言选择不限，时区统一全部选择亚州-上海 
* 启动之后需要开启网卡，并设置为开机自动启动 (可以使用图形化工具：nmtui） 
* 软件版本
  * etcd 3.4.3
  * kubernetes 1.17.1
  * docker 19.03.5
# ![图片](https://uploader.shimo.im/f/hJSjxWNYdM8G0sUD.png!thumbnail)

# 环境准备

## 更新centos

```
# 更新centos 
yum update
# 下载 wget 工具
yum install wget
# 禁用防火墙
systemctl stop firewalld
systemctl disable firewalld
# 安装 epel 
yum install epel-release
```
## **禁用swap**

```
swapoff -a
```
修改/etc/fstab
* 在行首加 #，注释/dev/mapper/centos-swap swap

check

```
swapon -s
```
## 禁用SELinux

```
vi /etc/selinux/config
# set SELINUX=disabled 
SELINUX=disabled
# 重启
reboot
```
输入sestatus, 输出应该为：disabled 
```
sestatus
SELinux status:                 disabled
```
** hostname 主机名称修改**

```
#192.168.0.201
hostnamectl set-hostname node00
#192.168.0.202
hostnamectl set-hostname node01
#192.168.0.203
hostnamectl set-hostname node02
```
## 时间同步

所有节点安装chrony确保时间同步  

```
# 安装
yum install chrony
# 启用
systemctl start chronyd
systemctl enable chronyd
# 设置亚洲时区
timedatectl set-timezone Asia/Shanghai
# 启用NTP同步
timedatectl set-ntp yes
```
## hostname

```
vi /etc/hosts
# 添加以下内容
192.168.0.201 node00
192.168.0.202 node01
192.168.0.203 node02
```
# 证书准备 

可以说证书是整个部署当中最繁琐但是又非常容易出错的地方，几乎每一个组件都需要用到相关的证书，一旦出错就影响整个集群的运行。搞懂每个证书的用处以及在各个组件里面的配置方式非常重要。



**生成的 CA 证书和秘钥文件如下：**

* ca-key.pem
* ca.pem
* kubernetes-key.pem
* kubernetes.pem
* kube-controller-manager.pem
* kube-controller-manager-key.pem
* kube-scheduler.pem
* kube-scheduler-key.pem
* service-account.pem
* service-account-key.pem
* node00.pem
* node00-key.pem
* node01.pem
* node01-key.pem
* node02.pem
* node02-key.pem
* kube-proxy.pem
* kube-proxy-key.pem
* admin.pem
* admin-key.pem

**使用证书的组件如下：**

![图片](https://uploader.shimo.im/f/vemHkk47zhIGN4IY.png!thumbnail)

|    | CA证书   | API Server证书    | ServiceAccount证书   | TLS API Server证书    | 
|:----|:----|:----|:----:|:----|:----|
| etcd   | ca.pem   | kubernetes.pem  kubernetes-key.pem   |    |    | 
| kube-apiserver   | ca.pem   | kubernetes.pem  kubernetes-key.pem   | service-account.pem   |    | 
| kube-controller-manager   | ca.pem  ca-key.pem   |    | service-account-key.pem   | kube-controller-manager.pem  kube-controller-manager-key.pem   | 
| kube-scheduler   | ca.pem   |    |    | kube-scheduler.pem  kube-scheduler-key.pem   | 
| kubelet   | ca.pem   |    |    | nodexx.pem  nodexx-key.pem   | 
| kube-proxy   | ca.pem   |    |    | kube-proxy.pem  kube-proxy-key.pem   | 

## 安装 cfssl

只在node00上安装和生成证书之后拷贝到其它master节点即可 

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
mv cfssl_linux-amd64 /usr/local/bin/cfssl
wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
chmod +x cfssl-certinfo_linux-amd64
mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
export PATH=/usr/local/bin:$PATH
```
## 创建ca配置文件

```
mkdir /root/ssl
cd /root/ssl
cfssl print-defaults config > config.json
cfssl print-defaults csr > csr.json
# 根据config.json文件的格式创建如下的ca-config.json文件
# 过期时间设置成了 87600h
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF
```
字段说明

* ca-config.json：可以定义多个 profiles，分别指定不同的过期时间、使用场景等参数；后续在签名证书时使用某个 profile；
* signing：表示该证书可用于签名其它证书；生成的 ca.pem 证书中 CA=TRUE；
* server auth：表示client可以用该 CA 对server提供的证书进行验证；
* client auth：表示server可以用该CA对client提供的证书进行验证；
## **创建 CA 证书签名请求**

创建 ca-csr.json 文件，内容如下：

```
{
  "CN": "kubernetes",
  "hosts": [
      "127.0.0.1",
      "192.168.0.201",
      "192.168.0.202",
      "192.168.0.203",
      "192.168.0.210"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ],
    "ca": {
       "expiry": "87600h"
    }
}
```
* host中的IP地址改为你自己节点的IP
* "CN"：Common Name，kube-apiserver 从证书中提取该字段作为请求的用户名 (User Name)；浏览器使用该字段验证网站是否合法；
* "O"：Organization，kube-apiserver 从证书中提取该字段作为请求用户所属的组 (Group)；
>这里的UserName和Group在 K8S的 RDBC授权中我们提到过可以用来做权限的处理 。
## **生成 CA 证书和私钥**

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```
## 创建 kubernetes 证书

创建 kubernetes 证书签名请求文件 kubernetes-csr.json：

```
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "192.168.0.201",
      "192.168.0.202",
      "192.168.0.203",
      "192.168.0.210",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
```
* 如果 hosts 字段不为空则需要指定授权使用该证书的 **IP 或域名列表**，由于该证书后续被 etcd 集群和 kubernetes master 集群使用，所以上面分别指定了 etcd 集群、kubernetes master 集群的主机 IP 和 **kubernetes 服务的服务 IP**（一般是 kube-apiserver 指定的 service-cluster-ip-range 网段的第一个IP，如 10.254.0.1）。
* 这是最小化安装的kubernetes集群，包括一个私有镜像仓库，三个节点的kubernetes集群，以上物理节点的IP也可以更换为主机名。
## 生成 kubernetes 证书和私钥

```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
# 查看生成的证书
ls kubernetes*
kubernetes.csr  kubernetes-csr.json  kubernetes-key.pem  kubernetes.pem
```
## 创建kubelet证书

```
# centos00
cat > centos00.json <<EOF
{
  "CN": "system:node:centos00",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
     "centos00",
     "centos01",
     "centos02",
     "192.168.101.100",
     "192.168.101.101",
     "192.168.101.102"
  ],
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

# centos01
cat > centos01.json <<EOF
{
  "CN": "system:node:centos01",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
     "centos00",
     "centos01",
     "centos02",
     "192.168.101.100",
     "192.168.101.101",
     "192.168.101.102"
  ],
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

# centos02
cat > centos02.json <<EOF
{
  "CN": "system:node:centos02",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
     "centos00",
     "centos01",
     "centos02",
     "192.168.101.100",
     "192.168.101.101",
     "192.168.101.102"
  ],
  "names": [
    {
      "C": "China",
      "L": "Shanghai",
      "O": "system:nodes",
      "OU": "Kubernetes",
      "ST": "Shanghai"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  centos00.json | cfssljson -bare centos00
  
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  centos01.json | cfssljson -bare centos01
  
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  centos02.json | cfssljson -bare centos02
```
## 创建 admin 证书

创建 admin 证书签名请求文件 admin-csr.json：

```
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
```
* 后续 kube-apiserver 使用 RBAC 对客户端(如 kubelet、kube-proxy、Pod)请求进行授权；
* kube-apiserver 预定义了一些 RBAC 使用的 RoleBindings，如 cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予了调用kube-apiserver 的**所有 API**的权限；
* O 指定该证书的 Group 为 system:masters，kubelet 使用该证书访问 kube-apiserver 时 ，由于证书被 CA 签名，所以认证通过，同时由于证书用户组为经过预授权的 system:masters，所以被授予访问所有 API 的权限；

**注意**：这个admin 证书，是将来生成管理员用的kube config 配置文件用的，现在我们一般建议使用RBAC 来对kubernetes 进行角色权限控制， kubernetes 将证书中的CN 字段 作为User， O 字段作为 Group。

在搭建完 kubernetes 集群后，我们可以通过命令: kubectl get clusterrolebinding cluster-admin -o yaml ,查看到 clusterrolebinding cluster-admin 的 subjects 的 kind 是 Group，name 是 system:masters。 roleRef 对象是 ClusterRole cluster-admin。 意思是凡是 system:masters Group 的 user 或者 serviceAccount 都拥有 cluster-admin 的角色。 因此我们在使用 kubectl 命令时候，才拥有整个集群的管理权限。可以使用 kubectl get clusterrolebinding cluster-admin -o yaml 来查看。

生成 admin 证书和私钥：

```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
# 查看生成的证书 
ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```
## 创建 kube-controller-manager 证书

```
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes",
      "ST": "BeiJing"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
```
## 
## 创建 kube-proxy 证书

创建 kube-proxy 证书签名请求文件 kube-proxy-csr.json：

```
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```
* CN 指定该证书的 User 为 system:kube-proxy；
* kube-apiserver 预定义的 RoleBinding system:node-proxier 将User system:kube-proxy 与 Role system:node-proxier 绑定，该 Role 授予了调用 kube-apiserver Proxy 相关 API 的权限；

生成 kube-proxy 客户端证书和私钥

```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy

# 查看生成的证书
ls kube-proxy*
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```
## 创建kube-scheudler证书

```
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes",
      "ST": "BeiJing"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```
## 创建ServiceAccount证书

```
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "O": "Kubernetes",
      "OU": "Kubernetes",
      "ST": "BeiJing"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
```
## 校验证书

### 使用 cfssl-certinfo 命令

```
cfssl-certinfo -cert kubernetes.pem
```
## 分发证书

```
mkdir -p /etc/kubernetes/ssl
cp *.pem /etc/kubernetes/ssl
cd /etc/kubernetes/ssl/
ls
admin-key.pem  ca-key.pem  kube-proxy-key.pem  kubernetes-key.pem
admin.pem      ca.pem      kube-proxy.pem      kubernetes.pem
```
复制到node01和node02(确保对应的节点上先创建/etc/kubernetes/ssl的文件夹） 

```
scp *.pem root@192.168.0.202:/etc/kubernetes/ssl
scp *.pem root@192.168.0.203:/etc/kubernetes/ssl
```
# 部署ETCD 集群 

## 下载etcd文件

```
# 在3台节点上创建etcd文件临时目录 
mkdir -p /root/etcd
cd /root/etcd
# 在node00上下载文件 
wget https://github.com/coreos/etcd/releases/download/v3.3.18/etcd-v3.3.18-linux-amd64.tar.gz
# 下载完之后复制到 node01和 node 02 
scp etcd-v3.3.18-linux-amd64.tar.gz root@192.168.0.202:/root/etcd
scp etcd-v3.3.18-linux-amd64.tar.gz root@192.168.0.203:/root/etcd
# 在node00, node01, node02的 /root/etcd目录下执行 
tar -xvf etcd-v3.3.18-linux-amd64.tar.gz
mv etcd-v3.3.18-linux-amd64/etcd* /usr/local/bin
```
验证etcd安装（确保三个节点上都安装成功）

```
etcd --version
etcd Version: 3.4.3
Git SHA: 3c8740a79
Go Version: go1.12.9
Go OS/Arch: linux/amd64
```
创建etcd 数据目录 （三个节点都要执行）

```
mkdir -p /var/lib/etcd
```
## 创建 etcd 的 systemd unit 文件

在/usr/lib/systemd/system/目录下创建文件etcd.service，内容如下。注意替换IP地址为你自己的etcd集群的主机IP。

```
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
Restart=always
RestartSec=5s
LimitNOFILE=40000
TimeoutStartSec=0
ExecStart=/usr/local/bin/etcd \
  --name infra1 \
  --data-dir /var/lib/etcd \
  --initial-advertise-peer-urls https://192.168.0.201:2380 \
  --listen-peer-urls https://192.168.0.201:2380 \
  --listen-client-urls https://192.168.0.201:2379 \
  --advertise-client-urls https://192.168.0.201:2379 \
  --initial-cluster-token etcd-cluster \
  --initial-cluster infra1=https://192.168.0.201:2380,infra2=https://192.168.0.202:2380,infra3=https://192.168.0.203:2380 \
  --initial-cluster-state new \
  --client-cert-auth \
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  --peer-client-cert-auth \
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
  --peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem
[Install]
WantedBy=multi-user.target
```
* infra1 为etcd member节点的名称，在不同的节点上要改为不同节点的名称 
* 指定 etcd 的工作目录为 /var/lib/etcd，数据目录为 /var/lib/etcd，需在启动服务前创建这个目录，否则启动服务的时候会报错“Failed at step CHDIR spawning /usr/bin/etcd: No such file or directory”；
* 为了保证通信安全，需要指定 etcd 的公私钥(cert-file和key-file)、Peers 通信的公私钥和 CA 证书(peer-cert-file、peer-key-file、peer-trusted-ca-file)、客户端的CA证书（trusted-ca-file）；
* 创建 kubernetes.pem 证书时使用的 kubernetes-csr.json 文件的 hosts 字段**包含所有 etcd 节点的IP**，否则证书校验会出错；
* --initial-cluster-state 值为 new 时，--name 的参数值必须位于 --initial-cluster 列表中；

**重要参数解释**

| name   | 本member名称    | 
|:----|:----|
| data-dir   | 指定节点的数据存储目录，这些数据包括节点ID，集群ID，集群初始化配置，Snapshot文件，若未指定-wal-dir，还会存储WAL文件；如果不指定会用缺省目录。   | 
| initial-advertise-peer-urls   | 其他member使用，其他member通过该地址与本member交互信息。一定要保证从其他member能可访问该地址。静态配置方式下，该参数的value一定要同时在--initial-cluster参数中存在。    memberID的生成受--initial-cluster-token和--initial-advertise-peer-urls影响。   | 
| listen-peer-urls   | 本member侧使用，用于监听其他member发送信息的地址。ip为全0代表监听本member侧所有接口   | 
| listen-client-urls   | 本member侧使用，用于监听etcd客户发送信息的地址。ip为全0代表监听本member侧所有接口   | 
| advertise-client-urls   | etcd客户使用，客户通过该地址与本member交互信息。一定要保证从客户侧能可访问该地址   | 
|    |    | 
| client-cert-auth   | 启用客户证书认证   | 
| trusted-ca-file   | 客户端认证CA文件   | 
| cert-file   | 客户端认证公钥   | 
| key-file   | 客户端认证私钥   | 
| peer-client-cert-auth    | 启用member成员之间证书认证   | 
| peer-trusted-ca-file   | 成员之间证书认证CA文件   | 
| peer-cert-file   | 成员之间证书认证公钥   | 
| peer-key-file   | 成员之间证书认证私钥    | 
|    |    | 
| initial-cluster-token   | 用于区分不同集群。本地如有多个集群要设为不同   | 
| initial-cluster   | 本member侧使用。描述集群中所有节点的信息，本member根据此信息去联系其他member。  memberID的生成受--initial-cluster-token和--initial-advertise-peer-urls影响。   | 
| initial-cluster-state   | 用于指示本次是否为新建集群。有两个取值new和existing。如果填为existing，则该member启动时会尝试与其他member交互。    集群初次建立时，要填为new，经尝试最后一个节点填existing也正常，其他节点不能填为existing。    集群运行过程中，一个member故障后恢复时填为existing，经尝试填为new也正常。   | 

## 启用etcd服务 

```
mv etcd.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
systemctl status etcd
```
## 验证etcd服务 

```
ETCDCTL_API=3 etcdctl --cert=/etc/kubernetes/ssl/kubernetes.pem --key /etc/kubernetes/ssl/kubernetes-key.pem --insecure-skip-tls-verify=true --endpoints=https://192.168.0.201:2379,https://192.168.0.202:2379,https://192.168.0.203:2379 endpoint health
https://192.168.0.201:2379 is healthy: successfully committed proposal: took = 13.87734ms
https://192.168.0.202:2379 is healthy: successfully committed proposal: took = 16.08662ms
https://192.168.0.203:2379 is healthy: successfully committed proposal: took = 15.656404ms
```
# 部署Master节点 

所有组件需要在3个 master节点上都执行。

```
# 创建统一文件存放目录
mkdir /kube
cd /kube
# 下载 kube-apiserver 组件
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kube-apiserver
# 下载 kube-scheduler组件 
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kube-scheduler
# 下载 kube-controller-manager组件 
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kube-controller-manager
```
## 创建 TLS Bootstrapping Token - （本次搭建不需要）

**Token auth file**

Token可以是任意的包含128 bit的字符串，可以使用安全的随机数发生器生成。

```
head -c 16 /dev/urandom | od -An -t x | tr -d ' '
7dc36cb645fbb422aeb328320673bbe0
```
把下面的  {BOOTSTRAP_TOKEN} 替换成上面生成的 token即可 

```
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > token.csv <<EOF
{BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```
**BOOTSTRAP_TOKEN** 将被写入到 kube-apiserver 使用的 token.csv 文件和 kubelet 使用的 bootstrap.kubeconfig 文件，如果后续重新生成了 BOOTSTRAP_TOKEN，则需要：

1. 更新 token.csv 文件，分发到所有机器 (master 和 node）的 /etc/kubernetes/ 目录下，分发到node节点上非必需；
2. 重新生成 bootstrap.kubeconfig 文件，分发到所有 node 机器的 /etc/kubernetes/ 目录下；
3. 重启 kube-apiserver 和 kubelet 进程；
4. 重新 approve kubelet 的 csr 请求；
```
cp token.csv /etc/kubernetes/
scp token.csv root@192.168.0.202:/etc/kubernetes
scp token.csv root@192.168.0.203:/etc/kubernetes
```
## kube-apiserver

预先准备

* 三个节点的证书(供kubelet使用，同时kube-apiserver访问kubelet时也要使用node00.pem node00-key.pem node01.pem node01-key.pem node02.pem node02-key.pem 
* service-account.pem 

将/kube下的kube-apiserver文件放到 /usr/local/bin下 

```
mv ~/kube/kube-apiserver /usr/local/bin
cd /usr/local/bin
chmod 755 kube-apiserver 
```
service配置文件/usr/lib/systemd/system/kube-apiserver.service内容：

```
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
    --advertise-address=192.168.101.101 \
    --allow-privileged=true \
    --audit-log-maxage=30 \
    --audit-log-maxbackup=3 \
    --audit-log-maxsize=100 \
    --audit-log-path=/var/log/audit.log \
    --authorization-mode=Node,RBAC \
    --bind-address=0.0.0.0 \
    --client-ca-file=/etc/kubernetes/ssl/ca.pem \
    --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota \
    --enable-swagger-ui=true \
    --etcd-cafile=/etc/kubernetes/ssl/ca.pem \
    --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \
    --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \
    --etcd-servers=https://192.168.101.100:2379,https://192.168.101.101:2379,https://192.168.101.102:2379 \
    --event-ttl=1h \
    --insecure-bind-address=127.0.0.1 \
    --kubelet-certificate-authority=/etc/kubernetes/ssl/ca.pem \
    --kubelet-client-certificate=/etc/kubernetes/ssl/centos01.pem \
    --kubelet-client-key=/etc/kubernetes/ssl/centos01-key.pem \
    --kubelet-https=true \
    --service-account-key-file=/etc/kubernetes/ssl/service-account.pem \
    --service-cluster-ip-range=10.254.0.0/16 \
    --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
    --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
    --v=2
Restart=always
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
启动 

```
systemctl daemon-reload
systemctl enable kube-apiserver
systemctl start kube-apiserver
systemctl status kube-apiserver
```
**重要参数解释**

[https://blog.csdn.net/zhonglinzhang/article/details/90697495](https://blog.csdn.net/zhonglinzhang/article/details/90697495)  （中文）

| advertise-address   | 向集群成员发布apiserver的IP地址，该地址必须能够被集群的成员访问。如果为空，则使用 --bind-address，如果 --bind-address未指定，那么使用主机的默认接口。   | 
|:----:|:----|:----:|
| authorization-mode | 在安全端口上执行授权的有序的插件列表。默认值：AlwaysAllow  以逗号分隔的列表：AlwaysAllow,AlwaysDeny,ABAC,Webhook,RBAC,Node.   | 
| allow-privileged   | true允许特权模式的容器。默认值false   | 
| audit-log-maxage   |    | 
| audit-log-maxbackup   |    | 
| audit-log-maxsize   |    | 
| audit-log-path   |    | 
|    |    | 
| bind-address   | 监听安全端口的IP地址。必须能被集群的其他以及CLI/web客户机访问   | 
| tls-cert-file | 包含HTTPS的默认x509证书的文件。 CA证书，如果有的话，在服务器证书之后连接。如果启用了HTTPS服务，但未提供 --tls-cert-file和--tls-private-key-file，则会为公共地址生成自签名证书和密钥，并将其保存到--cert-dir指定的目录中。 | 
| tls-private-key-file | 包含和--tls-cert-file配对的默认x509私钥的文件   | 
| insecure-bind-address   | 地址绑定到不安全服务端口，(default 127.0.0.1)，将来会被remove   | 
|    |    | 
| client-ca-file   | 启用客户端证书认证。该参数引用的文件中必须包含一个或多个证书颁发机构，用于验证提交给该组件的客户端证书。如果客户端证书已验证，则用其中的 Common Name 作为请求的用户名   | 
| enable-admission   |    | 
| enable-swagger-ui   | 启用swagger ui   | 
|    |    | 
| etcd-cafile   | 保护etcd通信的SSL证书颁发机构文件   | 
| etcd-certfile   | 用于保护etcd通信的SSL证书文件   | 
| etcd-keyfile   | 用来保护etcd通信的SSL key文件   | 
| etcd-servers   | etcd服务器列表（格式：//ip:port），逗号分隔   | 
|    |    | 
| event-ttl   | 保留事件的时间。默认值 1h0m0s   | 
|    |    | 
|    |    | 
| kubelet-certificate-authority   |    | 
| kubelet-client-certificate   |    | 
| kubelet-client-key   |    | 
| kubelet-https   | kubelet通信使用https，默认值 true   | 
| service-account-key-file   | 包含PEM编码的x509 RSA或ECDSA私有或者公共密钥的文件。用于验证service account token。指定的文件可以包含多个值。参数可以被指定多个不同的文件。如未指定，--tls-private-key-file将被使用。如果提供了--service-account-signing-key，则必须指定该参数   | 
| service-cluster-ip-range   | CIDR表示IP范围，用于分配服务集群IP。不能与分配给pod节点的IP重叠 (default 10.0.0.0/24)   | 
|    |    | 
|    |    | 
|    |    | 
| v   |    | 


## 安装 kubectl 

在192.168.0.201上下载kubectl

```
cd ~/kube
wget https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubectl
mv kubectl /usr/local/bin
chmod 755 /usr/local/bin/kubectl
```
## 创建kubectl kubeconfig  文件

```

kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.config

kubectl config set-credentials admin \
  --client-certificate=/etc/kubernetes/ssl/admin.pem \
  --client-key=/etc/kubernetes/ssl/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=admin \
  --kubeconfig=admin.config

kubectl config use-context default --kubeconfig=admin.config
```
* admin.pem 证书 OU 字段值为 system:masters，kube-apiserver 预定义的 RoleBinding cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予了调用kube-apiserver 相关 API 的权限；
* 生成的 kubeconfig 被保存到 ~/.kube/config 文件；

**注意：**~/.kube/config文件拥有对该集群的最高权限，请妥善保管

kubectl get ns查看 

```
kubectl get ns 
NAME              STATUS   AGE
default           Active   4h31m
kube-node-lease   Active   4h32m
kube-public       Active   4h32m
kube-system       Active   4h32m
```
## kube-controller-manager

准备

* 下载文件
* 准备kube-controller-manager证书
* 准备kube-controller-manager.config 访问api-server的config文件 

将/kube下的kube-apiserver文件放到 /usr/local/bin下 

```
mv ~/kube/kube-controller-manager /usr/local/bin
cd /usr/local/bin
chmod 755 kube-controller-manager
```
service配置文件/usr/lib/systemd/system/kube-controller-manager.service内容：

```
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --address=0.0.0.0 \
  --allocate-node-cidrs=true \
  --cluster-cidr=10.244.0.0/16 \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --kubeconfig=/etc/kubernetes/kube-controller-manager.config\
  --leader-elect=true \
  --root-ca-file=/etc/kubernetes/ssl/ca.pem \
  --service-account-private-key-file=/etc/kubernetes/ssl/service-account-key.pem \
  --service-cluster-ip-range=10.254.0.0/16 \
  --use-service-account-credentials=true \
  --v=2
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```
**重要参数说明**

[https://www.jianshu.com/p/bdb153daba21](https://www.jianshu.com/p/bdb153daba21)

| address   |    | 
|:----|:----|
| allocate-node-cidrs   |    | 
| cluster-cidr   |    | 
| cluster-name   |    | 
| cluster-signing-cert-file   | 一个PEM编码的有X509 CA证书的文件，用于在集群内发布证书   | 
| cluster-signing-key-file   | 一个PEM编码的有RSA或ECDSA私钥的文件，用于对集群内的证书进行签名   | 
| kubeconfig   |    | 
| leader-elect   |    | 
| root-ca-file   |    | 
| service-account-private-key-file   | 用于签署 service account tokens 的 PEM 编码的RSA或ECDSA密钥文件   | 
| service-cluster-ip-range   | 集群中服务的CIDR范围。 要求--allocate-node-cidrs为true   | 
| use-service-account-credentials   |    | 
| v   |    | 


**启动 **

```
systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
systemctl status kube-controller-manager
kubectl get componentstatus
```

kube-config

```
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.config

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=/etc/kubernetes/ssl/kube-controller-manager.pem \
  --client-key=/etc/kubernetes/ssl/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.config

kubectl config use-context default --kubeconfig=kube-controller-manager.config
```
## kube-scheduler

准备

* 下载文件
* 准备证书kube-scheduler.pem, kube-scheduler-key.pem
* 准备kubeconfig, kube-scheudler.config 

将/kube下的kube-apiserver文件放到 /usr/local/bin下 

```
mv ~/kube/kube-scheduler /usr/local/bin
cd /usr/local/bin
chmod 755 kube-scheduler
```
kubeconfig 

```
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.config

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/etc/kubernetes/ssl/kube-scheduler.pem \
  --client-key=/etc/kubernetes/ssl/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.config

kubectl config use-context default --kubeconfig=kube-scheduler.config
```
```
vi /etc/kubernetes/config/kube-scheduler.yaml
```
```

apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/etc/kubernetes/kube-scheduler.config"
leaderElection:
  leaderElect: true
```
vi /usr/lib/systemd/system/kube-scheduler.service

```
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --config=/etc/kubernetes/config/kube-scheduler.yaml \
  --v=2
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
```
启动
```
sudo systemctl daemon-reload
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler
```
# 部署node节点

## 安装Docker

```
sudo yum install -y socat conntrack ipset
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install -y docker-ce docker-ce-cli containerd.io

sudo systemctl enable docker
sudo systemctl start docker
```

## 安装kubelet, kube-proxy

```
cd ~/kube
wget --timestamping \
https://github.com/containernetworking/plugins/releases/download/v0.8.5/cni-plugins-linux-amd64-v0.8.5.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.17.1/bin/linux/amd64/kubelet
```
安装二进制文件

```
cd ~/kube
chmod +x kube-proxy kubelet
sudo mv kube-proxy kubelet /usr/local/bin/
mkdir -p /opt/cni/bin
tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz --directory /opt/cni/bin/
scp cni-plugins-linux-amd64-v0.8.5.tgz root@192.168.0.202:/root/kube
cd ~/kube
mkdir -p /opt/cni/bin
tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz --directory /opt/cni/bin
scp cni-p
lugins-linux-amd64-v0.8.5.tgz root@192.168.0.203:/root/kube
cd ~/kube
mkdir -p /opt/cni/bin
tar -xvf cni-plugins-linux-amd64-v0.8.5.tgz --directory /opt/cni/bin
```
## kubelet配置

```
# node00 
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kubelet.config

kubectl config set-credentials system:node:centos00 \
  --client-certificate=/etc/kubernetes/ssl/centos00.pem \
  --client-key=/etc/kubernetes/ssl/centos00-key.pem \
  --embed-certs=true \
  --kubeconfig=kubelet.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:node:centos00 \
  --kubeconfig=kubelet.config

kubectl config use-context default --kubeconfig=kubelet.config
# node01
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kubelet.config


kubectl config set-credentials system:node:centos01 \
  --client-certificate=/etc/kubernetes/ssl/centos01.pem \
  --client-key=/etc/kubernetes/ssl/centos01-key.pem \
  --embed-certs=true \
  --kubeconfig=kubelet.config


kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:node:centos01 \
  --kubeconfig=kubelet.config


kubectl config use-context default --kubeconfig=kubelet.config
# node02
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kubelet.config

kubectl config set-credentials system:node:centos02 \
  --client-certificate=/etc/kubernetes/ssl/centos02.pem \
  --client-key=/etc/kubernetes/ssl/centos02-key.pem \
  --embed-certs=true \
  --kubeconfig=kubelet.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:node:centos02 \
  --kubeconfig=kubelet.config

kubectl config use-context default --kubeconfig=kubelet.config
```
/etc/kubernetes/config/kubelet.yaml

```
Kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/ssl/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.254.0.10"
runtimeRequestTimeout: "15m"
tlsCertFile: "/etc/kubernetes/ssl/node00.pem"
tlsPrivateKeyFile: "/etc/kubernetes/ssl/node00-key.pem"
```
vi /usr/lib/systemd/system/kubelet.service

```
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/etc/kubernetes/config/kubelet.yaml \
  --image-pull-progress-deadline=2m \
  --kubeconfig=/etc/kubernetes/kubelet.config \
  --pod-infra-container-image=cargo.caicloud.io/caicloud/pause-amd64:3.1 \
  --network-plugin=cni \
  --register-node=true \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  --v=2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
**重要参数解释**

| config   |    | 
|:----|:----|
| image-pull-progress-deadline   |    | 
| kubeconfig   |    | 
| pod-infra-container-image   |    | 
| network-plugin   |    | 
| register-node   |    | 
| cni-conf-dir   |    | 
| cni-bin-dir   |    | 
| v   |    | 

## kube-proxy配置

vi /etc/kubernetes/kube-proxy.config

```
kubectl config set-cluster kubernetes-training \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-proxy.config

kubectl config set-credentials system:kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.config

kubectl config set-context default \
  --cluster=kubernetes-training \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.config

kubectl config use-context default --kubeconfig=kube-proxy.config
```
vi /etc/kubernetes/config/kube-proxy-config.yaml

```
Kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/etc/kubernetes/kube-proxy.config"
mode: "iptables"
clusterCIDR: "10.244.0.0/16"
```
vi /usr/lib/systemd/system/kube-proxy.service

```
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \
  --config=/etc/kubernetes/config/kube-proxy-config.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
## 启动kubelet，kube-proxy

```
sudo systemctl daemon-reload
sudo systemctl enable kubelet kube-proxy
sudo systemctl start kubelet kube-proxy
```
## kubelet授权 

访问 Kubelet API 是获取 metrics、日志以及执行容器命令所必需的。

>这里设置 Kubeket --authorization-mode 为 Webhook 模式。Webhook 模式使用 SubjectAccessReview API 来决定授权。

创建 system:kube-apiserver-to-kubelet ClusterRole 以允许请求 Kubelet API 和执行大部分来管理 Pods 的任务:

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Kubernetes API Server 使用客户端凭证授权 Kubelet 为 kubernetes 用户，此凭证用 --kubelet-client-certificate flag 来定义。

绑定 system:kube-apiserver-to-kubelet ClusterRole 到 kubernetes 用户:

```
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: Group
    name: system:nodes
EOF
```
# 安装flannel网络插件

```
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
如果遇到墙不能访问，把下面文档里面的代码保存到本地文件kube-flannel.yml然后在本地执行。
```
https://shimo.im/docs/VWdqDhDg3wWJWqcQ/ 「kube-flannel.yml」，可复制链接后用石墨文档 App 或小程序打开 
```
# 安装kubedns插件 

```
kubectl apply -f https://raw.githubusercontent.com/caicloud/kube-ladder/master/tutorials/resources/coredns.yaml
```
建立一个 busybox 部署:

```
kubectl run busybox --image=busybox:1.28.3 --command -- sleep 3600
```
列出 busybox 部署的 Pod：
```
kubectl get pods -l run=busybox
```
输出为
```
NAME                      READY   STATUS    RESTARTS   AGE
busybox-d967695b6-29hfh   1/1     Running   0          61s
```
查询 busybox Pod 的全名:
```
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```
在 busybox Pod 中查询 DNS：
```
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```
输出为
```
Server:    10.254.0.10
Address 1: 10.254.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.254.0.1 kubernetes.default.svc.cluster.local
```
# HAProxy 和 KeepAlived 

在3台master节点上安装haproxy和 keepalvied

```
yum install haproxy
yum install keepalived
```
## KeepAlived

keepalived是以VRRP协议为实现基础的，VRRP全称Virtual Router Redundancy Protocol，即虚拟路由冗余协议。

虚拟路由冗余协议，可以认为是实现路由器高可用的协议，即将多个提供相同功能的路由器组成一个路由器组，这个组里面有一个master和多个backup，master上面有一个对外提供服务的vip（该路由器所在局域网内其他机器的默认路由为该vip），master会发组播，当backup收不到vrrp包时就认为master宕掉了，这时就需要根据VRRP的优先级来选举一个backup当master。这样的话就可以保证路由器的高可用了。



```
cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
EOF
```
在3台节点上配置keepalived

/etc/keepalived/keepalived.conf

```

vrrp_script haproxy-check {
    script "killall -0 haproxy"
    interval 2
    weight -2
    fall 10
    rise 2
}
 
vrrp_instance haproxy-vip {
    state MASTER
    priority 250
    interface ens192
    virtual_router_id 47
    advert_int 3
 
    unicast_src_ip 192.168.101.100
    unicast_peer {
        192.168.101.101
        192.168.101.102
    }
 
    virtual_ipaddress {
        192.168.101.110
    }
 
    track_script {
        haproxy-check
    }
}
```
* interface ens33 中的ens33是网卡的名字，要改成你本机自己的，可以用nmtui工具查看
* unicast_src_ip 为当前节点IP，unicast_peer为另外两台节点IP
## HAProxy 

HAProxy 一旦启动，会做三件事情：

处理客户端接入的连接

周期性检查 server 的状态（健康检查）

1. 与其他 haproxy 交换信息

处理客户端接入的连接，是目前为止最为复杂的工作，因为配置有太多的可能性，但总的说来有 9 个步骤：

配置实体 frontend 拥有监听 socket，HAProxy 从它的监听 socket 处接受客户端连接
1. 根据 frontend 配置的规则，对连接进行处理。可能会拒绝一些连接，修改一些 headers，或是拦截连接，执行内部的小程序，比如统计页面，或者 CLI
1. backend 是定义后端 servers，以及负载均衡规则的配置实体，frontend 完成上面的处理后将连接转发给 backend。
1. 根据 backend 定义的规则，对连接进行处理
1. 根据负载均衡规则对连接进行调度
1. 根据 backend 定义的规则对 response data 进行处理
1. 根据 frontend 定义的规则对 response data 进行处理
1. 发起一个 log report，记录日志
1. 在 HTTP 模式，回到第二步，等待新的请求，或者关闭连接。

frontend 和 backend 有时被认为是 half-proxy，因为他们对一个 end-to-end（端对端）的连接只关心一半：frontend 只关心 client，backend 只关心 server。

HAProxy 也支持 full proxy，通过对 frontend 和 backend 的准确联合来工作。

HAProxy 工作于 HTTP 模式时，配置被分裂为 frontend 和 backend 两个部分，因为任何 frontend 可能转发连接给 任何 backend。

HAProxy 工作于 TCP 模式时，实际上就是 full proxy 模式，配置中使用 frontend 和 backend 不能提供更多的好处，在 full proxy 模式，配置文件更有可读性。



在3台节点上配置haproxy

/etc/haproxy/haproxy.cfg

```
cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_nonlocal_bind = 1
EOF

frontend k8s-api
  bind 192.168.0.210:443
  bind 127.0.0.1:443
  mode tcp
  option tcplog
  default_backend k8s-api

backend k8s-api
  mode tcp
  option tcplog
  option tcp-check
  balance roundrobin
  default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
  server k8s-api-1 192.168.0.201:6443 check
  server k8s-api-2 192.168.0.202:6443 check
  server k8s-api-3 192.168.0.203:6443 check
```
```
重启keepalived和haproxy
systemctl enable keepalived haproxy
systemctl restart keepalived haproxy
```
修改以下组件的kube apiserver地址至https://192.168.0.210

* kubectl
* kube-controller-manager
* kube-scheduler
* kubelet
* kube-proxy
```
systemctl restart kube-controller-manager kube-scheduler kubelet kube-proxy
```

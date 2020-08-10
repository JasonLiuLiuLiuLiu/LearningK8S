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
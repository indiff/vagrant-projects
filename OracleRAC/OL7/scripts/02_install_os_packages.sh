#！/bin/bash
# 本脚本用于安装和更新 Oracle RAC 环境所需的操作系统基础软件包和依赖
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
#
# LICENSE UPL 1.0
#
# Copyright (c) 1982-2024 Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      02_install_os_packages.sh
#
#    DESCRIPTION
#      Install and update OS packages
#
#    NOTES
#       DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
#
#    AUTHOR
#       Ruggero Citton - RAC Pack, Cloud Innovation and Solution Engineering Team
#
#    MODIFIED   (MM/DD/YY)
#    rcitton     03/30/20 - VBox libvirt & kvm support
#    rcitton     11/06/18 - Creation
#
#    REVISION
#    20240603 - $Revision: 2.0.2.1 $
#
#│▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒│

# 加载环境变量配置文件，包含主机名、ASM 类型等参数
. /vagrant/config/setup.env

if [[ -e /vagrant/ORCL_software/oracle_rac_rpms.zip ]]; then
  yum install -y /vagrant/ORCL_software/unzip*.rpm
  TMP_RPM_DIR=/tmp/oracle_rac_rpms
  unzip -o /vagrant/ORCL_software/oracle_rac_rpms.zip -d $TMP_RPM_DIR
  yum install -y $TMP_RPM_DIR/*.rpm
  rm -rf $TMP_RPM_DIR
else
  # 安装基础工具包
  echo "-----------------------------------------------------------------"
  echo -e "${INFO}`date +%F' '%T`: 安装基础软件包"
  echo "-----------------------------------------------------------------"
  yum install -y deltarpm expect tree unzip zip   # 常用工具包
  yum install -y oracle-database-preinstall-19c   # Oracle 19c 预安装包，自动配置内核参数和依赖


  # 如果 ASM_LIB_TYPE 变量为 ASMLIB，则安装 oracleasm-support 支持包
  if [ "${ASM_LIB_TYPE}" == "ASMLIB" ]
  then
    yum install -y oracleasm-support
  fi


  # 安装额外依赖包，涵盖编译、网络、Python、ODBC、时钟同步等
  echo "-----------------------------------------------------------------"
  echo -e "${INFO}`date +%F' '%T`: 安装额外依赖包"
  echo "-----------------------------------------------------------------"
  yum install -y bc                      # 计算器工具
  yum install -y binutils                # 二进制工具集
  yum install -y compat-libcap1           # 兼容性库
  yum install -y compat-libstdc++-33      # 旧版 C++ 兼容库
  yum install -y compat-libstdc++-33.i686 # 32 位兼容库
  yum install -y fontconfig-devel         # 字体配置开发包
  yum install -y glibc.i686               # 32 位 glibc
  yum install -y glibc                    # 64 位 glibc
  yum install -y glibc-devel.i686         # 32 位 glibc 开发包
  yum install -y glibc-devel              # 64 位 glibc 开发包
  yum install -y ksh                      # Korn shell
  yum install -y libaio.i686              # 32 位异步 IO
  yum install -y libaio                   # 64 位异步 IO
  yum install -y libaio-devel.i686        # 32 位异步 IO 开发包
  yum install -y libaio-devel             # 64 位异步 IO 开发包
  yum install -y libX11.i686              # 32 位 X11 库
  yum install -y libX11                   # 64 位 X11 库
  yum install -y libXau.i686              # 32 位 X11 授权库
  yum install -y libXau                   # 64 位 X11 授权库
  yum install -y libXi.i686               # 32 位 X11 输入扩展
  yum install -y libXi                    # 64 位 X11 输入扩展
  yum install -y libXtst.i686             # 32 位 X11 测试扩展
  yum install -y libXtst                  # 64 位 X11 测试扩展
  yum install -y libgcc.i686              # 32 位 GCC 运行库
  yum install -y libgcc                   # 64 位 GCC 运行库
  yum install -y librdmacm-devel          # RDMA 通信管理开发包
  yum install -y libstdc++.i686           # 32 位 C++ 运行库
  yum install -y libstdc++                # 64 位 C++ 运行库
  yum install -y libstdc++-devel.i686     # 32 位 C++ 开发包
  yum install -y libstdc++-devel          # 64 位 C++ 开发包
  yum install -y libxcb.i686              # 32 位 XCB 库
  yum install -y libxcb                   # 64 位 XCB 库
  yum install -y make                     # 编译工具
  yum install -y nfs-utils                # NFS 支持
  yum install -y net-tools                # 网络工具
  yum install -y python                   # Python 运行环境
  yum install -y python-configshell       # Python configshell 库
  yum install -y python-rtslib            # Python rtslib 库
  yum install -y python-six               # Python 2/3 兼容库
  yum install -y smartmontools            # 硬盘监控工具
  yum install -y sysstat                  # 性能监控工具
  yum install -y targetcli                # 存储目标管理工具
  yum install -y unixODBC                 # ODBC 支持
  yum install -y chrony                   # 时间同步服务
  yum install -y policycoreutils-python   # SELinux 管理工具
  yum install readline rlwrap -y
fi

# 安装 inotify 工具包（通过本地 rpm 包）
rpm -ivh /vagrant/ORCL_software/inotify-tools-3.14-9.el7.x86_64.rpm
# 以下为可选的系统更新操作，默认注释掉
echo "-----------------------------------------------------------------"
echo -e "${INFO}`date +%F' '%T`: 执行 yum update 升级系统"
echo "-----------------------------------------------------------------"
yum -y update



echo "关闭ZEROCONF"
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
echo "关闭 avahi 服务"
systemctl stop avahi-dnsconfd
systemctl stop avahi-daemon
systemctl disable avahi-dnsconfd.socket
systemctl disable avahi-daemon.socket

echo "关闭selinux"
sed -i -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
setenforce permissive
cat -A /etc/selinux/config
getenforce

echo "关闭防火墙"
systemctl stop firewalld
systemctl disable firewalld
# 关闭大页
echo "关闭大页"
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="transparent_hugepage=never/g' /etc/default/grub
sudo echo "never" > /sys/kernel/mm/transparent_hugepage/enable
sudo echo "never" > /sys/kernel/mm/transparent_hugepage/defrag

# session    required     /lib/security/pam_limits.so
# 添加PAM认证模块
cat > /etc/pam.d/login <<EOF
session required pam_limits.so
EOF


## 检查是否开启NUMA
dmesg | grep -i numa
## 关闭NUMA
sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="numa=off/g'  /etc/default/grub
dmesg | grep -i numa


## 调整MTU值
NETNAME=`ifconfig | grep -v docker | grep -v lo | grep flags | awk -F: '{print $1}' | head -n 1`
echo "调整 $NETNAME MTU值"
ifconfig $NETNAME mtu 9000
cat >> /etc/sysconfig/network-scripts/ifcfg-$NETNAME <<EOF
EOFMTU=9000
EOF
cat /etc/sysconfig/network-scripts/ifcfg-$NETNAME
ifconfig $NETNAME down
ifconfig $NETNAME up
netstat -in


## 修改lo回环网卡的MTU值当 linux 系统上 lo 接口的 MTU 过大，会存在一些 BUG,检查 LO 网卡的 MTU，如果是 65536，需要修改为16436参见 MOS 文档：ORA-27301: OS Failure Message: No Buffer Space Available /   ORA-27302: failure occurred at: sskgxpsnd2Source Script (Doc ID 2322410.1)
echo "lo回环网卡的MTU值"
ifconfig lo mtu 16436
cat >> /etc/sysconfig/network-scripts/ifcfg-lo <<EOF
EOFMTU=16436
EOF
cat /etc/sysconfig/network-scripts/ifcfg-lo
ifconfig lo down
ifconfig lo up
netstat -in

#----------------------------------------------------------
# 文件结束
#----------------------------------------------------------


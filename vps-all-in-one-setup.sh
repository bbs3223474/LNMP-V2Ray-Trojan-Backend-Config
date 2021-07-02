#!/bin/sh
clear
echo "                     ===简易VPS科学上网后端程序安装脚本==="
echo "       ===此脚本将会为系统全新的VPS提供以下软件/依赖的安装==="
echo "                   1. Python 3.8.1 / Pip 3.8.1（默认不安装，若需要使用请手动编辑脚本并手动修复yum）"
echo "                   2. vim, nano文本编辑器"
echo "                   3. wget, git, net-tools基础依赖"
echo "                   4. ServerSpeeder 锐速"
echo "                   5. SSR-Manyuser后端程序及其依赖"
echo "                   6. v2ray服务器端（含简易操作界面）"
echo ""
echo "===系统要求：CentOS 6.x以上，内核为3.10.0-229.1.2.el7.x86_64，"
echo "1GB最小内存或512MB+Swap，默认网卡为eth0==="
echo "===请确保VPS内存容量大于等于1GB或启用了swap分区，否则可能导致安装失败==="
echo ""
echo "**************************重要提示**************************"
echo "强烈推荐在系统全新的VPS上使用本脚本，本脚本暂不支持已有软件包的判断能力，"
echo "也暂不支持不安装其中的某些内容。一旦执行，将会从头至尾运行，直到全部完成或出错中止。"
echo "若VPS系统并非全新，则可能导致一些不可预知的问题，包括已有软件包被替代等，"
echo "请自行承担风险。"
echo "CentOS 8.x系统极可能无法安装3.x内核，使锐速无法正常安装，请谨慎使用，"
echo "或可以编辑此脚本以忽略内核及锐速的安装，并手动安装BBR作为替代。"
echo ""
echo "         请按任意键开始安装Python/Pip，否则请使用Ctrl+C退出脚本"
read -n 1
cd /root

## Python 3.8.1 & Pip 3.8.1安装并配置
## 安装后暂不能修复yum的使用，请参考网络教程修复。
## 将yum相关的执行命令从“#！/usr/bin/python”改为“#！/usr/bin/python2.7.5”即可
## 本版块默认不安装，若需要安装请去掉以下行的注释。

# yum -y install gcc zlib zlib-devel
# wget https://www.python.org/ftp/python/3.8.1/Python-3.8.1.tgz
# tar -zxvf Python-3.8.1.tgz && cd Python-3.8.1
# mkdir /usr/local/python3.8.1
# ./configure --prefix=usr/local/python3.8.1
# make && make install
# mv /usr/bin/python /usr/bin/python2.7.5
# ln -s /usr/local/python3.8.1/bin/python3.8 /usr/bin/python
# ln -s /usr/local/python3.8.1/bin/pip3.8 /usr/bin/pip

clear
echo "Python与Pip安装已经完成，请按任意键继续安装vim和nano文本编辑器"
read -n 1

## vim & nano 文本编辑器安装
yum -y install vim nano

clear
echo "vim与nano文本编辑器已经安装完成，请按任意键继续安装基础依赖程序"
read -n 1

## wget & git & net-tools 基础依赖安装
yum -y install wget git net-tools
clear
echo "基础依赖已经安装完成，请按任意键继续安装内核"
read -n 1

## Linux-3.10.0-229.1.2.el7.x86_64 内核安装
# rpm -ivh https://buildlogs.centos.org/c7.01.u/kernel/20150327030147/3.10.0-229.1.2.el7.x86_64/kernel-3.10.0-229.1.2.el7.x86_64.rpm --force --nodeps
clear
echo "内核已经安装完成，请按任意键继续安装锐速"
read -n 1

## ServerSpeeder 锐速安装
wget -N --no-check-certificate https://raw.githubusercontent.com/91yun/serverspeeder/master/serverspeeder.sh && chmod +x serverspeeder.sh && bash serverspeeder.sh
clear
echo "锐速已经安装完成，请按任意键继续安装SSR-Manyuser后端程序"
read -n 1

## ServerSpeeder 锐速卸载
chattr -i /serverspeeder/etc/apx* && /serverspeeder/bin/serverSpeeder.sh uninstall -f

## 一键加速脚本
wget -N --no-check-certificate "https://github.000060000.xyz/tcp.sh" && chmod +x tcp.sh && ./tcp.sh

## TCPA加速
wget https://raw.githubusercontent.com/ivmm/TCPA/master/tcpa.sh && chmod +x tcpa.sh && sh tcpa.sh

## 添加3GB虚拟内存
dd if=/dev/zero of=/var/swapfile bs=1024 count=3072000 && mkswap /var/swapfile && chmod -R 0600 /var/swapfile && swapon /var/swapfile && echo "/var/swapfile swap swap defaults 0 0" >> /etc/fstab

## LNMP 1.8 一键安装包
wget http://soft.vpser.net/lnmp/lnmp1.8.tar.gz -cO lnmp1.8.tar.gz && tar zxf lnmp1.8.tar.gz && cd lnmp1.8 && ./install.sh lnmp

## V2ray-Poseidon 后端程序
curl -o go.sh -L -s https://raw.githubusercontent.com/ColetteContreras/v2ray-poseidon/master/install-release.sh && bash go.sh
rm /etc/v2ray/config.json && nano /etc/v2ray/config.json
rm /usr/local/nginx/conf/vhost/--
nano /usr/local/nginx/conf/vhost/--

## Soga 后端程序
bash <(curl -Ls https://raw.githubusercontent.com/sprov065/soga/master/install.sh)

## 关闭系统防火墙。若不需要关闭，请手动注释掉以下行。

## 关闭CentOS 7防火墙（默认）
systemctl stop firewalld
systemctl disable firewalld

## 关闭CentOS 6防火墙
# service iptables stop
# chkconfig iptables off

clear
echo "SSR-Manyuser后端程序安装完毕，请在全部结束后手动配置userapiconfig.py与usermysql.json中的相关内容。"
echo "请按任意键继续安装v2ray服务器端程序"
read -n 1

## V2ray 服务器端一键安装脚本（来自https://github.com/Jrohy/multi-v2ray）
source <(curl -sL https://multi.netlify.com/v2ray.sh) --zh
clear
echo "恭喜！所有安装过程已经结束，请手动配置相关内容即可正常开始使用。"
echo "现在，你可以按下Ctrl+C退出脚本。"
# LNMP+V2Ray+Trojan后端配置脚本范例
### 写在开头：针对使用了LNMP+V2Ray-Poseidon+Soga（Trojan）后端程序的VPS，提供本人多年来摸爬滚打的经验和配置脚本案例，能解决大多数疑难杂症。
### 本Repo仅代表个人经验，不代表标准化、规范化的操作流程。其中多数操作来自各个程序的官方说明文档或教程，在这里非常感谢LNMP、V2Ray-Poseidon和Soga程序的作者以及他们编写的说明文档。若要获取更多信息，请访问以下链接：
- V2Ray-Poseidon: https://github.com/ColetteContreras/v2ray-poseidon
- Soga: https://github.com/sprov065/soga
- LNMP: https://lnmp.org
#### 本Repo旨在为希望自行购买VPS搭建飞机场、出租给身边熟人用（你们不会真的想拿来卖给陌生人赚钱吧，真嫌活腻了？），但是又无奈卡在诸如：不知道如何配置LNMP、V2Ray如何与Trojan后端并存并且不占用443端口、客户端莫名其妙出现“context deadline exceeded”提示等问题上，进退两难的同学，提供个人的见解和这几年来累死累活积累出来的实践经验。我不是程序员，只是个英语还行的文科生，关于Linux、SSH、LNMP等等代码方面的东西我懂得不多，只是一直照葫芦画瓢，最终在自己身上实践取得成功，这次给大家一次性整理起来了而已。有些内容不代表官方的解决方案，也不一定是标准化的流程，所以欢迎有经验的同学在issue页面给出自己的见解，但是有些问题我不一定能回答，因为我说了，我不懂程序相关的东西。
---
本说明文档将跳过选购VPS、域名解析、前端面板程序搭建、测速等与后端搭建无关的内容。阅读本说明文档即默认你已经做好了前述事项。
---
#### 配置基本目标
1. 使用CentOS7系统
2. 修改lnmp.conf并完成LNMP程序的安装
3. 不使用CloudFlare进行CDN加速（因为我觉得这玩意对于网速、延迟比较好的服务器，在大陆地区反而减速，没什么意义），也不配置其他任何CDN
4. 让Nginx转发来自443（或其他自定义SSL端口）的请求，分别处理V2Ray和Trojan的流量，使两个后端程序可以在同一台VPS上运行不产生任何冲突
5. 保留LNMP用于正常搭建网页的能力
6. 全程使用LNMP创建网站配置、申请SSL证书
7. （可选）解决潜在的443端口被拦截问题
8. 寻找最适合你的拥塞和队列算法（TCP加速脚本）
---
#### 一、安装CentOS 7下的一些基础工具
执行以下代码，安装vim、nano文本编辑器；wget、git、net-tools、socat依赖。自己有其他习惯或见解的可以跳过此步骤。
```
yum -y install vim nano wget git net-tools socat
```
注：所有代码都默认不包含“sudo”在前，本教程默认你已获得VPS的Root权限，若还没有进行操作的，请参见“附录：CentOS获取Root权限”一节，或自行在命令前加入“sudo”，下同。
#### 二、修改并安装LNMP
提示：如果后续LNMP安装过程中出现诸如“Error 1”之类，安装到中途停止，没有提示“LNMP Installed”的，极有可能是内存不足导致。可以直接执行下述代码，添加大约3GB的虚拟内存（建议VPS内存不足2GB的都进行添加）：
```
dd if=/dev/zero of=/var/swapfile bs=1024 count=3072000 && mkswap /var/swapfile && chmod -R 0600 /var/swapfile && swapon /var/swapfile && echo "/var/swapfile swap swap defaults 0 0" >> /etc/fstab
```
该虚拟内存文件会一直存在于硬盘，并开机自动调用。如果安装后不再需要，请参照该教程进行停用和删除：https://blog.csdn.net/ausboyue/article/details/73433990

1. 从https://lnmp.org 的“安装”页面，复制安装代码，但最后的“&& install.sh lnmp”不要复制，例如：
```
wget http://soft.vpser.net/lnmp/lnmp1.8.tar.gz -cO lnmp1.8.tar.gz && tar zxf lnmp1.8.tar.gz && cd lnmp1.8
```
2. 若下载成功，则目前你理应处在“lnmp1.8”目录下（版本号依照官网）。
3. 执行以下代码，打开文本编辑器，修改lnmp.conf。
```
vim lnmp.conf
```
4. 参照本Repo中的lnmp.conf，在“Nginx_Modules_Options”后加上“--with-stream_ssl_preread_module”，最终代码应如下所示：
```
# yum install -y gcc gcc-c++
Download_Mirror='https://soft.vpser.net'

Nginx_Modules_Options='--with-stream_ssl_preread_module'
PHP_Modules_Options=''
```
5. 按下ESC键，确保当前处于英文输入状态，输入一个冒号，然后输入wq，切记为小写，然后回车，保存退出文本编辑器。
6. 执行以下代码，完成LNMP的安装（教程请参见网络，若不需要在当前VPS上搭建网页或前端程序，则无需安装MySQL）
```
./install.sh lnmp
```
7. 按照自身及VPS配置情况，自行选择各个程序的版本，耐心等待LNMP安装完成即可。
#### 三、配置网页脚本
1. 在LNMP安装好之后，输入以下命令：
```
lnmp vhost add
```
完成用于V2Ray和Trojan后端程序的2个网页脚本的创建，以及对应SSL证书的申请。
2. 针对V2Ray，假设你创建的网站名称为“v2r.example.com”，则执行以下命令，删除默认的配置脚本：
```
rm /usr/local/nginx/conf/vhost/v2r.example.com.conf
```
回车后输入y，再次回车，即可删除。
3. 然后执行以下命令，新建一个同名文件：
```
nano /usr/local/nginx/conf/vhost/v2r.example.com.conf
```
此处使用nano而不是vim的主要原因是，某些VPS在使用vim粘贴文本的时候，会出现乱码、错位的情况，此时nano就比较保险一些。
4. 参照本Repo中的example.com.conf文件，将其中的内容先全部粘贴至文本编辑器中（以XShell为例，复制后按下Shift+Ins键粘贴）。
5. 然后参照以下内容，对应位置进行修改：
```
server
    {
        listen 80;
        #listen [::]:80;
        server_name example.com ; ## 此处修改为你自己的域名
        index index.html index.htm index.php default.html default.htm default.php;
        root  /home/wwwroot/v2ray;  ## 此处修改为你在使用lnmp vhost add时设置的网站目录
（中略）
server {
  listen 1444 ssl; ## 此处原本为“443”，请先按照“1444”进行设定，后续解释原因
  listen [::]:1444 ssl;
  ssl_certificate       /usr/local/nginx/conf/ssl/example.com/fullchain.cer; ## 将此处的所有“example.com”修改为你的域名，注意第二行末尾的“.key”不要删除
  ssl_certificate_key   /usr/local/nginx/conf/ssl/example.com/example.com.key;
（中略）
  server_name           example.com; ## 此处修改为你的域名
  location /welcome/ {  ## 此处的“/welcome/”和后续的“10086”端口都暂且不做修改，后续解释原因
    if ($http_upgrade != "websocket") {
        return 404;
    }
    proxy_redirect off;
    proxy_pass http://127.0.0.1:10086;
```
6. 修改完成后，按下键盘的Ctrl+O（字母），回车，保存修改，再按下Ctrl+X退出文本编辑器。
7. 针对Trojan，假设你创建的网站名称为“trj.example.com”，则执行以下命令，打开文本编辑器：
```
nano /usr/local/nginx/conf/vhost/trj.example.com.conf
```
8.将关于443端口的所有文段全部删除，从“server { listen 443 ssl;” 开始，到最后一个 “}” 结束，也就是说你要删掉如下内容：
```
server
    {
        listen 443 ssl;
（中略）
}
```
9. 删除完毕后，按照上述方法保存修改，并退出文本编辑器。
#### 四、配置Nginx端口转发
1. 执行以下命令，打开nginx配置文件：
```
vim /usr/local/nginx/conf/nginx.conf
```
2. 参照本Repo中的nginx_add.conf文件，将其中的内容全部粘贴至nginx.conf的events节之后、http节之前，并修改必要内容，最后看起来应该如下：
```
events
    {
        use epoll;
        worker_connections 51200;
        multi_accept off;
        accept_mutex off;
    }

stream {
    # map domain to different name
    map_hash_max_size 4096; ## 这两行“map_size”在Repo的文件中并没有，默认不需要添加，但如果后续LNMP重启时提示“map_hash_bucket_size”相关的错误，则需要使用
    map_hash_bucket_size 1024;
    map $ssl_preread_server_name $backend_name {
       # www.example.com web; ## 此处对应其他网页，例如你的WordPress，或是前端面板等，如有需要可以开启
        v2r.example.com vmess; ## 本行与下一行分别对应V2Ray和Trojan，修改成你的域名
        trj.example.com trojan;
    # default value for not matching any of above（如果请求的网址不符合上述设定，则默认转至）
        default trojan; ## 默认转至trojan，请自行设定，也可以不修改
    }

#    upstream web { ## 此处的“web”，与下面的“trojan”、“vmess”都可以自行设定成其他名称，但要与上面同步修改，以建立对应关系
#       server 127.0.0.1:1442;
#   }

    upstream trojan {
        server 127.0.0.1:1443;
    }

    upstream vmess {
        server 127.0.0.1:1444; ## 1444即对应转发到V2Ray后端的端口，这里的“1444”与第二节设置的必须一致，你也可以自行修改成其他端口号
    }

    server {
        listen 443 reuseport;
        listen [::]:443 reuseport;
        proxy_pass  $backend_name;
        ssl_preread on;
    }
}

http
    {
        include       mime.types;
        default_type  application/octet-stream;
```
3. :wq 保存退出文本编辑器。
4. 输入以下代码，重启LNMP，如果不报错，则证明已经完成LNMP侧的配置工作。
```
lnmp restart
```

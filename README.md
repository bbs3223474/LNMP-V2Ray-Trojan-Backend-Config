# LNMP+V2Ray+Trojan后端配置脚本范例
### 写在开头：针对使用了诸如SSPanel、V2Board等前端程序，并打算使用V2Ray-Poseidon+Soga（Trojan）后端程序的VPS，提供本人多年来摸爬滚打的经验和配置脚本案例，能解决大多数疑难杂症。
### 本Repo仅代表个人经验，不代表标准化、规范化的操作流程。其中多数操作来自各个程序的官方说明文档或教程，在这里非常感谢LNMP、V2Ray-Poseidon和Soga程序的作者以及他们编写的说明文档。若要获取更多信息，请访问以下链接：
- V2Ray-Poseidon: https://github.com/ColetteContreras/v2ray-poseidon
- Soga: https://github.com/sprov065/soga
- LNMP: https://lnmp.org
#### 本Repo旨在为希望自行购买VPS搭建飞机场、出租给身边熟人用（你们不会真的想拿来卖给陌生人赚钱吧，真嫌活腻了？），但是又无奈卡在诸如：不知道如何配置LNMP、V2Ray如何与Trojan后端并存并且不占用443端口、客户端莫名其妙出现“context deadline exceeded”提示等问题上，进退两难的同学，提供个人的见解和这几年来累死累活积累出来的实践经验。我不是程序员，只是个英语还行的文科生，关于Linux、SSH、LNMP等等代码方面的东西我懂得不多，只是一直照葫芦画瓢，最终在自己身上实践取得成功，这次给大家一次性整理起来了而已。有些内容不代表官方的解决方案，也不一定是标准化的流程，所以欢迎有经验的同学在issue页面给出自己的见解，但是有些问题我不一定能回答，因为我说了，我不懂程序相关的东西。
---
本说明文档将跳过选购VPS、域名解析、前端面板程序搭建、测速等与后端搭建无关的内容。阅读本说明文档即默认你已经做好了前述事项。
---
#### 配置基本目标
~~1. 使用CentOS7系统~~
1. 使用CentOS Stream系统（CentOS 7已经停止支持，8也基本上处于半死不活的状态了，不建议继续使用，否则yum还得换源）
2. 修改lnmp.conf并完成LNMP程序的安装
3. ~~不使用CloudFlare进行CDN加速（因为我觉得这玩意对于网速、延迟比较好的服务器，在大陆地区反而减速，没什么意义。当然，挂CDN也有利于增强服务器自身的隐藏，还能避免潜在的DDoS攻击，但个人目前还没碰到V2Ray和Trojan节点被封IP的事，所以用不用看你自己），也不配置其他任何CDN~~ （可选）使用亚马逊CloudFront CDN进行加速，见：“附录1.1 使用亚马逊CloudFront CDN解决443端口被封”
4. 让Nginx转发来自443（或其他自定义SSL端口）的请求，分别处理V2Ray和Trojan的流量，使两个后端程序可以在同一台VPS上运行不产生任何冲突
5. 保留LNMP用于正常搭建网页的能力
6. 全程使用LNMP创建网站配置、申请SSL证书
7. （可选）解决潜在的443端口被拦截问题
8. 寻找最适合你的拥塞和队列算法（TCP加速脚本）
9. （可选）配置IPv6以适应最新网络环境
---
#### 一、安装CentOS Stream下的一些基础工具
执行以下代码，安装vim、nano文本编辑器；wget、git、net-tools、socat依赖。自己有其他习惯或见解的可以跳过此步骤。
```
yum -y install vim nano wget git net-tools socat
```
注：所有代码都默认不包含“sudo”在前，本教程默认你已获得VPS的Root权限，若还没有进行操作的，请参见“附录2：CentOS获取Root权限”一节，或自行在命令前加入“sudo”，下同。
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
#### 8. 安装完成后，命令行将默认停留在lnmp安装程序的目录下。后续步骤需要继续下载各类脚本和程序，建议重新cd到你需要下载到的目录中再执行相关命令，以便管理。此步骤将不再赘述。若希望直接下载到登录VPS后默认进入的root目录，可执行以下命令：
```
cd ~
或
cd /root
```
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
8. 将关于443端口的所有文段全部删除，从“server { listen 443 ssl;” 开始，到最后一个 “}” 结束，也就是说你要删掉如下内容：
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
        server 127.0.0.1:1444; ## 1444即对应转发到V2Ray后端监听的端口，这里的“1444”与第三节第5点的端口号的必须一致，你也可以自行修改成其他端口号
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
#### 五、前端配置节点信息
1. 假设前端使用来自Anankke的SSPanel-Uim，则进入管理后台-节点管理，添加一个V2Ray节点，需要配置的内容参照下述：
```
节点地址：节点URL;nginx监听端口号;AlterID;tls;ws;path=/welcome/|host=节点URL
例：example.com;443;2;tls;ws;path=/welcome/|host=example.com
节点IP不需要填写，只要节点地址填写正确，IP地址会自动解析出来。

说明：默认情况下，我们的节点URL与尾部的host是一致的，如果不是一致的估计你也不用看我这个教程了。
nginx监听端口号参照第四节中nginx.conf的listen 443 reuseport和listen [::]:443 reuseport两行进行填写。
path为刚才案例中提到的/welcome/，AlterID默认为2（位于v2ray的config.json内），你可以自己进行修改，但是一定要与后端配置完全一致。

节点类型：V2Ray
等级、分组、流量、限速等自行设定即可。
```
2. 再添加一个Trojan节点：
```
节点地址：节点URL;port=nginx监听端口号#soga监听端口号（即nginx转发端口号）
例：example.com;port=443#1443
节点IP同样不需要填写。

说明：节点URL与V2Ray的不能相同，请参照你配置的lnmp vhost。
443端口为nginx.conf中的listen 443 reuseport，1443则是upstream trojan中的转发端口号，以告诉soga监听1443端口而非443，避免冲突。

节点类型：Trojan
等级、分组、流量、限速等自行设定即可。
```
3. 至此，前端节点配置完毕。
#### 六、安装V2Ray与Trojan后端程序
1. 粘贴以下代码并安装V2Ray-Poseidon：
```
curl -o go.sh -L -s https://raw.githubusercontent.com/ColetteContreras/v2ray-poseidon/master/install-release.sh
bash go.sh
```
2. 粘贴以下代码并安装Soga（Trojan后端）：
```
bash <(curl -Ls https://blog.sprov.xyz/soga.sh)
```
3. 执行以下命令，编辑V2Ray的配置文件：
```
vim /etc/v2ray/config.json
```
4. 参照本Repo中的v2ray_config.json（该文件已经可以实现最基础的V2Ray后端功能，需求与我相同的同学，可以直接删除自带配置文件，新建并粘贴我的代码进去），修改以下对应位置的内容：
```
{
  "poseidon": {
    "panel": "sspanel-webapi",
    "license_key": "",
    "nodeId": 1, # 参照第五节第1点创建的节点ID填写
    // every N seconds
    "checkRate": 60,
    "panelUrl": "https://sspanel.exampl.com", # 改为你管理面板的URL
    "panelKey": "muKey", # 改为你管理面板的mukey
    "user": {
      // inbound tag, which inbound you would like add user to
      "inboundTag": "proxy",
      "level": 1,
      "alterId": 2, # 与管理面板前端设置保持一致，参见第五节
      "security": "none"
    }
  },
  "log": {
    "loglevel": "debug"
  },
  "inbounds": [
    {
      "port": 10086, # 与第四节设置的“10086”端口保持一致，一处修改另一处也必须对应修改。
      "protocol": "vmess",
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/welcome/" # 与第四节设置的“/welcome/”保持一致，具体内容基本无所谓，也可以没有后面的斜杠等等，如“/123”、“/A12nFs9/”，确保完全一致包括斜杠就可以
（略）
```
5. 保存退出。
6. 执行以下命令，编辑Soga的配置文件：
```
vim /etc/soga/soga.conf
```
7. 参照本Repo中的soga.conf，修改以下对应位置中的内容：
```
type=sspanel-uim
server_type=trojan # 可选v2ray或trojan，但只能选其一，不能同时工作
api=webapi
webapi_url=https://sspanel.example.com/ # 修改为你的管理面板URL
webapi_mukey=muKey # 修改为你的mukey
node_id=1 # 参照第五节第2点创建的节点ID填写
soga_key=
cert_file=/usr/local/nginx/conf/ssl/example.com/fullchain.cer # 将本行及以下的所有example.com修改为你的节点URL
key_file=/usr/local/nginx/conf/ssl/example.com/example.com.key # 注意不要删除末尾的“.key”
（略）
# 注：新版soga默认提供的配置文件模板内容与本教程不完全相同，找到对应行直接修改即可，其他多出来的内容不需要修改或填写。
```
8. 保存退出。
9. 至此，V2Ray与Trojan后端配置完毕。
10. 执行以下命令，启动或重新启动后端程序：
```
service v2ray restart
soga start
```
11. 等待约5秒后，执行以下命令，检查V2Ray后端是否正常工作：
```
journalctl -u v2ray
```
12. 按下Shift+G，跳到最后一行，用键盘方向键观察后端程序是否已获得前端用户信息（如邮箱、UUID、设备限制数等），若有，则证明对接成功。
13. 执行以下命令，检查Trojan后端是否正常工作：
```
soga status
```
14. 若屏幕中的Status是绿色的Active，且下方日志已获取到正确的用户数，则证明对接成功。
#### 七、选择适合你的加速加速内核及拥塞算法
1. 执行以下命令，下载多合一加速脚本：
```
wget -N --no-check-certificate "https://github.000060000.xyz/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```
2. 在执行成功后，你将会看到一系列内核及拥塞算法、队列算法等的选项，只需要输入对应数字、按照提示即可进行安装。受VPS所在地域、绕行路线、机器性能等因素的影响，我也无法给出一个完美的答案。以下方案仅供参考，实际还是需要你寻找到最适合你的组合。
3. 本人采用的方案如下：
```
内核：xanmod（目前内核版本号为Linux 5.10+）
拥塞算法：BBR
队列算法：fq_pie
（即xanmod内核与BBR+fq_pie方案）
ECN：关闭
```
4. 按照网络说法，xanmod本身因为Linux内核版本号较新，支持的新特性更多，同时xanmod内核团队针对其进行了大量的性能优化（具体可以自行Google查看Xanmod Kernel网页的说明）。且根据实测，相比起BBR2、BBRPlus与锐速（LotServer）相比，BBR在xanmod内核下有着无可比拟的优势。例如延迟相对更低、稳定性更好（不易断流）、突发及持续的速度都比较稳定等等。虽说锐速依旧是搭建飞机场不可或缺的考虑对象，但其“断流小王子”的称号也不是白来的。如果你开的是香港节点，顺便想用来做游戏加速器，基本上就不要考虑锐速了，玩10分钟就断流一次，根本无法使用。且锐速目前个人VPS大都在用破解版，程序版本较老、要求内核版本号太低（3.10.127-x86_64），早就跟不上主流需求。BBR虽然称不上完美，但起码在我的方案中给了我一个尽可能接近锐速，同时又更稳定的选择。
5. 使用全局代理及speedtest.net 等方式，反复测试多个内核与算法的搭配，直到寻找到最适合你的方案。
#### 八、配置IPv6
开启IPv6能给机场节点带来的好处目前暂时还不明确，但有一点可以确定的是，在IPv4资源枯竭的情况下，部分VPS提供商开始提供仅IPv6地址的服务器（如Vultr），或是一个v4+十几个v6（常见于小提供商）。这时候你就可以不需要拘泥于仅一个v4地址带来的限制，如果终端用户有条件使用v6上网，你甚至可以完全抛弃v4地址，转为v6的解析。这样一来，其被封IP的概率又会小很多。

注意：有些VPS服务商或是某些特定套餐的VPS（如阿里云轻量）并未提供IPv6。在开始操作前，请先去VPS的管理面板上查看，是否存在IPv6地址。如果存在，则证明可以进行后续操作，否则即便配置了也可能无法使用。并且，部分VPS开启IPv6的方式可能与标准化流程存在一定差异，若下述方式无法正常开启IPv6，建议查看VPS服务商提供的说明手册进行操作（一般来说，只有阿里云、亚马逊、樱花、Vultr等大型提供商会存在潜在的差异，并提供标准化的说明文档以供参考。而那些使用了通用面板管理的小型服务商，基本不存在特殊化流程，可以适用于本教程）。

注意2：一般来说，一旦开启了IPv6，后端程序（尤其是Soga）将默认通过IPv6与管理面板对接，因此管理面板所在服务器也必须进行IPv6化配置。但部分情况下，即便你已经完成了所有配置，也依旧可能会出现后端无法与前端对接等情况，还需要进一步学习和观察。此外，你还需要考虑到机场内的部分用户并未开启或暂无条件使用IPv6的可能性。~~目前后端程序是否会根据用户的网络环境自动切换v4和v6还并不清楚。~~（已确认，在用户无条件使用IPv6的情况下，客户端会自动切换为IPv4解析）如果你实在是不放心，还是建议跳过该步骤。

1. 再度运行第七点下载的tcp.sh（请自行cd回你所下载的目录）：
```
./tcp.sh
```
2. 找到“开启IPV6”选项，并输入对应的数字，回车执行。
3. 待提示成功后，执行以下命令，重启网络服务：
```
sysctl -p
systemctl restart network.service
```
4. 执行以下命令，观察是否有IPv6地址出现：
```
ifconfig eth0
注：eth0为VPS默认网卡的名称，部分VPS默认网卡名称可能不是eth0，那么可以先执行：
ifconfig
在第一行开头查看网卡名称，并将上述eth0替换为该名称。
在不使用锐速的情况下，网卡名称不是eth0基本不影响使用，若使用锐速，非eth0网卡将无法正常开启。
```
5. 如果IPv6地址正常出现，其信息应大致如下：
```
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet (服务器IPv4地址)  netmask 255.255.254.0  broadcast xxx.xxx.xxx.xxx
        inet6 (服务器IPv6地址)  prefixlen 64  scopeid 0x0<global>
```
6. 如果没有出现inet6相关内容，可以尝试手动修改sysctl.conf文件：
```
vim /etc/sysctl.conf
```
在文本编辑器中找到下述两行：
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```
确保末尾的两个“1”改为“0”，然后保存退出，再次重启网络服务，并使用ifconfig eth0检查。

8. 如果依旧没有出现inet6相关内容，可以尝试重启一次，如果还是不行，请参考VPS的说明手册进行操作，或向VPS服务商提交工单。
9. 参照第三点的方式，重新配置V2Ray、Trojan以及前端管理面板的网页脚本，将#listen [::]:80;以及下方的SSL对应端口前的#号去掉。如果面板搭建在其他服务器上，请前往对应服务器开启IPv6并修改网页脚本。例如：
```
server
    {
        listen 80;
        listen [::]:80;
（中略）
server
    {
        listen 1443 ssl http2;
        listen [::]:1443 ssl http2;
（略）
```
8. 重启LNMP。
9. 进入域名提供商管理面板，添加对应URL的AAAA解析，IP地址填写服务器的公网IPv6地址，TTL请根据实际情况自行设定，一般来说习惯设定为最小值。
10. 等待解析成功，应该就可以正常访问节点了，无需进行其他任何操作。

---
### 附录
#### 附录1：解决443端口被拦截的问题
有时候，我们会发现一种情况：前后端对接没有问题，后端所在服务器能正常获得前端的用户信息，后端程序也没有出现任何故障，前端程序、域名解析、SSL证书等都没有发现问题，但客户端就是无法连接节点，或是连接以后无法访问网页，重启服务器、重新申请SSL证书、重装程序甚至直接重装系统都没办法解决问题，那么这时候极有可能是因为443端口被污染了。
要确定这一情况，请先在客户端的设置里尝试打开“默认跳过证书验证（allowInsecure）”功能，看看是否恢复上网，如果能够恢复，则证明一定是443端口被拦截，如果还是不行，也可以尝试使用本节方法尝试恢复。

1. 打开nginx.conf。
```
vim /usr/local/nginx/conf/nginx.conf
```
2. 按下i键进入编辑，找到以下代码，位于我们刚才手动添加的代码的末尾：
```
    server {
        listen 443 reuseport;
        listen [::]:443 reuseport;
        proxy_pass  $backend_name;
        ssl_preread on;
```
3. 将里面的所有“443”改为你希望更换成的端口号，如2442：
```
    server {
        listen 2442 reuseport;
        listen [::]:2442 reuseport;
        proxy_pass  $backend_name;
        ssl_preread on;
```
4. 保存并退出文本编辑器，输入lnmp restart重启LNMP，确认没有任何报错信息。（如果你的VPS配置了防火墙，请自行开放端口。如果你其实并不想使用防火墙，请参见“附录3：关闭SELinux和防火墙”一节）
5. 进入管理面板网页，逐个配置节点地址，将其中的“443”改为刚才所修改的端口号。
6. 在客户端内重新订阅节点，或手动修改节点信息，问题就应该解决了。

注意：前端所在服务器不建议修改443端口，否则登陆该服务器中托管的网站将会十分麻烦。因为浏览器在访问HTTPS时始终会默认尝试443端口，如果修改了端口号，你就必须在网址后面手动添加端口号。这样的操作尤其对WordPress等门户网站的流量存在负面影响。因此，后端和前端程序建议分VPS存放，后端所在服务器不建议托管任何重要的网站，这样就算修改了端口号，也不至于带来严重后果。

#### 附录1.1：使用亚马逊CloudFront CDN解决443端口被封
本文开头已经提到，原先我是不希望使用CloudFlare（以下简称CF）作为CDN的。事实上我也尝试过一次，但由于CF的延迟实在是太不好看了，用了还不如不用，所以一直没有朝CDN这个方向研究。但最近，随着我越来越多的服务器443端口遭到封禁（IP地址仍然存活），我也不得不考虑要开始用CDN了。然而CF我实在是不想用，其他家的CDN大多数需要收取高昂流量费，实在是不好下手。

经过朋友提醒，发现亚马逊提供了CloudFront（以下简称CFT）CDN，其拥有不错的免费额度，1T流量一千万次请求，且配置灵活，不需要你去修改域名那边的DNS服务器，因此决定尝试。就目前的效果而言，解决问题很彻底，且潜在地提升了连接的稳定性和速度，大家感兴趣的可以尝试，一劳永逸地解决总是需要改端口号的问题。（经验上说，只要你的SSL端口被盯上过一次，那么今后只会无数次地被封）

#### UPDATE 2023/4/25
CFT的访问是否流畅取决于你所在的地区和运营商。亚马逊并未提供特定的地区线路可供访问，而是将亚洲与其他地区混合作为一个选项，因此我们并不能决定CFT将我们的请求用哪里的服务器转发。根据目前的观察，电信访问CFT的效果最差，100Mbps带宽的服务器通常会存在200-300ms的延迟，可用带宽仅10Mbps不到，有时候可以低至1Mbps；联通次之，主要表现为延迟偏高，但速率可以在30-50Mbps，部分地区可以满速，另外可能受时间段影响；移动效果最好，无论是否过CDN，几乎都能做到满速访问，仅偶尔发生卡顿现象。

如果配置了CFT，用户访问体验很差，但SSL端口又确实被封无法验证证书的，可以将节点URL和host改回服务器原本域名，并将“跳过证书验证（allowInsecure）”设置为true（在客户端的节点信息设置内）。

注意：本文不涉及亚马逊AWS账号注册的相关教程，默认你已经拥有一个AWS账号。
1. 在AWS控制台中搜索CloudFront，进入CFT控制面板。
2. 点击“创建分配”，参考我的方案进行如下配置：
```
源域：你需要过CDN的域名
协议：匹配查看器（翻译错误，应指Browser，浏览器）
端口号：默认80和443，根据你域名所在服务器的实际Nginx监听端口号填写
最低源SSL协议：TLSv1
自动压缩对象：No
缓存键和源请求：Legacy cache settings（其所属的选项保持不动）
IPv6：默认Yes，根据服务器情况自行决定，当然可以不管，不支持IPv6的服务器选Yes也不会影响访问
除上述以外的其他选项均保持默认不变
```
3. 点击“创建分配”。
4. 在返回的页面右侧，观察“上次修改时间”，当其中的“部署”变为一串日期时间时，则证明部署成功。
5. 验证CDN是否配置成功，请在浏览器中分别访问两个地址：
```
原节点URL/你设定的path
例：v2ray.example.com/welcome/

CFT分配的域名/你设定的path
例：1234abcd.cloudfront.net/welcome/
```
若两次均出现相同内容，如“404 Not Found”或者“Bad Request”（仅浏览器左上角出现，不能是Nginx提示的403 Bad Request），则证明CDN转发正确，可以进行后续操作。

6. 复制该页面左侧的分配域名，来到SSPanel，修改你要设定CDN的节点，将节点地址改为如下格式：
```
CDN域名;443;AlterID;tls;ws;path=/welcome/|host=CDN域名
例：1234abcd.cloudfront.net;443;2;tls;ws;path=/welcome/|host=1234abcd.cloudfront.net

Trojan节点仅需替换节点URL为CDN域名即可，其他默认不变。如果曾修改过SSL端口号，请改回443

在配置CDN前如果你修改过SSL端口号，强烈建议你改回443，或在创建CFT分配时注意填写正确的SSL端口号。
path遵从前文内容，需要跟你设置的完全一样。
```
7. 保存修改，同步订阅到客户端中，检查是否正确联网即可。

备注：在研究CFT时，也顺便看到了网上有涉及到“优选IP”相关的操作，但在本文中不会涉及到这一内容，因为我没兴趣研究。需要使用优选IP的，将IP地址替换掉节点地址开头的CDN域名即可，host=后的CDN域名保持不变。

备注2：本操作仅涉及节点本身的CDN。建议V2Ray、Trojan分开创建分配，不同域名的节点也分开创建分配（不会额外收费，CFT收费是打包计算的，创建10个分配加起来都没超过免费额度那就不会收费），否则要不同客户端成功连接对应协议会很困难。SSPanel和在服务器上的其他网站如果也需要使用CDN，则建议单独创建分配后参照网上常规教程进行配置（需要设置域名的CNAME记录），尤其是WordPress，需要涉及到非常多内容的修改，否则将完全无法访问，这里不再赘述。

#### 附录2：CentOS获取Root权限
本文档内的所有操作均默认基于root账户进行，因此不需要输入sudo。对于安全性要求不算高的服务器，也确实可以这么做，省下各种不必要的麻烦。
绝大多数小VPS提供商，和部分大型提供商，均提供了Root账号登陆的功能，但像亚马逊、Oracle、谷歌等提供商默认仅允许你使用SSH Key进行登录。实际上这些服务器并没有完全禁用Root账号，要打开也并不是什么难事。

1. 打开sshd_config。
```
vim /etc/ssh/sshd_config
```
2. 找到如下代码（并不位于同一位置，请自行翻找，一般来说在该文件较靠前的位置都能找到）：
```
PermitRootLogin no
PasswordAuthentication no
```
3. 将后面的no改为yes，有时候这两行代码前会存在#号，也需要一并删除。
4. 如有需求，可以顺带修改检测客户端在线的时间，以避免低性能服务器在安装LNMP时过长时间没有任何操作，自动断开SSH导致需要重新安装的问题。
```
ClientAliveInterval 900
ClientAliveCountMax 999
注：第一行为两次检测的时间间隔，第二行为“检测多少次没有操作后自动断开SSH”，单位为秒。
```
修改SSH的22端口这里不做详细解释，网上已经有很多教程。个人建议一并修改，以解决22端口遭到攻击的问题（即登陆VPS时出现类似“There're xxxx times of login attempts”的提示，这就是遭到穷举法攻击了）。

5. 给Root账户设置密码。
```
sudo passwd root
输入你想设定的Root密码，回车（屏幕没有提示）
再次输入你想设定的Root密码，回车（屏幕没有提示，输入无误回车后自动返回）
```
6. 此时输入su，并输入刚才设定的密码，你就应该位于Root账户下了。
7. 重启VPS后，即可正常使用Root账号和密码登陆。

#### 附录3：关闭SELinux和防火墙
对于安全性要求不高的服务器，你可以选择关闭SELinux和防火墙，这样可以避开每次设定一个端口都需要手动开放的操作。
但注意，这项操作仅适合在安全性要求不高的服务器里使用，否则造成任何不良后果请自行承担！

1. 打开selinux配置文件。
```
vim /etc/sysconfig/selinux
```
2. 找到其中的SELINUX=enforcing，将“enforcing”修改为“disabled”。
3. 修改SELinux后需要重启VPS生效，但你可以先做完下列步骤，再一并重启。
4. 如果你是CentOS 7或更高版本的系统，执行下列代码关闭防火墙：
```
systemctl stop firewalld
systemctl disable firewalld
systemctl stop iptables
systemctl disable iptables
```
4. 如果你是CentOS 6或更老版本，执行下列代码：
```
service iptables stop
chkconfig iptables off
```
5. 对于大多数VPS，此时你已经成功关闭SELinux和防火墙。但对于部分大型提供商（如樱花、Oracle、谷歌、亚马逊等），它们的防火墙设定实际上存在于VPS的管理面板中。请根据实际情况，搜寻诸如“网络安全组”、“端口过滤”之类的页面，在其中手动关闭防火墙，或允许所有端口、所有协议、所有IP通过。
6. 如果你要修改SSH默认的22端口，请务必执行本操作，或是在防火墙中添加新的白名单端口号，然后再重启VPS，否则你会再也无法通过SSH连接上VPS服务器。

#### 附录4：新SSPanel-Uim安装注意事项
近段时间因为原先使用的SSPanel-Uim出现了数据库问题，卡登录界面怎样都过不去，同时服务器端MySQL关闭后就再也无法开启，所以彻底重装了一遍MySQL5.7和前端管理面板。但发现了如下问题：
1. 现在SSPanel-Uim出现了Dev和New-Feat两个分支，不太清楚它们的区别。
2. 使用了New-Feat分支，并按照Wiki进行数据库迁移步骤至“remarks”时出现报错。
3. 即便不完成数据库迁移，也可以通过一些暴力手段强行将老面板数据库迁移至新面板（需要改一些字段之类的，但很容易错漏），但会出现大量HTTP 500和SQLite报错。

首先，第一点很简单。Dev分支即以往的旧主题，而New-Feat分支使用了新的主页，看起来更简洁，信息密度更大，排版布局更合理。这个大家自己进行选择就好。
接下来是第二点。经过查证，推测可能是MySQL版本的问题。官方Wiki指出安装环境推荐使用MariaDB 10.3.32+，虽然根据网上信息，MariaDB 10.3相当于MySQL 5.6和5.7的有限替代，但具体区别是什么我没有查证。且PHP这边报错的内容可能指向了类似于“开发环境支持而部署环境不支持”之类的问题，参见下列描述：

“
I'm going to guess that your local XAMPP development server is running MySQL 8.0.13 or newer — or MariaDB 10.2.1 or newer. Prior to that version, MYSQL did not allow a DEFAULT value other than NULL for JSON columns. In MariaDB, JSON is an alias for LONGTEXT, which likewise (starting with version 10.2.1) allows DEFAULT values.

Probably your development environment allows the defaults and the production environment doesn't. You can either upgrade your production system or not use that feature.
”

所以考虑将原先的MySQL 5.7替换为MariaDB。至于版本号，不要低于Wiki要求的即可，这里我选择了LNMP一键安装脚本里的10.4.19。
由于VPS的内存仅为1G，甚至过不去脚本的内存检测（即低于1024MB内存不允许安装MySQL 8或MariaDB 10），所以进入lnmp安装目录下的include文件夹，编辑main.sh，找到如下代码，并在开头加入井号注释掉，并wq保存退出，即可正常进行安装步骤。但为了后续操作，强烈建议添加SWAP！
```
if [[ "${DBSelect}" =~ ^[345789]$ ]] && [ `free -m | grep Mem | awk '{print  $2}'` -le 1024 ]; then

    echo "Memory less than 1GB, can't install MySQL 5.6+ or MairaDB 10+!"

    exit 1

fi
```

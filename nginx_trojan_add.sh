stream {
    # map domain to different name
    map $ssl_preread_server_name $backend_name {
 #       web.cn.chengxiaobai web;
        .rimi.moe vmess;
        .rimi.moe trojan;
    # default value for not matching any of above
        default trojan;
    }

 #   upstream web {
#        server 127.0.0.1:10240;
 #   }

    upstream trojan {
        server 127.0.0.1:1443;
    }

    upstream vmess {
        server 127.0.0.1:1444;
    }

    server {
        listen 443 reuseport;
        listen [::]:443 reuseport;
        proxy_pass  $backend_name;
        ssl_preread on;
    }
}
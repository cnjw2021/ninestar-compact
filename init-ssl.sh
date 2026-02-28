#!/bin/bash

# --- 設定値 (ユーザー環境に合わせて修正) ---
domains=(lucia9star.com www.lucia9star.com)
email="aussie9804@yahoo.co.jp" # Let's Encrypt アカウント用のメールアドレス
# --- 設定値 終了 ---

# スクリプト実行中にエラーが発生した場合は、即座に終了します。
set -e

echo "### 必要なディレクトリを作成しています... ###"
mkdir -p ./certbot/conf ./certbot/www

echo "### 一時的な Nginx 設定ファイルを作成しています... ###"
# SSL 設定がない一時的な Nginxのための設定ファイルを作成
cat > ./certbot/conf/default.conf <<EOF
events {
    worker_connections 1024;
}
http {
    server {
        listen 80;
        server_name ${domains[0]} ${domains[1]};

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 200 'Temp server for SSL cert generation. Please wait...';
        }
    }
}
EOF

echo "### 一時的な Nginx コンテナをバックグラウンドで実行しています... ###"
# docker-compose.ymlを使用しながら、一時的な設定ファイルをマウントして nginx 実行
# 💡 [最終修正] -v オプションを追加して、一時的な設定ファイルが含まれるディレクトリをコンテナにマウントします。
# 💡 [修正] -d (detached) オプションでバックグラウンド実行, --name で識別可能な名前を指定
# 💡 [最終修正] --service-ports オプションを追加して、80番ポートを外部に公開します。
docker compose run --rm -d --name nginx-temp --service-ports \
  -v "$(pwd)/certbot/conf:/etc/nginx/conf.d" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  --entrypoint "\
  nginx -g 'daemon off;' -c /etc/nginx/conf.d/default.conf" nginx

echo "### SSL 証明書の発行をリクエストしています... ###"
# certbot コンテナを実行して証明書を発行
# --webroot 方式と一時的な Nginxが共有するボリュームを使用
docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
    --email $email \
    --agree-tos \
    --no-eff-email \
    -d ${domains[0]} -d ${domains[1]}

echo "### 一時的な Nginx コンテナを停止しています... ###"
# 💡 [追加] 名前で指定して一時的なコンテナを確実に停止
docker stop nginx-temp

echo "### 一時的な Nginx 設定ファイルを削除しています... ###"
rm ./certbot/conf/default.conf

echo "### SSL セキュリティオプションファイルを作成しています... ###"
mkdir -p ./certbot/conf
cat > ./certbot/conf/options-ssl-nginx.conf <<EOF
ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOF

# 💡 [追加] Diffie-Hellman パラメータファイルを作成します。 (セキュリティ強化)
echo "### Diffie-Hellman パラメータファイルを作成しています... ###"
if [ ! -f "./certbot/conf/ssl-dhparams.pem" ]; then
  openssl dhparam -out ./certbot/conf/ssl-dhparams.pem 2048
fi

# 💡 [自動化追加] Crontab 自動更新登録
echo "### Crontabに自動更新タスクを登録しています... ###"
# プロジェクトの絶対パスを取得
PROJECT_PATH=$(pwd)
# 登録する cron コマンドを定義
CRON_COMMAND="/usr/bin/docker compose -f $PROJECT_PATH/docker-compose.yml run --rm certbot renew && /usr/bin/docker compose -f $PROJECT_PATH/docker-compose.yml exec nginx nginx -s reload"
# cron タスクの内容を定義 (毎日 2:30)
CRON_JOB="30 2 * * * $CRON_COMMAND"

# 現在の crontab に同じコマンドがあるかどうかを確認
(crontab -l 2>/dev/null | grep -Fq "$CRON_COMMAND") || \
( (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - && \
echo "成功: Crontabに自動更新タスクが追加されました。" )
# 💡 [ここまで追加] ###

echo "### 自動化スクリプトが完了しました! ###"
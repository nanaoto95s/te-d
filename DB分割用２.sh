#!/bin/bash
# RHEL6用
# NFSの設定から
# centOS6の場合
# あらかじめslaveサーバーでcrontabの設定をする
 # crontab -e
 # 0 0 * * * /usr/local/cybozu/cbgrn/grn.cgi -C -q /usr/local/cybozu/cbgrn/code/sched/dynamic/cleanup.csp

set -u

PW="cybozu"
masterIP="10.224.156.105"
slaveIP="10.224.156.106"

# webサーバのドキュメントルート
web_dir=/var/www/html
# インストール識別子
app_name=cbgrn
# データベース管理ユーザーのパスワード
db_root_password=garoon
# データベースに対して、書き込み/読み込みを行うユーザーのパスワード
db_password=garoon

# masterサーバーでNFSを設定する
commandA="echo testtest >> /etc/exports"
commandB="sed -i -e 's@testtest@\/usr\/local\/cybozu\/files ${slaveIP}(rw)@g' /etc/exports"

# slaveサーバーの添付ファイル保存領域のアクセス権を変更する
commandC="chmod -R 000 /usr/local/cybozu/files/*"

# NFSサーバをインストールして起動する
commandD="yum -y install nfs-utils"
commandE="service rpcbind start"
commandF="service nfs start"

# slaveサーバーでfilesをマウントする
commandG="mount -o intr ${masterIP}:/usr/local/cybozu/files /usr/local/cybozu/files"

# masterサーバーでGaroonを初期化する
commandH="/etc/init.d/cyss_cbgrn stop"
commandI="/usr/local/cybozu/cbgrn/grn.cgi -C -q /usr/local/cybozu/cbgrn/code/command/grn_initialize.csp db_admin_password='${db_root_password}' db_user_password='${db_password}' garoon_admin_password='${PW}' default_timezone='Asia/Tokyo' default_locale='ja'"
commandJ="/etc/init.d/cyss_cbgrn start"

# 全サーバーでMySQLの設定を変更する
commandK="/etc/init.d/cyss_cbgrn stop"
commandL="/etc/init.d/cyde_5_0 stop"
MEM8GB_innoDB_buffer_pool_size=4600M
MEM8GB_max_connections=50
commandM="sed -i -e 's@max_connections                 = *@max_connections                 = ${MEM8GB_max_connections}@g' /usr/local/cybozu/mysql-5.0/etc/my.ini"

clear

expect -c "
set timeout 5
spawn env LANG=C /usr/bin/ssh root@${masterIP}
expect \"password:\"
send \"${PW}\n\"
expect \"$\"

send \"echo masterサーバーでNFSを設定する\r\"



spawn env LANG=C /usr/bin/ssh root@${slaveIP}
expect \"password:\"
send \"${PW}\n\"
expect \"$\"
send \"echo slaveサーバーの添付ファイル保存領域のアクセス権を変更する\r\"
send \"${commandC}\r\"

send \"echo nfsサーバーをインストールし起動する\r\"

send \"${commandE}\r\"
send \"${commandF}\r\"

send \"${commandG}\r\"

spawn env LANG=C /usr/bin/ssh root@${masterIP}
expect \"password:\"
send \"${PW}\n\"
expect \"$\"
send \"echo nfsサーバーをインストールし起動する\r\"

send \"${commandE}\r\"
send \"${commandF}\r\"
send \"echo Garoonを初期化する\r\"
send \"${commandH}\r\"
send \"${commandI}\r\"
expect \"$\"
send \"y\r\"
send \"${commandJ}\r\"


set timeout 60
interact
"








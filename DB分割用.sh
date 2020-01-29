#!/bin/bash
# RHEL6用
# 先にmasterサーバーの/root/cybozuにinstaller-5.0.0-linux.tar.gzを配置してください
# 全サーバーのhostsファイルを編集して、名前解決をしてください
#mod_phpの設定までのシェル
#シェルを回した後、Doubleをダブルコーテーションに変えてapacheの再起動が必要（全DB）

set -u

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

# slaveサーバにインストールするアプリケーション
# 通知を分ける際は、他のアプリケーションと挙動が違うので、sedコマンドの記述を変える必要がある
slave1=schedule
slave2=message
slave3_note=notification_host1-
slave3_noteA=notification_host1-1000
slave3_noteB=notification_host1001-2000
slave3_noteC=notification_host2001-

# mod_phpの設定
PHPIniDir=/user/local/cybozu/cbgrn/mod_php.ini
Alias=/user/local/cybozu/cbgrn/code/doc_root

# 各サーバーのhostsファイルを編集する
command0="sed -i '1s@^@${slaveIP} slave_server host2\n@' /etc/hosts"
command01="sudo sed -i '1s@^@${masterIP} master_server host1\n@' /etc/hosts"

# 全DBサーバで必要なライブラリをインストールする
command1="yum -y install bash.x86_64 cyrus-sasl-lib.x86_64 freetype.x86_64 glibc.x86_64 keyutils-libs.x86_64 krb5-libs.x86_64 libaio.x86_64 libcom_err.x86_64 libcurl.x86_64 libgcc.x86_64 libicu.x86_64 libidn.x86_64 libjpeg-turbo.x86_64 libpng.x86_64 libselinux.x86_64 libssh2.x86_64 libstdc++.x86_64 libxml2.x86_64 ncurses-libs.x86_64 nspr.x86_64 nss.x86_64 nss-softokn-freebl.x86_64 nss-util.x86_64 numactl.x86_64 openldap.x86_64 openssl.x86_64 perl.x86_64 zlib.x86_64"

# 全DBサーバでmod_php/mod_auth_mysqlモジュールを無効にする
command2="cd /etc/httpd/conf.d/"
#set +e  # set -e を無効にする
#mv php/conf php.conf_bak
#mv auth_mysql.conf auth_mysql.conf_bak

# SELinuxを無効にする
command3="sed -i -e 's/SELINUX=Enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux"
#set -e # ここまで。

# 全DBサーバーでtransparent hugepages(THP)機能を無効にする
command4="echo never > /sys/kernel/mm/transparent_hugepage/enabled"
# 再起動後もTHP機能が無効になるように設定する
#sed -i -e '$a echo never > /sys/kernel/mm/transparent_hugepage/enabled' /etc/rc.d/rc.local

# masterサーバーでinstallerを配置したディレクトリを、slaveサーバーにも作る
command5_1="mkdir cybozu"
command5_2="cd cybozu/"
command5_3="mkdir installer"
command5_4="cd ../"

# マスターDBでインストール設定ファイルを編集する
command6="cd cybozu/"
command7="tar zxvf installer-5.0.0-linux.tar.gz"
command8="cd installer/"
# hostsセクション
command9="sed -i -e 's/host1 = webdb01.cybozu.co.jp:localhost/host1 = master_server:'${masterIP}'/g' setting.ini"
command10="sed -i -e '3i host2 = slave_server:'${slaveIP}'' setting.ini"
# commonセクション
command11="sed -i -e 's@web_dir = /usr/local/apache2/htdocs@web_dir = '${web_dir}'@g' setting.ini"
command12="sed -i -e 's/app_name = cbgrn/app_name = '${app_name}'/g' setting.ini"
command13="sed -i -e 's/db_root_password = cybozu/db_root_password = '${db_root_password}'/g' setting.ini"
command14="sed -i -e 's/db_password = cybozu/db_password = '${db_password}'/g' setting.ini"
# garoonセクション
command15="sed -i -e 's/;mysql_${slave1}_host = host1/mysql_${slave1}_host = host2/g' setting.ini"
command16="sed -i -e 's/;mysql_${slave2}_host = host1/mysql_${slave2}_host = host2/g' setting.ini"
command17="sed -i -e 's/;mysql_${slave3_note} = host1/mysql_${slave3_noteA} = host1/g' setting.ini"
command18="sed -i -e '/;mysql_profile_host1- = host1/i mysql_${slave3_noteB} = host2' setting.ini"
command19="sed -i -e '/;mysql_profile_host1- = host1/i mysql_${slave3_noteC} = host1' setting.ini"

# masterサーバーからslaveサーバーにsetting.iniをコピーする
command20="cd /root/cybozu/installer"
command20_1="cd /root/cybozu/"
command20_2="mkdir test"
command21="scp setting.ini root@'${slaveIP}':/root/cybozu/installer"

# MySQLをインストール
command22="./install.sh mysql64 setting.ini"

# mysqldセクションのlog-binを編集
command23="sed -i -e 's@#log-bin@binlog-format = row@g' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command24="sed -i -e '/^binlog-format = row$/a log-bin = \/usr\/local\/cybozu\/mysql-5.0\/data\/binlog' /usr/local/cybozu/mysql-5.0/etc/my.ini"

# データベースエンジンを再起動
command25="/etc/init.d/cyde_5_0 restart"

# slaveサーバーのmy.iniを編集
command26="sed -i -e '/^server-id/s/= 1/= 2/g' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command27="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_user_name_language' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command28="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_itemuserrelation' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command29="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_useritem' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command30="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_group_local' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command31="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_language_status' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command32="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_file' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command33="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_userinfo' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command34="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_mimetype' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command35="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_userrolerelation' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command36="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_usergrouprelation' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command37="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_sso_sso' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command38="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_access_abstractdata' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command39="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_role' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command40="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_grn_mygroup' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command41="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_group' /usr/local/cybozu/mysql-5.0/etc/my.ini"
command42="sed -i -e '/^log_timestamps                  = SYSTEM$/a replicate-do-table = cb_cbgrn.tab_cb_user' /usr/local/cybozu/mysql-5.0/etc/my.ini"

# mysqlに接続する
command43="cd /usr/local/cybozu/mysql-5.0/bin"
command44="./mysql --defaults-file=/usr/local/cybozu/mysql-5.0/etc/my.ini -u cbroot -p${db_root_password}"
command45="CHANGE MASTER TO MASTER_HOST='${masterIP}',MASTER_PORT=3770,MASTER_USER='cbroot',MASTER_PASSWORD='${db_root_password}';"
command46="exit;"

# Garoonプログラムをインストール
command47="./install.sh garoon64 setting.ini"

# httpd.confにmod_phpの設定を追記
command48="sed -i -e '$ a LoadModulennn' /etc/httpd/conf/httpd.conf"
command49="sed -i -e 's@LoadModulennn@LoadModule php7_module \/usr\/local\/cybozu\/cbgrn\/libphp7_httpd22.so@g' /etc/httpd/conf/httpd.conf"
command50="sed -i -e '$ a PHPIniDirnnn' /etc/httpd/conf/httpd.conf"
command51="sed -i -e 's@PHPIniDirnnn@PHPIniDir Double${PHPIniDir}Double@g' /etc/httpd/conf/httpd.conf"
command52="sed -i -e '$ a AddTypennn' /etc/httpd/conf/httpd.conf"
command53="sed -i -e 's@AddTypennn@AddType application\/x-httpd-php .php .csp@g' /etc/httpd/conf/httpd.conf"
command54="sed -i -e '$ a Aliasnnn' /etc/httpd/conf/httpd.conf"
command55="sed -i -e 's@Aliasnnn@Alias \/grn\/ Double${Alias}\/Double@g' /etc/httpd/conf/httpd.conf"
command56="sed -i -e '$ a <Directorynnn' /etc/httpd/conf/httpd.conf"
command57="sed -i -e 's@<Directorynnn@<Directory Double${Alias}Double>@g' /etc/httpd/conf/httpd.conf"
command58="sed -i -e '$ a AllowOverridennn' /etc/httpd/conf/httpd.conf"
command59="sed -i -e 's@AllowOverridennn@AllowOverride None@g' /etc/httpd/conf/httpd.conf"
command60="sed -i -e '$ a Ordernnn' /etc/httpd/conf/httpd.conf"
command61="sed -i -e 's@Ordernnn@Order allow,deny@g' /etc/httpd/conf/httpd.conf"
command62="sed -i -e '$ a Allowf' /etc/httpd/conf/httpd.conf"
command63="sed -i -e 's@Allowf@Allow from all@g' /etc/httpd/conf/httpd.conf"
command64="sed -i -e '$ a </Directory>' /etc/httpd/conf/httpd.conf"
command65="sed -i -e 's@Double@\\"@g' /etc/httpd/conf/httpd.conf"

PW="cybozu"

expect -c "
set timeout 5
spawn env LANG=C /usr/bin/ssh root@${masterIP}
expect \"password:\"
send \"${PW}\n\"
expect \"$\"
send \"echo 必要なライブラリをインストールする\r\"

send \"echo mod_auth_mysqlモジュールを無効にする\r\"
send \"${command2}\r\"
send \"echo SELinuxを無効にする\r\"
send \"${command3}\r\"
send \"echo transparent_hugepage機能を無効にする\r\"
send \"${command4}\r\"

send \"echo slaveサーバーに移動\r\"
send \"ssh root@${slaveIP}\r\"
expect \"password:\"
send \"${PW}\n\"
expect \"$\"
send \"echo masterサーバーでinstallerを配置したディレクトリを、slaveサーバーにも作る\r\"




send \"echo 必要なライブラリをインストールする\r\"

send \"echo mod_auth_mysqlモジュールを無効にする\r\"

send \"echo SELinuxを無効にする\r\"

send \"echo transparent_hugepage機能を無効にする\r\"


send \"echo masterサーバーに移動\r\"




send \"echo setting.iniを編集\r\"















send \"echo masterサーバーからslaveサーバーにsetting.iniをコピーする\r\"






send \"echo masterサーバーでMySQLをインストールする\r\"


send \"echo slaveサーバーに移動\r\"






send \"echo slaveサーバーでMySQLをインストールする\r\"


send \"echo masterサーバーに移動\r\"







send \"echo masterサーバーでMySQLレプリケーションを設定する\r\"
send \"echo masterサーバーでmy.iniを編集\r\"


send \"echo my.iniの変更を有効にするため、masterサーバーのDBエンジンを再起動\r\"


send \"echo slaveサーバーに移動\r\"

send \"echo server-idに、他のDBサーバーと重複しない値を設定する\r\"

send \"echo mysqldセクションに追記\r\"













send \"echo my.iniの変更を有効にするため、slaveサーバーのDBエンジンを再起動\r\"

send \"echo mysqlに接続\r\"





send \"echo Garoonプログラムをインストール\r\"


send \"echo masterサーバーに移動\r\"



send \"echo httpd.confにmod_phpの設定を追記する\r\"



send \"echo slaveサーバーに移動\r\"





send \"echo httpd.confにmod_phpの設定を追記する\r\"

send \"echo ここでDoubleをダブルコーテーションに変える\r\"
send \"${command65}\r\"



interact
exit 0
"


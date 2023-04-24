#!/bin/bash
# Author: Slotheve<https://slotheve.com>

RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[36m"
PLAIN='\033[0m'

IP=`curl -sL -4 ip.sb`
CPU=`uname -m`
snell_conf="/etc/snell/snell-server.conf"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

archAffix(){
    if   [[ "$CPU" = "x86_64" ]] || [[ "$CPU" = "amd64" ]]; then
		CPU="amd64"
	elif [[ "$CPU" = "armv8" ]] || [[ "$CPU" = "aarch64" ]]; then
		CPU="arm64"
	else
		colorEcho $RED " 不支持的CPU架构！"
	fi
}

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	#bit=`uname -m`
}

Install_dependency(){
if [[ ${release} == "centos" ]]; then
			yum install unzip wget -y
		else
			apt-get install unzip wget -y
fi
}

Download_snell(){
	rm -rf 
	mkdir -p /etc/snell /tmp/snell
	archAffix
	DOWNLOAD_LINK="https://raw.githubusercontent.com/Slotheve/Snell-v3/main/snell-server-linux-${CPU}.zip"
	colorEcho $BLUE " 下载Snell: ${DOWNLOAD_LINK}"
	curl -L -H "Cache-Control: no-cache" -o /tmp/snell/snell.zip ${DOWNLOAD_LINK}
	unzip /tmp/snell/snell.zip -d /tmp/snell/
	mv /tmp/snell/snell-server /etc/snell/snell
	chmod +x /etc/snell/snell
}

Generate_conf(){
	Set_port
	Set_psk
}


Deploy_snell(){
	cd /etc/systemd/system
	cat > snell.service<<-EOF
	[Unit]
	Description=Snell Server
	After=network.target
	[Service]
	ExecStart=/etc/snell/snell -c /etc/snell/snell-server.conf
	Restart=on-failure
	RestartSec=1s
	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl daemon-reload
	systemctl start snell
	systemctl restart snell
	systemctl enable snell.service
	echo "snell已安装完毕并运行"
}

Set_port(){
	while true
		do
		echo -e "请输入 Snell 端口 [1-65535]"
		read -e -p "(默认: 6666，回车):" PORT
		[[ -z "${PORT}" ]] && PORT="6666"
		echo $((${PORT}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${PORT} -ge 1 ]] && [[ ${PORT} -le 65535 ]]; then
				echo && echo "========================"
				echo -e "       ${BLUE}已设置端口${PLAIN}"
				echo "========================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}

Set_psk(){
	while true
		do
		echo "请输入 Snell psk（建议随机生成）"
		read -e -p "(避免出错，强烈推荐随机生成，直接回车):" PSK
		if [[ -z "${PSK}" ]]; then
			PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 31)
		else
			[[ ${#PSK} != 31 ]] && echo -e "请输入正确的密匙（31位字符）。" && continue
		fi
		echo && echo "========================"
		echo -e "       ${BLUE}已设置密钥${PLAIN}"
		echo "========================" && echo
		break
	done
}

Write_config(){
	cat > ${snell_conf}<<-EOF
[snell-server]
listen = 0.0.0.0:${PORT}
psk = ${PSK}
EOF
}

Install_snell(){
	Generate_conf
	Download_snell
	Write_config
	Deploy_snell
	ShowInfo
}

Start_snell(){
	systemctl start snell
	colorEcho $BLUE "snell已启动"
}

Stop_snell(){
	systemctl stop snell
	colorEcho $BLUE "snell已停止"
}

Restart_snell(){
	systemctl restart snell
	colorEcho $BLUE "snell已重启"
}

Uninstall_snell(){
	systemctl stop snell
	systemctl disable snell
	rm -rf /etc/systemd/snell.service
	systemctl daemon-reload
	rm -rf /etc/snell
	echo "snell已经卸载完毕"
}

ShowInfo() {
	echo ""
	echo -e " ${BLUE}Snell配置文件: ${PLAIN} ${RED}${snell_conf}${PLAIN}"
	colorEcho $BLUE " Snell配置信息："
	GetConfig
	outputSnell
}

GetConfig() {
	port=`grep 0.0.0.0: $snell_conf | cut -d: -f2 | tr -d \",' '`
	psk=`grep psk ${snell_conf} | awk -F '= ' '{print $2}'`
}

outputSnell() {
	echo -e "   ${BLUE}协议: ${PLAIN} ${RED}snell${PLAIN}"
	echo -e "   ${BLUE}IP(address): ${PLAIN} ${RED}${IP}${PLAIN}"
	echo -e "   ${BLUE}端口(port)：${PLAIN} ${RED}${port}${PLAIN}"
	echo -e "   ${BLUE}密钥(PSK)：${PLAIN} ${RED}${psk}${PLAIN}"
	echo -e "   ${BLUE}版本(VER)：${PLAIN} ${RED}v1/v2/v3${PLAIN}"
}

Change_snell_info(){
	echo -e "修改 snell 配置信息"
	Set_port
	Set_psk
	Write_config
	Restart_snell
	colorEcho $RED "修改配置成功"
	ShowInfo
}

check_sys
menu() {
        Install_dependency
	clear
	echo "################################################"
	echo -e "#              ${RED}Snell一键安装脚本${PLAIN}               #"
	echo -e "#         ${GREEN}作者${PLAIN}: 怠惰(Slotheve)                 #"
	echo -e "#         ${GREEN}网址${PLAIN}: https://slotheve.com           #"
	echo -e "#         ${GREEN}论坛${PLAIN}: https://slotheve.com           #"
	echo -e "#         ${GREEN}TG群${PLAIN}: https://t.me/slotheve          #"
	echo "################################################"
	echo " -------------"
	echo -e "  ${GREEN}1.${PLAIN}  安装Snell"
	echo -e "  ${GREEN}2.${PLAIN}  ${RED}卸载Snell${PLAIN}"
	echo " -------------"
	echo -e "  ${GREEN}3.${PLAIN}  启动Snell"
	echo -e "  ${GREEN}4.${PLAIN}  重启Snell"
	echo -e "  ${GREEN}5.${PLAIN}  停止Snell"
	echo " -------------"
	echo -e "  ${GREEN}6.${PLAIN}  查看Snell配置"
	echo -e "  ${GREEN}7.${PLAIN}  修改Snell配置"
	echo " -------------"
	echo -e "  ${GREEN}0.${PLAIN}  退出"
	echo 

	read -p " 请选择操作[0-8]：" answer
	case $answer in
		0)
			exit 0
			;;
		1)
			Install_snell
			;;
		2)
			Uninstall_snell
			;;
		3)
			Start_snell
			;;
		4)
			Restart_snell
			;;
		5)
			Stop_snell
			;;
		6)
			ShowInfo
			;;
		7)
			Change_snell_info
			;;
		*)
			colorEcho $RED " 请选择正确的操作！"
			exit 1
			;;
	esac
}

action=$1
[[ -z $1 ]] && action=menu
case "$action" in
	menu|Uninstall_snell|Start_snell|Restart_snell|Stop_snell|ShowInfo|Change_snell_info)
		${action}
		;;
	*)
		echo " 参数错误"
		echo " 用法: `basename $0` [menu|Uninstall_snell|Start_snell|Restart_snell|Stop_snell|ShowInfo|Change_snell_info]"
		;;
esac
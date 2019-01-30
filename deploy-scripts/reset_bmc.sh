#!/usr/bin/expect
set timeout 180
set username [lindex $argv 0]
set host [lindex $argv 1]
set passwd [lindex $argv 2]

spawn ssh $username@$host

expect {
        "(yes/no)?" { send "yes\r" ; exp_continue }
        "password:" { send "${passwd}\r"}
}
sleep 10

expect "iBMC:/->"
send "ipmcset -d reset\r"
sleep 10
expect "\[Y/N\]:"
send "Y\r"

sleep 100

interact

#!/bin/bash 
#rvsh main program

#gobal var
tty=1;
username_s='';
machine_name_s='';
back_pid=0;

#log_out
function log_out
{
    echo 'Logout!';
    ./sqlite3 ./database.db "DELETE FROM login_user WHERE username='$username_s' AND machine='$machine_name_s' AND tty='$tty'";
    kill -9 $back_pid;
    c_user=`./sqlite3 ./database.db "SELECT COUNT(no) FROM login_user"`;
    if [ $c_user -eq 0 ]; then
    {
    	./sqlite3 ./database.db "UPDATE sqlite_sequence SET seq = 0 WHERE name='login_user'";
    	./sqlite3 ./database.db "UPDATE sqlite_sequence SET seq = 0 WHERE name='message'";
    	./sqlite3 ./database.db "DELETE FROM message";
    }
    fi;
    if [ "$1" == "" ]; then exit 0; fi;
}

#trap
trap 'echo "";log_out' 2 9; 

#v_shell
function v_shell
{
    username_s=$1;
    machine_name_s=$2;
    if [ "$username" == 'root' ]; then
    {
        en_var='rvsh >';
    }
    else
    {
        en_var="$username_s@$machine_name_s >";
    }
    fi;
    while [ 1 -eq 1 ];
    do
    {
        echo -n $en_var;
        read r_command;
        t_command_f=`echo $r_command | cut -d ' ' -f 1`;
        t_command_p=`echo $r_command | cut -d ' ' -f 2`;
        #echo $t_command_f;
        case $t_command_f in
            exit|quit)
                log_out;;
            who)
                #sql_result=`./sqlite3 ./database.db "SELECT * FROM login_user WHERE machine='$machine_name_s' OR machine=''"`;
                #echo $sql_result | awk -F '|' '{print $1}';;
       	 		./sqlite3 ./database.db "SELECT * FROM login_user WHERE machine='$machine_name_s' OR machine=''" | awk -F '|' 'BEGIN{OFS="\t";print "Username","TTY","Login Date";}{OFS="\t";print $4,"","pts/"$3,$6;}';;
            rusers)
                ./sqlite3 ./database.db "SELECT * FROM login_user" | awk -F '|' 'BEGIN{OFS="\t";print "Username","Machine Name","Login Date";}{OFS="\t";print $4,"",$5,"",$6;}';;
            rhost)
                ./sqlite3 ./database.db "SELECT * FROM machine" | awk -F '|' 'BEGIN{OFS="\t";print "Machine_name","Permitted_User";}{OFS="\t";print $2,"",$3;}';;
            connect)
                if [ "$t_command_p" == "$r_command" ]; then
                {
                    echo -ne '\033[32m';
                    echo -n 'Connect to:';
                    echo -ne '\033[0m';
                    read t_command_p;
                }
                fi;
                log_out -1;
                password_input $username_s $t_command_p;;
            su)
                if [ "$t_command_p" == "$r_command" ]; then
                {
                    log_out -1;
                    admin_login;
                }
                else
                {
                    log_out -1;
                    password_input $t_command_p $machine_name_s;
                }
                fi;;
            passwd)
                echo -ne '\033[32m';
                echo -n 'Old password:';
                echo -ne '\033[0m';
                read -s old_pas;
                echo '';
                old_pas_sha=`echo "$old_pas" | sha512sum | cut -d ' ' -f 1`;
                is_ok=`./sqlite3 ./database.db "SELECT no FROM user WHERE password='$old_pas_sha'"`;
                if [ "$is_ok" == "" ]; then
                {
                    echo -ne '\033[31m';
                    echo 'Wrong password!';
                    echo -e '\033[0m';
                }
                else
                {
                    echo -ne '\033[32m';
                    echo -n 'Please input new password:';
                    echo -ne '\033[0m';
                    read -s new_pas;
                    echo '';
                    new_pas_sha=`echo "$new_pas" | sha512sum | cut -d ' ' -f 1`;
                    ./sqlite3 ./database.db "UPDATE user SET password='$new_pas_sha' WHERE username='$username_s'";
                    echo 'Password has been changed!';
                }
                fi;;
            finger)
                ./sqlite3 database.db "SELECT user.username,login_user.tty,login_user.date,user.office,user.phone FROM user,login_user WHERE user.no=login_user.UID AND login_user.machine='$machine_name_s'" | awk -F '|' 'BEGIN{OFS="\t";print "Username","TTY","Login Date","","Office","","Office Phone";}{OFS="\t";print $1,"","pts/"$2,$3,$4,"",$5;}';;
            write)
            	to_user=`echo "$t_command_p" | cut -d "@" -f 1`;
                if [ "$to_user" == "root" ]; then 
                    to_machine="";
                else
                    to_machine=`echo "$t_command_p" | cut -d "@" -f 2`;
                fi;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM login_user WHERE username='$to_user' AND machine='$to_machine'"`" == ""  ]; then
				{
					echo -ne '\033[31m';
                	echo "ERROR:$to_user@$to_machine not logged in!";
                	echo -e '\033[0m';
                }
                else
                {
					message=`echo $r_command | sed "s/$t_command_f $t_command_p //"`;
					from_username=$username_s;
					from_machine=$machine_name_s;
					#tty=$tty;
					m_date=`date +%F_%H:%M:%S`;
					count=`./sqlite3 ./database.db "SELECT COUNT(no) FROM login_user WHERE username='$to_user' AND machine='$to_machine'"`;
					./sqlite3 ./database.db "INSERT INTO message (from_username,from_machine,tty,to_username,to_machine,date,message,count) VALUES ('$from_username','$from_machine',$tty,'$to_user','$to_machine','$m_date','$message',$count)";
                    if [ $? -eq 0 ]; then
                    {
					    echo -ne '\033[32m';
                        echo 'Message has been sent successfully.';
                        echo -e '\033[0m';
                    }
                    else
                    {
                        echo -ne '\033[31m';
                        echo 'ERROR:Database error!';
                        echo -ne '\033[0m';
                    }
                    fi;
                }
                fi;;
            host)
                if [ "$username" != "root" ]; then
                {
                    echo -ne '\033[31m';
                    echo 'You must be root to use this command!';
                    echo -ne '\033[0m';
                }
                else
                {
                    machine_manage;
                }
                fi;;                                   
            users)
                if [ "$username" != "root" ]; then
                {
                    echo -ne '\033[31m';
                    echo 'You must be root to use this command!';
                    echo -ne '\033[0m';
                }
                else
                {
                    user_manage;
                }
                fi;;                                 
            afinger)
                if [ "$username" != "root" ]; then
                {
                    echo -ne '\033[31m';
                    echo 'You must be root to use this command!';
                    echo -ne '\033[0m';
                }
                else
                {
                    user_information_manage;
                }
                fi;;                                   
            *)
                echo -ne '\033[31m';
                echo 'Error:We only have [who],[rusers],[rhost],[connect],[su],[passwd],[finger] and [write] for users,[host],[users] and [afinger] for admin.';
                echo -ne '\033[0m';
        esac;
            
      

    }
    done;
};

#machine_manage
function machine_manage
{
	is_break=-1;
	while [ $is_break -eq -1 ];
	do
	{
		echo '********Machine Manage********';
		echo '1.Add Machine';
		echo '2.Remove Machine';
		echo '3.Exit';
		read u_choose;
		case $u_choose in
			1)
				echo -n 'Please input machine name:';
				read m_name;
				./sqlite3 ./database.db "INSERT INTO machine (machine_name) VALUES ('$m_name')";
				echo -ne '\033[32m';
				echo 'Done.';
				echo -ne '\033[0m';;
			2)
				echo 'Please input the MID of the machine';
				./sqlite3 ./database.db "SELECT no,machine_name FROM machine" | awk -F '|' 'BEGIN{OFS="\t";print "MID","Machine_name";}{OFS="\t";print $1,$2;}';
				read d_mid;
				if [ "`./sqlite3 ./database.db "SELECT no FROM machine WHERE no='$d_mid'"`" == "" ]; then
				{
					echo -ne '\033[31m';
                	echo 'Wrong MID!';
                	echo -ne '\033[0m';
                }
                else
                {
                	./sqlite3 ./database.db "DELETE FROM machine WHERE no=$d_mid";
                	echo -ne '\033[32m';
                	echo 'Done.';
                	echo -ne '\033[0m';
                }
                fi;;
            3)
            	is_break=1;;
            *)
            	echo -ne '\033[31m';
                echo 'Please input 1,2 or 3!';
                echo -ne '\033[0m';;
        esac;
    }
    done;
};


#user_manage
function user_manage
{
	is_break=-1;
	while [ $is_break -eq -1 ];
	do
	{
		echo '********User Manage********';
		echo '1.Add User';
		echo '2.Remove User';
		echo '3.Add Authority';
		echo '4.Remove Authority';
		echo '5.Change Password';
		echo '6.Exit';
		read u_choose;
		case $u_choose in
			1)
				echo -n 'User name:';
				read u_name;
				echo -n 'Password:';
				read -s u_pass;
				u_pass_sha=`echo "$u_pass" | sha512sum | cut -d ' ' -f 1`;
				if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
				{
                	./sqlite3 ./database.db "INSERT INTO user (username,password) VALUES ('$u_name','$u_pass_sha')";
                	echo -ne '\033[32m';
                	echo 'Done.';
                	echo -ne '\033[0m';
                }
                else
                {
                	echo -e '\033[31m';
                	echo "ERROR:$u_name already exists!";
                	echo -e '\033[0m';
                }
                fi;;
            2)
            	echo -n 'User name:';
				read u_name;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
            	{
            		echo -ne '\033[31m';
                	echo "ERROR:$u_name not exists!";
                	echo -e '\033[0m';
            	}
            	else
            	{
            		./sqlite3 ./database.db "DELETE FROM machine WHERE username='$u_name'";
            		echo -ne '\033[32m';
                	echo 'Done.';
                	echo -ne '\033[0m';
                }
                fi;;
            3)
            	echo -n 'User name:';
            	read u_name;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
				{
					echo -ne '\033[31m';
                	echo "ERROR:$u_name not exists!";
                	echo -e '\033[0m';
                }
                else
                {
            		./sqlite3 ./database.db "SELECT no,machine_name FROM machine" | awk -F '|' 'BEGIN{OFS="\t";print "MID","Machine_name";}{OFS="\t";print $1,$2;}';
            		echo -n 'Please input MID,use sapce to divide,exp:1 2 3 4:';
            		read u_mid;
            		for i in $u_mid
            		do
            		{
            			if [ "`./sqlite3 ./database.db "SELECT no FROM machine WHERE no=$i"`" == ""  ]; then
            			{
            				echo -ne '\033[31m';
                			echo "ERROR:MID $mid not exists!";
                			echo -e '\033[0m';
                		}
                		else
                		{
            				old_users=`./sqlite3 ./database.db "SELECT user FROM machine WHERE no=$i"`;
            				if [ "`echo "$old_users" | grep -w $u_name`" != "" ]; then
            				{
            					echo -ne '\033[31m';
                				echo "ERROR:$u_name already exsits in $i!";
                				echo -e '\033[0m';
                			}
                			else
                			{
            					if [ "$old_users" == "" ]; then
            					{
            						new_users=${u_name};
            					}
            					else
            					{
            						new_users=${old_users}","${u_name};
            					}	
            					fi;
            					./sqlite3 ./database.db "UPDATE machine SET user='$new_users' WHERE no=$i";
            					echo -ne '\033[32m';
                				echo 'Done.';
                				echo -ne '\033[0m';
            				}
            				fi;
            			}
            			fi;
            		}
            		done;
                }
                fi;;
            4)
            	echo -n 'User name:';
            	read u_name;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
				{
					echo -ne '\033[31m';
                	echo "ERROR:$u_name not exists!";
                	echo -e '\033[0m';
                }
                else
                {
            		./sqlite3 ./database.db "SELECT no,machine_name FROM machine" | awk -F '|' 'BEGIN{OFS="\t";print "MID","Machine_name";}{OFS="\t";print $1,$2;}';
            		echo -n 'Please input MID,use sapce to divide,exp:1 2 3 4:';
            		read u_mid;
            		for i in $u_mid
            		do
            		{
            			if [ "`./sqlite3 ./database.db "SELECT no FROM machine WHERE no=$i"`" == ""  ]; then
            			{
            				echo -ne '\033[31m';
                			echo "ERROR:MID $mid not exists!";
                			echo -e '\033[0m';
                		}
                		else
                		{
            				old_users=`./sqlite3 ./database.db "SELECT user FROM machine WHERE no=$i"`;
            				if [ "`echo "$old_users" | grep -w $u_name`" != "" ]; then
            				{
            					if [ "`echo "$old_users" | grep ","`" == "" ]; then
            					{
            						new_users=`echo "$old_users" | sed "s/$u_name//"`;
            					}
            					else
            					{
            						new_users=`echo "$old_users" | sed "s/,$u_name//"`;
            					}
            					fi;
            					./sqlite3 ./database.db "UPDATE machine SET user='$new_users' WHERE no=$i";
                				echo -ne '\033[32m';
                				echo 'Done.';
                				echo -ne '\033[0m';
            				}
            				else
            				{
            					echo -ne '\033[31m';
                				echo "ERROR:$u_name not exsits in $i!";
                				echo -e '\033[0m';
                			}
                			fi;
            			}
            			fi;
            		}
            		done;
                }
                fi;;
            5)
            	echo -n 'User name:';
            	read u_name;
            	echo -ne '\033[32m';
                echo -n 'Please input new password:';
                echo -ne '\033[0m';
                read -s new_pas;
                echo '';
                new_pas_sha=`echo "$new_pas" | sha512sum | cut -d ' ' -f 1`;
                ./sqlite3 ./database.db "UPDATE user SET password='$new_pas_sha' WHERE username='$u_name'";
                echo 'Password has been changed!';;
            6)
            	is_break=1;;
            *)
            	echo -ne '\033[31m';
                echo 'Please input 1,2,3,4,5 or 6!';
                echo -ne '\033[0m';;
        esac;
    }
    done;
};


#user_information_manage
function user_information_manage
{
	is_break=-1;
	while [ $is_break -eq -1 ];
	do
	{
		echo '********User Information Manage********';
		echo '1.Office';
		echo '2.Phone';
		echo '3.Exit';
		read u_choose;
		case $u_choose in
			1)
				echo -n 'User name:';
            	read u_name;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
				{
					echo -ne '\033[31m';
                	echo "ERROR:$u_name not exists!";
                	echo -e '\033[0m';
                }
                else
                {
                	./sqlite3 ./database.db "SELECT no,username,office,phone FROM user WHERE username='$u_name'" | awk -F '|' 'BEGIN{OFS="\t";print "UID","Username","Office","","Phone";}{OFS="\t";print $1,$2,"",$3,"",$4;}';
                	echo -n "Please input new Office for $u_name:";
                	read i_office;
                	./sqlite3 ./database.db "UPDATE user SET office='$i_office' WHERE username='$u_name'";
                	echo -ne '\033[32m';
                	echo 'Done.';
                	echo -ne '\033[0m';
                }
                fi;;
            2)
            	echo -n 'User name:';
            	read u_name;
            	if [ "`./sqlite3 ./database.db "SELECT no FROM user WHERE username='$u_name'"`" == ""  ]; then
				{
					echo -ne '\033[31m';
                	echo "ERROR:$u_name not exists!";
                	echo -e '\033[0m';
                }
                else
                {
                	./sqlite3 ./database.db "SELECT no,username,office,phone FROM user WHERE username='$u_name'" | awk -F '|' 'BEGIN{OFS="\t";print "UID","Username","Office","","Phone";}{OFS="\t";print $1,$2,"",$3,"",$4;}';
                	echo -n "Please input new Phone Number for $u_name:";
                	read i_phone;
                	./sqlite3 ./database.db "UPDATE user SET phone='$i_phone' WHERE username='$u_name'";
                	echo -ne '\033[32m';
                	echo 'Done.';
                	echo -ne '\033[0m';
                }
                fi;;
            3)
            	is_break=1;;
            *)
            	echo -ne '\033[31m';
                echo 'Please input 1,2 or 3!';
                echo -ne '\033[0m';;
		esac
	}
	done;
};
				
				
				
	



#user_login
#0:success -1:wrong username or password -2:wrong machine
login_result=-1;
function user_login
{
    #echo $0 $1 $2 $3;
    username=$1;
    password=`echo "$2" | sha512sum | cut -d ' ' -f 1`;
    machine=$3;
    sql_check_user_password="SELECT no FROM user WHERE username='$username' AND password='$password'";
    #echo $sql_check_user_password;
    if [ "`./sqlite3 ./database.db "$sql_check_user_password"`" == '' ]; then
    {
        echo -ne '\033[31m';
        echo 'Access denied';
        echo -ne '\033[0m';
        login_result=-1
    }
    else
    {
        if [ "$username" != "root" ]; then
        {
            sql_check_machine="SELECT user FROM machine WHERE machine_name='$machine'";
            #echo $sql_check_machine;
            if [ "`./sqlite3 database.db "$sql_check_machine" | grep -w $username`" == '' ]; then
            {
                echo -ne '\033[31m';
                echo "Access denied,you can't login to this machine";
                echo -ne '\033[0m';
                login_result=-2;
            }
            fi;
        }
        fi;
        if [ ! $login_result -eq -2 ]; then
        {
        	login_result=0;
        	UID_v=`./sqlite3 ./database.db "SELECT no FROM user WHERE username="\'$username\'""`;
        	login_date=`date +%F_%H:%M:%S`;
        	#!!!!!!!!!!!!i must change the database and add the number of tty here!!!!!!!!!!!!!
        	tty=`./sqlite3 ./database.db "SELECT tty FROM login_user WHERE username="\'$username\'" AND machine="\'$machine\'" ORDER BY tty DESC LIMIT 1"`;
        	if [ "$tty" == "" ]; then
        	{
            	tty=1;
        	}
        	else
        	{
            	tty=`expr $tty + 1`;
        	}
        	fi;
        	./sqlite3 ./database.db "INSERT INTO login_user (UID,username,machine,date,tty) VALUES ($UID_v,'$username','$machine','$login_date',$tty)";
            if [ "$username" == "root" ]; then
        	    ./message_background.sh $username root "rvsh_p_!!!"&
            else
                ./message_background.sh $username $machine "rvsh_p_!!!"&
            fi;
        	back_pid=$!;
        }
        fi;
    }
    fi;
};


#admin_login
function admin_login
{ 
    echo -ne '\033[32m';
    echo "login as: root";
    echo -ne '\033[0m';
    s=0;
    login_result=-1;
    until [ $login_result -eq 0 -o $s -gt 5 ];
    do
    {
        echo -ne '\033[32m';
        echo -n "root's password: ";
        echo -ne '\033[0m';
        read -s password;
        echo '';
        #echo $password;
        user_login 'root' $password;
        s=`expr $s + 1`;
    }
    done;
    if [ $login_result -eq 0 ]; then
    {
        #v_shell username machine_name;
        v_shell 'root' '';
    }
    fi;
    if [ $s -gt 5 ]; then
    {
        echo -ne '\033[31m';
        echo 'Wrong too many times,quit.';
        echo -ne '\033[0m';
    }
    fi;
};

#input password !username machine_name
function password_input
{
    #user_login username password machine_name
    echo -ne '\033[32m';
    echo "login as: $1";
    echo -ne '\033[0m';
    login_result=-1;
    s=0;
    until [ $login_result -eq 0 -o $s -gt 5 ];
    do
    {
        echo -ne '\033[32m';
        echo -n "$1@$2's password: ";
        echo -ne '\033[0m';                           
        read -s password;
        echo '';
        #echo $password;
        user_login $1 $password $2;
        s=`expr $s + 1`;
    }
    done;
    if [ $login_result -eq 0 ]; then
    {
        #v_shell username machine_name;
        v_shell $1 $2;
    }
    fi;
    if [ $s -gt 5 ]; then
    {
        echo -ne '\033[31m';
        echo 'Wrong too many times,quit.';
        echo -ne '\033[0m';                           
    }
    fi;
};

#main
if [ "$1" == '-connect' ]; then
{
    if [ $# -eq 3 ]; then
    {
		password_input $3 $2;
    }
    else
    {
        echo -ne '\033[31m';
        echo 'Error:if you want to use -connect mode, please input username and machine name, rvsh - connect machine_name username.';
        echo -ne '\033[0m';
        exit -1;
    }
    fi;
}
else
{
    if [ "$1" == '-admin' ]; then
    {
        #admin_login;
        admin_login;
    }
    else
    {
        echo -ne '\033[31m';
        echo 'Error:rvsh [-connect/-admin] [machine_name/ ] [username/ ]';
        echo -ne '\033[0m';
    }
    fi;
}
fi;


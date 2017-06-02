#!/bin/bash 
#message background program
#./message_background.sh username machine_name

if [ "$3" != "rvsh_p_!!!" ]; then
{
    echo 'ERROR:this program must be called by main program';
}
else
{
    username=$1;
    if [ "$1" == "root" ]; then
        machine_name="";
    else
        machine_name=$2;
    fi;
}
fi;

message_id_now=0;

while [ 1 -eq 1 ];
do
{
    if [ "`./sqlite3 ./database.db "SELECT no FROM message WHERE no>$message_id_now AND to_username='$username' AND to_machine='$machine_name' AND count>0"`" != "" ]; then
    {
        sql_result=`./sqlite3 ./database.db "SELECT no FROM message WHERE no>$message_id_now AND to_username='$username' AND to_machine='$machine_name' AND count>0"`;
        for i in $sql_result;
        do
        {
            send_ok=0;
            read_ok=0;
            write_ok=0;
            while [ $send_ok -eq 0 ];
            do
            {
                ./sqlite3 ./database.db "SELECT * FROM message WHERE no=$i" | awk -F '|' '{print "Message from:"$2"@"$3" on pts/"$4,"at",$7,"...\n",$8,"\n";}';
                if [ $? -eq 0 ]; then
                    send_ok=1
                    message_id_now="$i"; 
                fi;
            }
            done;

            while [ $read_ok -eq 0 ];
            do
            {
                m_count=`./sqlite3 ./database.db "SELECT count FROM message WHERE no=$i"`;
                if [ $? -eq 0 ]; then 
                    m_count=`expr $m_count - 1`;
                    read_ok=1;
                fi;
            }
            done;

            while [ $write_ok -eq 0 ];
            do
            {
                ./sqlite3 ./database.db "UPDATE message SET count='$m_count' WHERE no=$i";
                if [ $? -eq 0 ]; then
                    write_ok=1;
                fi;
            }
            done;
        }
        done;
    }
    fi;
    sleep `expr $RANDOM % 2 + 1`
}
done;





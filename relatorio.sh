#!/bin/bash

DOMINIOSATELLITE="getnet.local"

ARQUIVO_POSICIONAL=$1
DATA=$2
MAQUINA_ESPECIFICA=$3

if [ -z $ARQUIVO_POSICIONAL ] || [ -z $DATA ];then
	echo -ne '\n'
	echo "Por favor informar um arquivo .CSV já formatado conforme documentação para o script!"
	echo -ne '\n'
	echo "Use o script assim --> ./script.sh nome-arquivo.CSV 22/02/2024"
	echo -ne '\n'
	exit 1
fi

if [ ! -z "$MAQUINA_ESPECIFICA" ];then
	grep "$DATA" "$ARQUIVO_POSICIONAL" | grep -i "$MAQUINA_ESPECIFICA" | head -n 1 > agendamentos_tmp.csv
	ARQUIVO="agendamentos_tmp.csv"
else
	grep "$DATA" "$ARQUIVO_POSICIONAL" > agendamentos_tmp.csv
	ARQUIVO="agendamentos_tmp.csv"
fi

for HOST in $(cat "$ARQUIVO" | awk -F"," '{print $2}' | sort -u | uniq); 
do 

	ID=($(hammer job-invocation list --search "$HOST" | grep "${DATA:6:6}-${DATA:3:2}-${DATA:0:2}" | egrep -vw "(install\ rsync|failed)" | awk '{print $1}'))


	for IDJOBEXECUTADO in "${ID[@]}"
	do

		hammer job-invocation output --id $IDJOBEXECUTADO --host $HOST.$DOMINIOSATELLITE > $HOST-$IDJOBEXECUTADO.tmp

		TIMESTAMP=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -w "Data-execucao:" | awk -F" " '{print $2}' | sed 's/\r$//' | sed 's/\",//')

		AUDIT=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep "Exit status:" | awk -F" " '{print $3}' | sed 's/ //g')

		AUDIT2=$(grep "Exit status:" $HOST-$IDJOBEXECUTADO.tmp | awk -F" " '{print $3}' | sed 's/ //g')

		DEPENDENCIA1=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "Dependencies Resolved")

		DEPENDENCIA2=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "Transaction Summary")

		DEPENDENCIA3=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "No packages marked for update")

		DEPENDENCIA4=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "Error: rpmdb open failed")

		DEPENDENCIA5=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "Nothing to do")

		DEPENDENCIA6=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "Incorrect padding")

		DEPENDENCIA7=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -i "StandardError: Job execution failed")

		DEPENDENCIA8=$(grep -i "Failed to initialize:" $HOST-$IDJOBEXECUTADO.tmp)

		DEPENDENCIA9=$(grep -i "This system is not registered" $HOST-$IDJOBEXECUTADO.tmp)	


		if [ "$AUDIT" == "0" ] && [ -n "$DEPENDENCIA1" ] && [ -n "$DEPENDENCIA2" ];then

			VAR1=$(grep -iA100000 "\"stdout_lines\":" $HOST-$IDJOBEXECUTADO.tmp | grep -iA10000 "Dependencies Resolved" | egrep -m1 -B10000 "Transaction Summary" | awk '{print $2}' | egrep -v 'resolved.|Resolved|Package|x86_64|Summary' | sed 's/",//g' | sed '/^$/d' | sort -u | sed 's/ //g' | sed 's/\r//' | sed -e :a -e '$!N;s/\n/ /;ta' -e 'P;D' | sed 's/ /,/g')		

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,$VAR1" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "0" ] && [ -n "$DEPENDENCIA3" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,No-packages-marked-for-update" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "0" ] && [ -n "$DEPENDENCIA4" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,Erro-rpmdb-yum" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "0" ] && [ -n "$DEPENDENCIA5" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,Nothing-to-do" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp	

		elif [ "$AUDIT" == "1" ] && [ -n "$DEPENDENCIA6" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,Incorrect padding" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "127" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,rex login" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "EXCEPTION" ];then

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,Erro-SSH-EXCEPTION" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT" == "2" ];then

			TIMESTAMP=$(/bin/date +%d-%m-%Y-%H-%M-%S)

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,StandardError-Job-execution-failed" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ "$AUDIT2" == "1" ] || [ "$AUDIT2" == "2" ];then

			TIMESTAMP=$(/bin/date +%d-%m-%Y-%H-%M-%S)

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,StandardError-Job-execution-failed" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ -n "$DEPENDENCIA8" ];then

			TIMESTAMP=$(/bin/date +%d-%m-%Y-%H-%M-%S)

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,NoMethodError-undefined-method" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp

		elif [ -n "$DEPENDENCIA9" ];then

			TIMESTAMP=$(/bin/date +%d-%m-%Y-%H-%M-%S)

			echo "$HOST,$IDJOBEXECUTADO,$TIMESTAMP,This-system-is-not-registered" >> audit.csv

			rm -f $HOST-$IDJOBEXECUTADO.tmp			

		else
			AUDIT="N/A"
			DEPENDENCIA="N/A"

			echo "$HOST,$AUDIT,$TIMESTAMP,$DEPENDENCIA" >> NA-audit.csv
		fi
	done

	cat audit.csv | awk -F"," '{print NF}' > numero

	MAXIMODECOLUNAS=$(cat numero | sort -nr | head -1 | awk '{print int($1)}')

	CONTADOR=1

	for COLUNAS in `more numero | awk '{print int($1)}'`
	do
		if [ $MAXIMODECOLUNAS != $COLUNAS ];then

			COLUNASCAL=$(( $MAXIMODECOLUNAS - $COLUNAS ));

				for i in $(seq 1 $COLUNASCAL)
				do
					echo "," >> lola-$CONTADOR
				done

			VIRGULAS=$(cat lola-$CONTADOR | xargs | sed 's/ //g')

			sed -i "${CONTADOR}s/$/${VIRGULAS}/" audit.csv

		fi

		CONTADOR=$((CONTADOR+1))
	done

	rm -f lola-*
	rm -f numero

done

rm -f "$ARQUIVO"
